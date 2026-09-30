// Generated; no runtime code generation or eval.
import lengthModule from "ajv/dist/runtime/ucs2length.js";
const ucs2length = lengthModule.default ?? lengthModule;
"use strict";
export const Request = validate21;
const schema32 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["describe"],"properties":{"describe":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["suggest"],"properties":{"suggest":{"type":"object","additionalProperties":false,"properties":{"search":{"type":"string","maxLength":131072}},"required":["search"]}}},{"type":"object","additionalProperties":false,"required":["assist"],"properties":{"assist":{"type":"object","additionalProperties":false,"properties":{"sql":{"type":"string","maxLength":131072},"cursor":{"type":"integer","minimum":0,"maximum":65535},"generation":{"type":"integer","minimum":0,"maximum":4294967295},"mode":{"type":"string","enum":["sql","console"]}},"required":["sql","cursor","generation","mode"]}}},{"type":"object","additionalProperties":false,"required":["compile"],"properties":{"compile":{"type":"object","additionalProperties":false,"properties":{"sql":{"type":"string","maxLength":131072}},"required":["sql"]}}},{"type":"object","additionalProperties":false,"required":["inspect"],"properties":{"inspect":{"type":"object","additionalProperties":false,"properties":{"sql":{"type":"string","maxLength":131072}},"required":["sql"]}}},{"type":"object","additionalProperties":false,"required":["next"],"properties":{"next":{"type":"object","additionalProperties":false,"properties":{"namespace":{"type":"string","maxLength":131072},"bundle":{"type":"string","maxLength":131072}},"required":["namespace","bundle"]}}},{"type":"object","additionalProperties":false,"required":["next_draft"],"properties":{"next_draft":{"type":"object","additionalProperties":false,"properties":{"namespace":{"type":"string","maxLength":131072},"bundle":{"type":"string","maxLength":131072},"generation":{"type":"string","maxLength":131072}},"required":["namespace","bundle","generation"]}}},{"type":"object","additionalProperties":false,"required":["draft_open"],"properties":{"draft_open":{"type":"object","additionalProperties":false,"properties":{"expected":{"type":"string","maxLength":131072},"limit":{"type":"integer","minimum":0,"maximum":255}},"required":["expected","limit"]}}},{"type":"object","additionalProperties":false,"required":["draft_close"],"properties":{"draft_close":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["draft_status"],"properties":{"draft_status":{"anyOf":[{"type":"string","maxLength":131072},{"type":"null"}]}}},{"type":"object","additionalProperties":false,"required":["submit"],"properties":{"submit":{"type":"object","additionalProperties":false,"properties":{"token":{"type":"string","maxLength":131072}},"required":["token"]}}},{"type":"object","additionalProperties":false,"required":["observe"],"properties":{"observe":{"type":"integer","minimum":0,"maximum":9007199254740991}}},{"type":"object","additionalProperties":false,"required":["status"],"properties":{"status":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["page"],"properties":{"page":{"type":"object","additionalProperties":false,"properties":{"namespace":{"type":"string","maxLength":131072},"cursor":{"anyOf":[{"type":"string","maxLength":131072},{"type":"null"}]}},"required":["namespace","cursor"]}}},{"type":"object","additionalProperties":false,"required":["prepare_control"],"properties":{"prepare_control":{"type":"object","additionalProperties":false,"properties":{"namespace":{"type":"string","maxLength":131072},"operation":{"type":"string","enum":["cancel","collect","retire"]}},"required":["namespace","operation"]}}}]};
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
if((data.suggest === undefined) && (missing1 = "suggest")){
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
if(!(key1 === "suggest")){
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
if(data.suggest !== undefined){
let data1 = data.suggest;
const _errs9 = errors;
if(errors === _errs9){
if(data1 && typeof data1 == "object" && !Array.isArray(data1)){
let missing2;
if((data1.search === undefined) && (missing2 = "search")){
const err7 = {instancePath:instancePath+"/suggest",schemaPath:"#/oneOf/1/properties/suggest/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
if(vErrors === null){
vErrors = [err7];
}
else {
vErrors.push(err7);
}
errors++;
}
else {
const _errs11 = errors;
for(const key2 in data1){
if(!(key2 === "search")){
const err8 = {instancePath:instancePath+"/suggest",schemaPath:"#/oneOf/1/properties/suggest/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(_errs11 === errors){
if(data1.search !== undefined){
let data2 = data1.search;
const _errs12 = errors;
if(errors === _errs12){
if(typeof data2 === "string"){
if(func1(data2) > 131072){
const err9 = {instancePath:instancePath+"/suggest/search",schemaPath:"#/oneOf/1/properties/suggest/properties/search/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
}
}
else {
const err10 = {instancePath:instancePath+"/suggest/search",schemaPath:"#/oneOf/1/properties/suggest/properties/search/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
}
}
}
}
}
}
else {
const err11 = {instancePath:instancePath+"/suggest",schemaPath:"#/oneOf/1/properties/suggest/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err12 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
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
const _errs14 = errors;
if(errors === _errs14){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing3;
if((data.assist === undefined) && (missing3 = "assist")){
const err13 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
if(vErrors === null){
vErrors = [err13];
}
else {
vErrors.push(err13);
}
errors++;
}
else {
const _errs16 = errors;
for(const key3 in data){
if(!(key3 === "assist")){
const err14 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(_errs16 === errors){
if(data.assist !== undefined){
let data3 = data.assist;
const _errs17 = errors;
if(errors === _errs17){
if(data3 && typeof data3 == "object" && !Array.isArray(data3)){
let missing4;
if(((((data3.sql === undefined) && (missing4 = "sql")) || ((data3.cursor === undefined) && (missing4 = "cursor"))) || ((data3.generation === undefined) && (missing4 = "generation"))) || ((data3.mode === undefined) && (missing4 = "mode"))){
const err15 = {instancePath:instancePath+"/assist",schemaPath:"#/oneOf/2/properties/assist/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
}
else {
const _errs19 = errors;
for(const key4 in data3){
if(!((((key4 === "sql") || (key4 === "cursor")) || (key4 === "generation")) || (key4 === "mode"))){
const err16 = {instancePath:instancePath+"/assist",schemaPath:"#/oneOf/2/properties/assist/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(_errs19 === errors){
if(data3.sql !== undefined){
let data4 = data3.sql;
const _errs20 = errors;
if(errors === _errs20){
if(typeof data4 === "string"){
if(func1(data4) > 131072){
const err17 = {instancePath:instancePath+"/assist/sql",schemaPath:"#/oneOf/2/properties/assist/properties/sql/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err18 = {instancePath:instancePath+"/assist/sql",schemaPath:"#/oneOf/2/properties/assist/properties/sql/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
}
}
var valid5 = _errs20 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data3.cursor !== undefined){
let data5 = data3.cursor;
const _errs22 = errors;
if(!(((typeof data5 == "number") && (!(data5 % 1) && !isNaN(data5))) && (isFinite(data5)))){
const err19 = {instancePath:instancePath+"/assist/cursor",schemaPath:"#/oneOf/2/properties/assist/properties/cursor/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
}
if(errors === _errs22){
if((typeof data5 == "number") && (isFinite(data5))){
if(data5 > 65535 || isNaN(data5)){
const err20 = {instancePath:instancePath+"/assist/cursor",schemaPath:"#/oneOf/2/properties/assist/properties/cursor/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
if(vErrors === null){
vErrors = [err20];
}
else {
vErrors.push(err20);
}
errors++;
}
else {
if(data5 < 0 || isNaN(data5)){
const err21 = {instancePath:instancePath+"/assist/cursor",schemaPath:"#/oneOf/2/properties/assist/properties/cursor/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
}
errors++;
}
}
}
}
var valid5 = _errs22 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data3.generation !== undefined){
let data6 = data3.generation;
const _errs24 = errors;
if(!(((typeof data6 == "number") && (!(data6 % 1) && !isNaN(data6))) && (isFinite(data6)))){
const err22 = {instancePath:instancePath+"/assist/generation",schemaPath:"#/oneOf/2/properties/assist/properties/generation/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err22];
}
else {
vErrors.push(err22);
}
errors++;
}
if(errors === _errs24){
if((typeof data6 == "number") && (isFinite(data6))){
if(data6 > 4294967295 || isNaN(data6)){
const err23 = {instancePath:instancePath+"/assist/generation",schemaPath:"#/oneOf/2/properties/assist/properties/generation/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err23];
}
else {
vErrors.push(err23);
}
errors++;
}
else {
if(data6 < 0 || isNaN(data6)){
const err24 = {instancePath:instancePath+"/assist/generation",schemaPath:"#/oneOf/2/properties/assist/properties/generation/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
}
errors++;
}
}
}
}
var valid5 = _errs24 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data3.mode !== undefined){
let data7 = data3.mode;
const _errs26 = errors;
if(typeof data7 !== "string"){
const err25 = {instancePath:instancePath+"/assist/mode",schemaPath:"#/oneOf/2/properties/assist/properties/mode/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err25];
}
else {
vErrors.push(err25);
}
errors++;
}
if(!((data7 === "sql") || (data7 === "console"))){
const err26 = {instancePath:instancePath+"/assist/mode",schemaPath:"#/oneOf/2/properties/assist/properties/mode/enum",keyword:"enum",params:{allowedValues: schema32.oneOf[2].properties.assist.properties.mode.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err26];
}
else {
vErrors.push(err26);
}
errors++;
}
var valid5 = _errs26 === errors;
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
else {
const err27 = {instancePath:instancePath+"/assist",schemaPath:"#/oneOf/2/properties/assist/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err27];
}
else {
vErrors.push(err27);
}
errors++;
}
}
}
}
}
}
else {
const err28 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err28];
}
else {
vErrors.push(err28);
}
errors++;
}
}
var _valid0 = _errs14 === errors;
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
const _errs28 = errors;
if(errors === _errs28){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing5;
if((data.compile === undefined) && (missing5 = "compile")){
const err29 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
if(vErrors === null){
vErrors = [err29];
}
else {
vErrors.push(err29);
}
errors++;
}
else {
const _errs30 = errors;
for(const key5 in data){
if(!(key5 === "compile")){
const err30 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(_errs30 === errors){
if(data.compile !== undefined){
let data8 = data.compile;
const _errs31 = errors;
if(errors === _errs31){
if(data8 && typeof data8 == "object" && !Array.isArray(data8)){
let missing6;
if((data8.sql === undefined) && (missing6 = "sql")){
const err31 = {instancePath:instancePath+"/compile",schemaPath:"#/oneOf/3/properties/compile/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
if(vErrors === null){
vErrors = [err31];
}
else {
vErrors.push(err31);
}
errors++;
}
else {
const _errs33 = errors;
for(const key6 in data8){
if(!(key6 === "sql")){
const err32 = {instancePath:instancePath+"/compile",schemaPath:"#/oneOf/3/properties/compile/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err32];
}
else {
vErrors.push(err32);
}
errors++;
break;
}
}
if(_errs33 === errors){
if(data8.sql !== undefined){
let data9 = data8.sql;
const _errs34 = errors;
if(errors === _errs34){
if(typeof data9 === "string"){
if(func1(data9) > 131072){
const err33 = {instancePath:instancePath+"/compile/sql",schemaPath:"#/oneOf/3/properties/compile/properties/sql/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
}
else {
const err34 = {instancePath:instancePath+"/compile/sql",schemaPath:"#/oneOf/3/properties/compile/properties/sql/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err34];
}
else {
vErrors.push(err34);
}
errors++;
}
}
}
}
}
}
else {
const err35 = {instancePath:instancePath+"/compile",schemaPath:"#/oneOf/3/properties/compile/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err35];
}
else {
vErrors.push(err35);
}
errors++;
}
}
}
}
}
}
else {
const err36 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
}
}
var _valid0 = _errs28 === errors;
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
const _errs36 = errors;
if(errors === _errs36){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing7;
if((data.inspect === undefined) && (missing7 = "inspect")){
const err37 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
if(vErrors === null){
vErrors = [err37];
}
else {
vErrors.push(err37);
}
errors++;
}
else {
const _errs38 = errors;
for(const key7 in data){
if(!(key7 === "inspect")){
const err38 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err38];
}
else {
vErrors.push(err38);
}
errors++;
break;
}
}
if(_errs38 === errors){
if(data.inspect !== undefined){
let data10 = data.inspect;
const _errs39 = errors;
if(errors === _errs39){
if(data10 && typeof data10 == "object" && !Array.isArray(data10)){
let missing8;
if((data10.sql === undefined) && (missing8 = "sql")){
const err39 = {instancePath:instancePath+"/inspect",schemaPath:"#/oneOf/4/properties/inspect/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
if(vErrors === null){
vErrors = [err39];
}
else {
vErrors.push(err39);
}
errors++;
}
else {
const _errs41 = errors;
for(const key8 in data10){
if(!(key8 === "sql")){
const err40 = {instancePath:instancePath+"/inspect",schemaPath:"#/oneOf/4/properties/inspect/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
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
if(_errs41 === errors){
if(data10.sql !== undefined){
let data11 = data10.sql;
const _errs42 = errors;
if(errors === _errs42){
if(typeof data11 === "string"){
if(func1(data11) > 131072){
const err41 = {instancePath:instancePath+"/inspect/sql",schemaPath:"#/oneOf/4/properties/inspect/properties/sql/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err41];
}
else {
vErrors.push(err41);
}
errors++;
}
}
else {
const err42 = {instancePath:instancePath+"/inspect/sql",schemaPath:"#/oneOf/4/properties/inspect/properties/sql/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
}
}
else {
const err43 = {instancePath:instancePath+"/inspect",schemaPath:"#/oneOf/4/properties/inspect/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err43];
}
else {
vErrors.push(err43);
}
errors++;
}
}
}
}
}
}
else {
const err44 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err44];
}
else {
vErrors.push(err44);
}
errors++;
}
}
var _valid0 = _errs36 === errors;
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
const _errs44 = errors;
if(errors === _errs44){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing9;
if((data.next === undefined) && (missing9 = "next")){
const err45 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
if(vErrors === null){
vErrors = [err45];
}
else {
vErrors.push(err45);
}
errors++;
}
else {
const _errs46 = errors;
for(const key9 in data){
if(!(key9 === "next")){
const err46 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
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
if(_errs46 === errors){
if(data.next !== undefined){
let data12 = data.next;
const _errs47 = errors;
if(errors === _errs47){
if(data12 && typeof data12 == "object" && !Array.isArray(data12)){
let missing10;
if(((data12.namespace === undefined) && (missing10 = "namespace")) || ((data12.bundle === undefined) && (missing10 = "bundle"))){
const err47 = {instancePath:instancePath+"/next",schemaPath:"#/oneOf/5/properties/next/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"};
if(vErrors === null){
vErrors = [err47];
}
else {
vErrors.push(err47);
}
errors++;
}
else {
const _errs49 = errors;
for(const key10 in data12){
if(!((key10 === "namespace") || (key10 === "bundle"))){
const err48 = {instancePath:instancePath+"/next",schemaPath:"#/oneOf/5/properties/next/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err48];
}
else {
vErrors.push(err48);
}
errors++;
break;
}
}
if(_errs49 === errors){
if(data12.namespace !== undefined){
let data13 = data12.namespace;
const _errs50 = errors;
if(errors === _errs50){
if(typeof data13 === "string"){
if(func1(data13) > 131072){
const err49 = {instancePath:instancePath+"/next/namespace",schemaPath:"#/oneOf/5/properties/next/properties/namespace/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err49];
}
else {
vErrors.push(err49);
}
errors++;
}
}
else {
const err50 = {instancePath:instancePath+"/next/namespace",schemaPath:"#/oneOf/5/properties/next/properties/namespace/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err50];
}
else {
vErrors.push(err50);
}
errors++;
}
}
var valid11 = _errs50 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data12.bundle !== undefined){
let data14 = data12.bundle;
const _errs52 = errors;
if(errors === _errs52){
if(typeof data14 === "string"){
if(func1(data14) > 131072){
const err51 = {instancePath:instancePath+"/next/bundle",schemaPath:"#/oneOf/5/properties/next/properties/bundle/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err51];
}
else {
vErrors.push(err51);
}
errors++;
}
}
else {
const err52 = {instancePath:instancePath+"/next/bundle",schemaPath:"#/oneOf/5/properties/next/properties/bundle/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err52];
}
else {
vErrors.push(err52);
}
errors++;
}
}
var valid11 = _errs52 === errors;
}
else {
var valid11 = true;
}
}
}
}
}
else {
const err53 = {instancePath:instancePath+"/next",schemaPath:"#/oneOf/5/properties/next/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
}
else {
const err54 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err54];
}
else {
vErrors.push(err54);
}
errors++;
}
}
var _valid0 = _errs44 === errors;
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
let missing11;
if((data.next_draft === undefined) && (missing11 = "next_draft")){
const err55 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
if(vErrors === null){
vErrors = [err55];
}
else {
vErrors.push(err55);
}
errors++;
}
else {
const _errs56 = errors;
for(const key11 in data){
if(!(key11 === "next_draft")){
const err56 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err56];
}
else {
vErrors.push(err56);
}
errors++;
break;
}
}
if(_errs56 === errors){
if(data.next_draft !== undefined){
let data15 = data.next_draft;
const _errs57 = errors;
if(errors === _errs57){
if(data15 && typeof data15 == "object" && !Array.isArray(data15)){
let missing12;
if((((data15.namespace === undefined) && (missing12 = "namespace")) || ((data15.bundle === undefined) && (missing12 = "bundle"))) || ((data15.generation === undefined) && (missing12 = "generation"))){
const err57 = {instancePath:instancePath+"/next_draft",schemaPath:"#/oneOf/6/properties/next_draft/required",keyword:"required",params:{missingProperty: missing12},message:"must have required property '"+missing12+"'"};
if(vErrors === null){
vErrors = [err57];
}
else {
vErrors.push(err57);
}
errors++;
}
else {
const _errs59 = errors;
for(const key12 in data15){
if(!(((key12 === "namespace") || (key12 === "bundle")) || (key12 === "generation"))){
const err58 = {instancePath:instancePath+"/next_draft",schemaPath:"#/oneOf/6/properties/next_draft/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key12},message:"must NOT have additional properties"};
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
if(_errs59 === errors){
if(data15.namespace !== undefined){
let data16 = data15.namespace;
const _errs60 = errors;
if(errors === _errs60){
if(typeof data16 === "string"){
if(func1(data16) > 131072){
const err59 = {instancePath:instancePath+"/next_draft/namespace",schemaPath:"#/oneOf/6/properties/next_draft/properties/namespace/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err59];
}
else {
vErrors.push(err59);
}
errors++;
}
}
else {
const err60 = {instancePath:instancePath+"/next_draft/namespace",schemaPath:"#/oneOf/6/properties/next_draft/properties/namespace/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err60];
}
else {
vErrors.push(err60);
}
errors++;
}
}
var valid13 = _errs60 === errors;
}
else {
var valid13 = true;
}
if(valid13){
if(data15.bundle !== undefined){
let data17 = data15.bundle;
const _errs62 = errors;
if(errors === _errs62){
if(typeof data17 === "string"){
if(func1(data17) > 131072){
const err61 = {instancePath:instancePath+"/next_draft/bundle",schemaPath:"#/oneOf/6/properties/next_draft/properties/bundle/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err61];
}
else {
vErrors.push(err61);
}
errors++;
}
}
else {
const err62 = {instancePath:instancePath+"/next_draft/bundle",schemaPath:"#/oneOf/6/properties/next_draft/properties/bundle/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err62];
}
else {
vErrors.push(err62);
}
errors++;
}
}
var valid13 = _errs62 === errors;
}
else {
var valid13 = true;
}
if(valid13){
if(data15.generation !== undefined){
let data18 = data15.generation;
const _errs64 = errors;
if(errors === _errs64){
if(typeof data18 === "string"){
if(func1(data18) > 131072){
const err63 = {instancePath:instancePath+"/next_draft/generation",schemaPath:"#/oneOf/6/properties/next_draft/properties/generation/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err63];
}
else {
vErrors.push(err63);
}
errors++;
}
}
else {
const err64 = {instancePath:instancePath+"/next_draft/generation",schemaPath:"#/oneOf/6/properties/next_draft/properties/generation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err64];
}
else {
vErrors.push(err64);
}
errors++;
}
}
var valid13 = _errs64 === errors;
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
const err65 = {instancePath:instancePath+"/next_draft",schemaPath:"#/oneOf/6/properties/next_draft/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err65];
}
else {
vErrors.push(err65);
}
errors++;
}
}
}
}
}
}
else {
const err66 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err66];
}
else {
vErrors.push(err66);
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
const _errs66 = errors;
if(errors === _errs66){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing13;
if((data.draft_open === undefined) && (missing13 = "draft_open")){
const err67 = {instancePath,schemaPath:"#/oneOf/7/required",keyword:"required",params:{missingProperty: missing13},message:"must have required property '"+missing13+"'"};
if(vErrors === null){
vErrors = [err67];
}
else {
vErrors.push(err67);
}
errors++;
}
else {
const _errs68 = errors;
for(const key13 in data){
if(!(key13 === "draft_open")){
const err68 = {instancePath,schemaPath:"#/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key13},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err68];
}
else {
vErrors.push(err68);
}
errors++;
break;
}
}
if(_errs68 === errors){
if(data.draft_open !== undefined){
let data19 = data.draft_open;
const _errs69 = errors;
if(errors === _errs69){
if(data19 && typeof data19 == "object" && !Array.isArray(data19)){
let missing14;
if(((data19.expected === undefined) && (missing14 = "expected")) || ((data19.limit === undefined) && (missing14 = "limit"))){
const err69 = {instancePath:instancePath+"/draft_open",schemaPath:"#/oneOf/7/properties/draft_open/required",keyword:"required",params:{missingProperty: missing14},message:"must have required property '"+missing14+"'"};
if(vErrors === null){
vErrors = [err69];
}
else {
vErrors.push(err69);
}
errors++;
}
else {
const _errs71 = errors;
for(const key14 in data19){
if(!((key14 === "expected") || (key14 === "limit"))){
const err70 = {instancePath:instancePath+"/draft_open",schemaPath:"#/oneOf/7/properties/draft_open/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key14},message:"must NOT have additional properties"};
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
if(_errs71 === errors){
if(data19.expected !== undefined){
let data20 = data19.expected;
const _errs72 = errors;
if(errors === _errs72){
if(typeof data20 === "string"){
if(func1(data20) > 131072){
const err71 = {instancePath:instancePath+"/draft_open/expected",schemaPath:"#/oneOf/7/properties/draft_open/properties/expected/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err72 = {instancePath:instancePath+"/draft_open/expected",schemaPath:"#/oneOf/7/properties/draft_open/properties/expected/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err72];
}
else {
vErrors.push(err72);
}
errors++;
}
}
var valid15 = _errs72 === errors;
}
else {
var valid15 = true;
}
if(valid15){
if(data19.limit !== undefined){
let data21 = data19.limit;
const _errs74 = errors;
if(!(((typeof data21 == "number") && (!(data21 % 1) && !isNaN(data21))) && (isFinite(data21)))){
const err73 = {instancePath:instancePath+"/draft_open/limit",schemaPath:"#/oneOf/7/properties/draft_open/properties/limit/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err73];
}
else {
vErrors.push(err73);
}
errors++;
}
if(errors === _errs74){
if((typeof data21 == "number") && (isFinite(data21))){
if(data21 > 255 || isNaN(data21)){
const err74 = {instancePath:instancePath+"/draft_open/limit",schemaPath:"#/oneOf/7/properties/draft_open/properties/limit/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err74];
}
else {
vErrors.push(err74);
}
errors++;
}
else {
if(data21 < 0 || isNaN(data21)){
const err75 = {instancePath:instancePath+"/draft_open/limit",schemaPath:"#/oneOf/7/properties/draft_open/properties/limit/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid15 = _errs74 === errors;
}
else {
var valid15 = true;
}
}
}
}
}
else {
const err76 = {instancePath:instancePath+"/draft_open",schemaPath:"#/oneOf/7/properties/draft_open/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err77 = {instancePath,schemaPath:"#/oneOf/7/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err77];
}
else {
vErrors.push(err77);
}
errors++;
}
}
var _valid0 = _errs66 === errors;
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
let missing15;
if((data.draft_close === undefined) && (missing15 = "draft_close")){
const err78 = {instancePath,schemaPath:"#/oneOf/8/required",keyword:"required",params:{missingProperty: missing15},message:"must have required property '"+missing15+"'"};
if(vErrors === null){
vErrors = [err78];
}
else {
vErrors.push(err78);
}
errors++;
}
else {
const _errs78 = errors;
for(const key15 in data){
if(!(key15 === "draft_close")){
const err79 = {instancePath,schemaPath:"#/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key15},message:"must NOT have additional properties"};
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
if(_errs78 === errors){
if(data.draft_close !== undefined){
let data22 = data.draft_close;
const _errs79 = errors;
if(errors === _errs79){
if(typeof data22 === "string"){
if(func1(data22) > 131072){
const err80 = {instancePath:instancePath+"/draft_close",schemaPath:"#/oneOf/8/properties/draft_close/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err81 = {instancePath:instancePath+"/draft_close",schemaPath:"#/oneOf/8/properties/draft_close/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
const err82 = {instancePath,schemaPath:"#/oneOf/8/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err82];
}
else {
vErrors.push(err82);
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
const _errs81 = errors;
if(errors === _errs81){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing16;
if((data.draft_status === undefined) && (missing16 = "draft_status")){
const err83 = {instancePath,schemaPath:"#/oneOf/9/required",keyword:"required",params:{missingProperty: missing16},message:"must have required property '"+missing16+"'"};
if(vErrors === null){
vErrors = [err83];
}
else {
vErrors.push(err83);
}
errors++;
}
else {
const _errs83 = errors;
for(const key16 in data){
if(!(key16 === "draft_status")){
const err84 = {instancePath,schemaPath:"#/oneOf/9/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key16},message:"must NOT have additional properties"};
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
if(_errs83 === errors){
if(data.draft_status !== undefined){
let data23 = data.draft_status;
const _errs85 = errors;
let valid18 = false;
const _errs86 = errors;
if(errors === _errs86){
if(typeof data23 === "string"){
if(func1(data23) > 131072){
const err85 = {instancePath:instancePath+"/draft_status",schemaPath:"#/oneOf/9/properties/draft_status/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err86 = {instancePath:instancePath+"/draft_status",schemaPath:"#/oneOf/9/properties/draft_status/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err86];
}
else {
vErrors.push(err86);
}
errors++;
}
}
var _valid1 = _errs86 === errors;
valid18 = valid18 || _valid1;
const _errs88 = errors;
if(data23 !== null){
const err87 = {instancePath:instancePath+"/draft_status",schemaPath:"#/oneOf/9/properties/draft_status/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err87];
}
else {
vErrors.push(err87);
}
errors++;
}
var _valid1 = _errs88 === errors;
valid18 = valid18 || _valid1;
if(!valid18){
const err88 = {instancePath:instancePath+"/draft_status",schemaPath:"#/oneOf/9/properties/draft_status/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err88];
}
else {
vErrors.push(err88);
}
errors++;
}
else {
errors = _errs85;
if(vErrors !== null){
if(_errs85){
vErrors.length = _errs85;
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
const err89 = {instancePath,schemaPath:"#/oneOf/9/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err89];
}
else {
vErrors.push(err89);
}
errors++;
}
}
var _valid0 = _errs81 === errors;
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
if((data.submit === undefined) && (missing17 = "submit")){
const err90 = {instancePath,schemaPath:"#/oneOf/10/required",keyword:"required",params:{missingProperty: missing17},message:"must have required property '"+missing17+"'"};
if(vErrors === null){
vErrors = [err90];
}
else {
vErrors.push(err90);
}
errors++;
}
else {
const _errs92 = errors;
for(const key17 in data){
if(!(key17 === "submit")){
const err91 = {instancePath,schemaPath:"#/oneOf/10/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key17},message:"must NOT have additional properties"};
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
if(_errs92 === errors){
if(data.submit !== undefined){
let data24 = data.submit;
const _errs93 = errors;
if(errors === _errs93){
if(data24 && typeof data24 == "object" && !Array.isArray(data24)){
let missing18;
if((data24.token === undefined) && (missing18 = "token")){
const err92 = {instancePath:instancePath+"/submit",schemaPath:"#/oneOf/10/properties/submit/required",keyword:"required",params:{missingProperty: missing18},message:"must have required property '"+missing18+"'"};
if(vErrors === null){
vErrors = [err92];
}
else {
vErrors.push(err92);
}
errors++;
}
else {
const _errs95 = errors;
for(const key18 in data24){
if(!(key18 === "token")){
const err93 = {instancePath:instancePath+"/submit",schemaPath:"#/oneOf/10/properties/submit/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key18},message:"must NOT have additional properties"};
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
if(_errs95 === errors){
if(data24.token !== undefined){
let data25 = data24.token;
const _errs96 = errors;
if(errors === _errs96){
if(typeof data25 === "string"){
if(func1(data25) > 131072){
const err94 = {instancePath:instancePath+"/submit/token",schemaPath:"#/oneOf/10/properties/submit/properties/token/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err95 = {instancePath:instancePath+"/submit/token",schemaPath:"#/oneOf/10/properties/submit/properties/token/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
const err96 = {instancePath:instancePath+"/submit",schemaPath:"#/oneOf/10/properties/submit/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err97 = {instancePath,schemaPath:"#/oneOf/10/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err97];
}
else {
vErrors.push(err97);
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
const _errs98 = errors;
if(errors === _errs98){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing19;
if((data.observe === undefined) && (missing19 = "observe")){
const err98 = {instancePath,schemaPath:"#/oneOf/11/required",keyword:"required",params:{missingProperty: missing19},message:"must have required property '"+missing19+"'"};
if(vErrors === null){
vErrors = [err98];
}
else {
vErrors.push(err98);
}
errors++;
}
else {
const _errs100 = errors;
for(const key19 in data){
if(!(key19 === "observe")){
const err99 = {instancePath,schemaPath:"#/oneOf/11/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key19},message:"must NOT have additional properties"};
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
if(_errs100 === errors){
if(data.observe !== undefined){
let data26 = data.observe;
const _errs101 = errors;
if(!(((typeof data26 == "number") && (!(data26 % 1) && !isNaN(data26))) && (isFinite(data26)))){
const err100 = {instancePath:instancePath+"/observe",schemaPath:"#/oneOf/11/properties/observe/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err100];
}
else {
vErrors.push(err100);
}
errors++;
}
if(errors === _errs101){
if((typeof data26 == "number") && (isFinite(data26))){
if(data26 > 9007199254740991 || isNaN(data26)){
const err101 = {instancePath:instancePath+"/observe",schemaPath:"#/oneOf/11/properties/observe/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err101];
}
else {
vErrors.push(err101);
}
errors++;
}
else {
if(data26 < 0 || isNaN(data26)){
const err102 = {instancePath:instancePath+"/observe",schemaPath:"#/oneOf/11/properties/observe/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err102];
}
else {
vErrors.push(err102);
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
const err103 = {instancePath,schemaPath:"#/oneOf/11/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err103];
}
else {
vErrors.push(err103);
}
errors++;
}
}
var _valid0 = _errs98 === errors;
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
const _errs103 = errors;
if(errors === _errs103){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing20;
if((data.status === undefined) && (missing20 = "status")){
const err104 = {instancePath,schemaPath:"#/oneOf/12/required",keyword:"required",params:{missingProperty: missing20},message:"must have required property '"+missing20+"'"};
if(vErrors === null){
vErrors = [err104];
}
else {
vErrors.push(err104);
}
errors++;
}
else {
const _errs105 = errors;
for(const key20 in data){
if(!(key20 === "status")){
const err105 = {instancePath,schemaPath:"#/oneOf/12/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key20},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err105];
}
else {
vErrors.push(err105);
}
errors++;
break;
}
}
if(_errs105 === errors){
if(data.status !== undefined){
let data27 = data.status;
const _errs106 = errors;
if(errors === _errs106){
if(typeof data27 === "string"){
if(func1(data27) > 131072){
const err106 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/12/properties/status/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err106];
}
else {
vErrors.push(err106);
}
errors++;
}
}
else {
const err107 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/12/properties/status/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
const err108 = {instancePath,schemaPath:"#/oneOf/12/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err108];
}
else {
vErrors.push(err108);
}
errors++;
}
}
var _valid0 = _errs103 === errors;
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
const _errs108 = errors;
if(errors === _errs108){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing21;
if((data.page === undefined) && (missing21 = "page")){
const err109 = {instancePath,schemaPath:"#/oneOf/13/required",keyword:"required",params:{missingProperty: missing21},message:"must have required property '"+missing21+"'"};
if(vErrors === null){
vErrors = [err109];
}
else {
vErrors.push(err109);
}
errors++;
}
else {
const _errs110 = errors;
for(const key21 in data){
if(!(key21 === "page")){
const err110 = {instancePath,schemaPath:"#/oneOf/13/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key21},message:"must NOT have additional properties"};
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
if(_errs110 === errors){
if(data.page !== undefined){
let data28 = data.page;
const _errs111 = errors;
if(errors === _errs111){
if(data28 && typeof data28 == "object" && !Array.isArray(data28)){
let missing22;
if(((data28.namespace === undefined) && (missing22 = "namespace")) || ((data28.cursor === undefined) && (missing22 = "cursor"))){
const err111 = {instancePath:instancePath+"/page",schemaPath:"#/oneOf/13/properties/page/required",keyword:"required",params:{missingProperty: missing22},message:"must have required property '"+missing22+"'"};
if(vErrors === null){
vErrors = [err111];
}
else {
vErrors.push(err111);
}
errors++;
}
else {
const _errs113 = errors;
for(const key22 in data28){
if(!((key22 === "namespace") || (key22 === "cursor"))){
const err112 = {instancePath:instancePath+"/page",schemaPath:"#/oneOf/13/properties/page/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key22},message:"must NOT have additional properties"};
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
if(_errs113 === errors){
if(data28.namespace !== undefined){
let data29 = data28.namespace;
const _errs114 = errors;
if(errors === _errs114){
if(typeof data29 === "string"){
if(func1(data29) > 131072){
const err113 = {instancePath:instancePath+"/page/namespace",schemaPath:"#/oneOf/13/properties/page/properties/namespace/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err113];
}
else {
vErrors.push(err113);
}
errors++;
}
}
else {
const err114 = {instancePath:instancePath+"/page/namespace",schemaPath:"#/oneOf/13/properties/page/properties/namespace/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err114];
}
else {
vErrors.push(err114);
}
errors++;
}
}
var valid24 = _errs114 === errors;
}
else {
var valid24 = true;
}
if(valid24){
if(data28.cursor !== undefined){
let data30 = data28.cursor;
const _errs116 = errors;
const _errs117 = errors;
let valid25 = false;
const _errs118 = errors;
if(errors === _errs118){
if(typeof data30 === "string"){
if(func1(data30) > 131072){
const err115 = {instancePath:instancePath+"/page/cursor",schemaPath:"#/oneOf/13/properties/page/properties/cursor/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err116 = {instancePath:instancePath+"/page/cursor",schemaPath:"#/oneOf/13/properties/page/properties/cursor/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err116];
}
else {
vErrors.push(err116);
}
errors++;
}
}
var _valid2 = _errs118 === errors;
valid25 = valid25 || _valid2;
const _errs120 = errors;
if(data30 !== null){
const err117 = {instancePath:instancePath+"/page/cursor",schemaPath:"#/oneOf/13/properties/page/properties/cursor/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err117];
}
else {
vErrors.push(err117);
}
errors++;
}
var _valid2 = _errs120 === errors;
valid25 = valid25 || _valid2;
if(!valid25){
const err118 = {instancePath:instancePath+"/page/cursor",schemaPath:"#/oneOf/13/properties/page/properties/cursor/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err118];
}
else {
vErrors.push(err118);
}
errors++;
}
else {
errors = _errs117;
if(vErrors !== null){
if(_errs117){
vErrors.length = _errs117;
}
else {
vErrors = null;
}
}
}
var valid24 = _errs116 === errors;
}
else {
var valid24 = true;
}
}
}
}
}
else {
const err119 = {instancePath:instancePath+"/page",schemaPath:"#/oneOf/13/properties/page/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
}
else {
const err120 = {instancePath,schemaPath:"#/oneOf/13/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err120];
}
else {
vErrors.push(err120);
}
errors++;
}
}
var _valid0 = _errs108 === errors;
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
const _errs122 = errors;
if(errors === _errs122){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing23;
if((data.prepare_control === undefined) && (missing23 = "prepare_control")){
const err121 = {instancePath,schemaPath:"#/oneOf/14/required",keyword:"required",params:{missingProperty: missing23},message:"must have required property '"+missing23+"'"};
if(vErrors === null){
vErrors = [err121];
}
else {
vErrors.push(err121);
}
errors++;
}
else {
const _errs124 = errors;
for(const key23 in data){
if(!(key23 === "prepare_control")){
const err122 = {instancePath,schemaPath:"#/oneOf/14/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key23},message:"must NOT have additional properties"};
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
if(_errs124 === errors){
if(data.prepare_control !== undefined){
let data31 = data.prepare_control;
const _errs125 = errors;
if(errors === _errs125){
if(data31 && typeof data31 == "object" && !Array.isArray(data31)){
let missing24;
if(((data31.namespace === undefined) && (missing24 = "namespace")) || ((data31.operation === undefined) && (missing24 = "operation"))){
const err123 = {instancePath:instancePath+"/prepare_control",schemaPath:"#/oneOf/14/properties/prepare_control/required",keyword:"required",params:{missingProperty: missing24},message:"must have required property '"+missing24+"'"};
if(vErrors === null){
vErrors = [err123];
}
else {
vErrors.push(err123);
}
errors++;
}
else {
const _errs127 = errors;
for(const key24 in data31){
if(!((key24 === "namespace") || (key24 === "operation"))){
const err124 = {instancePath:instancePath+"/prepare_control",schemaPath:"#/oneOf/14/properties/prepare_control/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key24},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err124];
}
else {
vErrors.push(err124);
}
errors++;
break;
}
}
if(_errs127 === errors){
if(data31.namespace !== undefined){
let data32 = data31.namespace;
const _errs128 = errors;
if(errors === _errs128){
if(typeof data32 === "string"){
if(func1(data32) > 131072){
const err125 = {instancePath:instancePath+"/prepare_control/namespace",schemaPath:"#/oneOf/14/properties/prepare_control/properties/namespace/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err125];
}
else {
vErrors.push(err125);
}
errors++;
}
}
else {
const err126 = {instancePath:instancePath+"/prepare_control/namespace",schemaPath:"#/oneOf/14/properties/prepare_control/properties/namespace/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err126];
}
else {
vErrors.push(err126);
}
errors++;
}
}
var valid27 = _errs128 === errors;
}
else {
var valid27 = true;
}
if(valid27){
if(data31.operation !== undefined){
let data33 = data31.operation;
const _errs130 = errors;
if(typeof data33 !== "string"){
const err127 = {instancePath:instancePath+"/prepare_control/operation",schemaPath:"#/oneOf/14/properties/prepare_control/properties/operation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err127];
}
else {
vErrors.push(err127);
}
errors++;
}
if(!(((data33 === "cancel") || (data33 === "collect")) || (data33 === "retire"))){
const err128 = {instancePath:instancePath+"/prepare_control/operation",schemaPath:"#/oneOf/14/properties/prepare_control/properties/operation/enum",keyword:"enum",params:{allowedValues: schema32.oneOf[14].properties.prepare_control.properties.operation.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err128];
}
else {
vErrors.push(err128);
}
errors++;
}
var valid27 = _errs130 === errors;
}
else {
var valid27 = true;
}
}
}
}
}
else {
const err129 = {instancePath:instancePath+"/prepare_control",schemaPath:"#/oneOf/14/properties/prepare_control/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err129];
}
else {
vErrors.push(err129);
}
errors++;
}
}
}
}
}
}
else {
const err130 = {instancePath,schemaPath:"#/oneOf/14/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err130];
}
else {
vErrors.push(err130);
}
errors++;
}
}
var _valid0 = _errs122 === errors;
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
}
}
}
}
}
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
const err131 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err131];
}
else {
vErrors.push(err131);
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
const schema33 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["description"],"properties":{"description":{"type":"object","additionalProperties":false,"properties":{"connection":{"type":"object","additionalProperties":false,"properties":{"realm":{"type":"integer","minimum":0,"maximum":9007199254740991},"principal":{"type":"integer","minimum":0,"maximum":9007199254740991},"source":{"type":"integer","minimum":0,"maximum":9007199254740991},"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"requester":{"type":"integer","minimum":0,"maximum":9007199254740991},"requests":{"type":"integer","minimum":0,"maximum":9007199254740991}},"required":["realm","principal","source","resource","requester","requests"]},"name":{"type":"string","maxLength":131072},"source":{"type":"object","additionalProperties":false,"properties":{"capabilities":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"source":{"type":"integer","minimum":0,"maximum":255},"plan":{"type":"integer","minimum":0,"maximum":255},"result":{"type":"integer","minimum":0,"maximum":255},"bundle_bytes":{"type":"integer","minimum":0,"maximum":4294967295},"part_bytes":{"type":"integer","minimum":0,"maximum":65535},"segment_bytes":{"type":"integer","minimum":0,"maximum":4294967295},"batch_rows":{"type":"integer","minimum":0,"maximum":255},"columns":{"type":"integer","minimum":0,"maximum":255},"kv":{"type":"boolean"},"table":{"type":"boolean"},"document":{"type":"boolean"}},"required":["version","source","plan","result","bundle_bytes","part_bytes","segment_bytes","batch_rows","columns","kv","table","document"]},"source":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"source":{"oneOf":[{"type":"object","additionalProperties":false,"required":["kv"],"properties":{"kv":{"type":"object","additionalProperties":false,"properties":{"prefix":{"type":"string","maxLength":131072},"key":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["version","type"]},"value":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["version","type"]}},"required":["prefix","key","value"]}}},{"type":"object","additionalProperties":false,"required":["table"],"properties":{"table":{"type":"object","additionalProperties":false,"properties":{"id":{"type":"integer","minimum":0,"maximum":4294967295},"names":{"type":"array","minItems":2,"maxItems":2,"items":{"type":"string","maxLength":131072}},"value_type":{"type":"string","enum":["int64","boolean","utf8","binary"]}},"required":["id","names","value_type"]}}},{"type":"object","additionalProperties":false,"required":["document"],"properties":{"document":{"type":"object","additionalProperties":false,"properties":{"reference":{"type":"object","additionalProperties":false,"properties":{"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"document":{"type":"string","maxLength":131072},"epoch":{"type":"string","maxLength":131072},"type_revision":{"type":"integer","minimum":0,"maximum":4294967295},"revision":{"type":"string","maxLength":131072}},"required":["resource","document","epoch","type_revision","revision"]},"change_format":{"type":"integer","minimum":0,"maximum":4294967295},"expand":{"anyOf":[{"type":"array","maxItems":8,"items":{"type":"string","maxLength":131072}},{"type":"null"}]},"projections":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"column":{"type":"object","additionalProperties":false,"properties":{"name":{"type":"string","maxLength":131072},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["name","type"]},"path":{"type":"array","maxItems":8,"items":{"type":"string","maxLength":131072}},"relative":{"type":"boolean"},"mode":{"type":"string","enum":["scalar","text","element_counter","element_replica"]},"text_bytes":{"type":"integer","minimum":0,"maximum":65535},"text_steps":{"type":"integer","minimum":0,"maximum":65535}},"required":["column","path","relative","mode","text_bytes","text_steps"]}}},"required":["reference","change_format","expand","projections"]}}}]}},"required":["version","resource","source"]},"resource_revision":{"type":"integer","minimum":0,"maximum":9007199254740991},"policy_revision":{"type":"string","maxLength":131072},"limits":{"type":"object","additionalProperties":false,"properties":{"pages":{"type":"string","maxLength":131072},"segments":{"type":"string","maxLength":131072},"result_bytes":{"type":"string","maxLength":131072}},"required":["pages","segments","result_bytes"]},"active":{"anyOf":[{"type":"string","maxLength":131072},{"type":"null"}]}},"required":["capabilities","source","resource_revision","policy_revision","limits","active"]},"sql":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"statement_bytes":{"type":"integer","minimum":0,"maximum":4294967295},"named_columns":{"type":"integer","minimum":0,"maximum":255},"star_columns":{"type":"integer","minimum":0,"maximum":255},"uint64_limits":{"type":"boolean"},"uint64_literals":{"type":"boolean"},"float64_literals":{"type":"boolean"},"null_comparison":{"type":"boolean"},"explicit_null_test":{"type":"boolean"},"writes":{"type":"boolean"},"continuous":{"type":"boolean"}},"required":["version","statement_bytes","named_columns","star_columns","uint64_limits","uint64_literals","float64_literals","null_comparison","explicit_null_test","writes","continuous"]},"budgets":{"type":"object","additionalProperties":false,"properties":{"pages":{"type":"string","maxLength":131072},"segments":{"type":"string","maxLength":131072},"result_bytes":{"type":"string","maxLength":131072}},"required":["pages","segments","result_bytes"]},"columns":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"name":{"type":"string","maxLength":131072},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["name","type"]}}},"required":["connection","name","source","sql","budgets","columns"]}}},{"type":"object","additionalProperties":false,"required":["suggestions"],"properties":{"suggestions":{"type":"object","additionalProperties":false,"properties":{"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"contract":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"items":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"label":{"type":"string","maxLength":131072},"sql":{"type":"string","maxLength":131072}},"required":["label","sql"]}}},"required":["resource","contract","items"]}}},{"type":"object","additionalProperties":false,"required":["assistance"],"properties":{"assistance":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"generation":{"type":"integer","minimum":0,"maximum":4294967295},"profile":{"type":"string","enum":["unified_v1"]},"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"contract":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"resource_revision":{"type":"integer","minimum":0,"maximum":9007199254740991},"policy_revision":{"type":"string","maxLength":131072},"range":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"start":{"type":"integer","minimum":0,"maximum":65535},"end":{"type":"integer","minimum":0,"maximum":65535},"quoted":{"type":"boolean"}},"required":["start","end","quoted"]},{"type":"null"}]},"items":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"text":{"type":"string","maxLength":131072},"kind":{"type":"string","enum":["keyword","source","column","symbol","literal","meta"]},"detail":{"type":"string","maxLength":131072}},"required":["text","kind","detail"]}}},"required":["version","generation","profile","resource","contract","resource_revision","policy_revision","range","items"]}}},{"type":"object","additionalProperties":false,"required":["compiled"],"properties":{"compiled":{"type":"object","additionalProperties":false,"properties":{"bundle":{"type":"string","maxLength":131072},"source":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"source":{"oneOf":[{"type":"object","additionalProperties":false,"required":["kv"],"properties":{"kv":{"type":"object","additionalProperties":false,"properties":{"prefix":{"type":"string","maxLength":131072},"key":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["version","type"]},"value":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["version","type"]}},"required":["prefix","key","value"]}}},{"type":"object","additionalProperties":false,"required":["table"],"properties":{"table":{"type":"object","additionalProperties":false,"properties":{"id":{"type":"integer","minimum":0,"maximum":4294967295},"names":{"type":"array","minItems":2,"maxItems":2,"items":{"type":"string","maxLength":131072}},"value_type":{"type":"string","enum":["int64","boolean","utf8","binary"]}},"required":["id","names","value_type"]}}},{"type":"object","additionalProperties":false,"required":["document"],"properties":{"document":{"type":"object","additionalProperties":false,"properties":{"reference":{"type":"object","additionalProperties":false,"properties":{"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"document":{"type":"string","maxLength":131072},"epoch":{"type":"string","maxLength":131072},"type_revision":{"type":"integer","minimum":0,"maximum":4294967295},"revision":{"type":"string","maxLength":131072}},"required":["resource","document","epoch","type_revision","revision"]},"change_format":{"type":"integer","minimum":0,"maximum":4294967295},"expand":{"anyOf":[{"type":"array","maxItems":8,"items":{"type":"string","maxLength":131072}},{"type":"null"}]},"projections":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"column":{"type":"object","additionalProperties":false,"properties":{"name":{"type":"string","maxLength":131072},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["name","type"]},"path":{"type":"array","maxItems":8,"items":{"type":"string","maxLength":131072}},"relative":{"type":"boolean"},"mode":{"type":"string","enum":["scalar","text","element_counter","element_replica"]},"text_bytes":{"type":"integer","minimum":0,"maximum":65535},"text_steps":{"type":"integer","minimum":0,"maximum":65535}},"required":["column","path","relative","mode","text_bytes","text_steps"]}}},"required":["reference","change_format","expand","projections"]}}}]}},"required":["version","resource","source"]},"plan":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"projection":{"type":"array","maxItems":8,"items":{"type":"integer","minimum":0,"maximum":4294967295}},"limit":{"anyOf":[{"type":"string","maxLength":131072},{"type":"null"}]},"aggregate":{"type":"string","enum":["rows","count","sum"]},"predicate":{"oneOf":[{"type":"object","additionalProperties":false,"required":["all"],"properties":{"all":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["state"],"properties":{"state":{"type":"object","additionalProperties":false,"properties":{"column":{"type":"integer","minimum":0,"maximum":255},"value":{"type":"string","enum":["missing","null","type_error","value","conflict"]}},"required":["column","value"]}}},{"type":"object","additionalProperties":false,"required":["compare"],"properties":{"compare":{"type":"object","additionalProperties":false,"properties":{"column":{"type":"integer","minimum":0,"maximum":255},"op":{"type":"string","enum":["eq","ne","lt","le","gt","ge"]},"value":{"oneOf":[{"type":"object","additionalProperties":false,"required":["int64"],"properties":{"int64":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["uint64"],"properties":{"uint64":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"type":"boolean"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"type":"string","maxLength":131072}}}]}},"required":["column","op","value"]}}}]}},"required":["version","projection","limit","aggregate","predicate"]},"limits":{"type":"object","additionalProperties":false,"properties":{"pages":{"type":"string","maxLength":131072},"segments":{"type":"string","maxLength":131072},"result_bytes":{"type":"string","maxLength":131072}},"required":["pages","segments","result_bytes"]},"contract":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"schema":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}}},"required":["bundle","source","plan","limits","contract","schema"]}}},{"type":"object","additionalProperties":false,"required":["inspection"],"properties":{"inspection":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"scope":{"type":"string","enum":["configured_source"]},"name":{"type":"string","maxLength":131072},"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"source_kind":{"type":"string","enum":["kv","table","document"]},"contract":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"schema":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"resource_revision":{"type":"integer","minimum":0,"maximum":9007199254740991},"policy_revision":{"type":"string","maxLength":131072},"details":{"oneOf":[{"type":"object","additionalProperties":false,"required":["description"],"properties":{"description":{"type":"object","additionalProperties":false,"properties":{"columns":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"name":{"type":"string","maxLength":131072},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["name","type"]}}},"required":["columns"]}}},{"type":"object","additionalProperties":false,"required":["tables"],"properties":{"tables":{"type":"array","maxItems":8,"items":{"type":"string","maxLength":131072}}}},{"type":"object","additionalProperties":false,"required":["explanation"],"properties":{"explanation":{"type":"object","additionalProperties":false,"properties":{"operators":{"type":"array","maxItems":8,"items":{"type":"string","enum":["scan","filter","limit","project","count","sum"]}},"predicate":{"oneOf":[{"type":"object","additionalProperties":false,"required":["all"],"properties":{"all":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["state"],"properties":{"state":{"type":"object","additionalProperties":false,"properties":{"column":{"type":"string","maxLength":131072},"value":{"type":"string","enum":["missing","null","type_error","value","conflict"]}},"required":["column","value"]}}},{"type":"object","additionalProperties":false,"required":["compare"],"properties":{"compare":{"type":"object","additionalProperties":false,"properties":{"column":{"type":"string","maxLength":131072},"op":{"type":"string","enum":["eq","ne","lt","le","gt","ge"]},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["column","op","type"]}}}]},"projection":{"type":"array","maxItems":8,"items":{"type":"string","maxLength":131072}},"limit":{"anyOf":[{"type":"string","maxLength":131072},{"type":"null"}]},"aggregate":{"type":"string","enum":["rows","count","sum"]},"columns":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"name":{"type":"string","maxLength":131072},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["name","type"]}},"budgets":{"type":"object","additionalProperties":false,"properties":{"pages":{"type":"string","maxLength":131072},"segments":{"type":"string","maxLength":131072},"result_bytes":{"type":"string","maxLength":131072}},"required":["pages","segments","result_bytes"]}},"required":["operators","predicate","projection","limit","aggregate","columns","budgets"]}}}]}},"required":["version","scope","name","resource","source_kind","contract","schema","resource_revision","policy_revision","details"]}}},{"type":"object","additionalProperties":false,"required":["prepared"],"properties":{"prepared":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"token":{"type":"string","maxLength":131072}},"required":["token"]},{"type":"null"}]}}},{"type":"object","additionalProperties":false,"required":["receipt"],"properties":{"receipt":{"type":"object","additionalProperties":false,"properties":{"position":{"type":"integer","minimum":0,"maximum":9007199254740991}},"required":["position"]}}},{"type":"object","additionalProperties":false,"required":["observation"],"properties":{"observation":{"oneOf":[{"type":"object","additionalProperties":false,"required":["pending"],"properties":{"pending":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["committed"],"properties":{"committed":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["rejected"],"properties":{"rejected":{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512}}}]}}},{"type":"object","additionalProperties":false,"required":["status"],"properties":{"status":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"reference":{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512},"phase":{"type":"string","enum":["uploading","sealed","admitted","complete","cancelled","denied","rejected","retired"]},"correlation":{"type":"string","maxLength":131072},"manifest":{"anyOf":[{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512},{"type":"null"}]},"collected":{"type":"boolean"}},"required":["reference","phase","correlation","manifest","collected"]},{"type":"null"}]}}},{"type":"object","additionalProperties":false,"required":["page"],"properties":{"page":{"type":"object","additionalProperties":false,"properties":{"evidence":{"type":"object","additionalProperties":false,"properties":{"manifest":{"type":"object","additionalProperties":false,"properties":{"job":{"type":"integer","minimum":0,"maximum":9007199254740991},"source":{"type":"object","additionalProperties":false,"properties":{"pid":{"type":"integer","minimum":0,"maximum":9007199254740991},"input":{"type":"integer","minimum":0,"maximum":9007199254740991},"index":{"type":"integer","minimum":0,"maximum":255}},"required":["pid","input","index"]},"requester":{"type":"integer","minimum":0,"maximum":9007199254740991},"correlation":{"type":"string","maxLength":131072},"policy_revision":{"type":"string","maxLength":131072},"request":{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512},"basis":{"type":"object","additionalProperties":false,"properties":{"kind":{"type":"string","enum":["kv","table","document"]},"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"revision":{"type":"integer","minimum":0,"maximum":9007199254740991},"contract":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"schema":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}}},"required":["kind","resource","revision","contract","schema"]},"plan":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"pages":{"type":"string","maxLength":131072},"scanned":{"type":"string","maxLength":131072},"selected":{"type":"string","maxLength":131072},"segments":{"type":"string","maxLength":131072},"rows":{"type":"string","maxLength":131072},"bytes":{"type":"string","maxLength":131072},"sum":{"anyOf":[{"type":"string","maxLength":131072},{"type":"null"}]},"finished":{"anyOf":[{"type":"string","enum":["source_end","limit"]},{"type":"null"}]},"chain":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}}},"required":["job","source","requester","correlation","policy_revision","request","basis","plan","pages","scanned","selected","segments","rows","bytes","sum","finished","chain"]},"columns":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"name":{"type":"string","maxLength":131072},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["name","type"]}},"ordinal":{"type":"string","maxLength":131072},"rows":{"type":"integer","minimum":0,"maximum":255},"ipc":{"type":"string","maxLength":131072},"next":{"anyOf":[{"type":"string","maxLength":131072},{"type":"null"}]}},"required":["manifest","columns","ordinal","rows","ipc","next"]},"cells":{"type":"array","maxItems":8,"items":{"type":"array","maxItems":8,"items":{"oneOf":[{"type":"object","additionalProperties":false,"required":["missing"],"properties":{"missing":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["null"],"properties":{"null":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["type_error"],"properties":{"type_error":{"type":"string","enum":["unknown","int64","uint64","float64","boolean","utf8","binary","null_value","map","list","text","character"]}}},{"type":"object","additionalProperties":false,"required":["value"],"properties":{"value":{"oneOf":[{"type":"object","additionalProperties":false,"required":["int64"],"properties":{"int64":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["uint64"],"properties":{"uint64":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"type":"boolean"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"type":"string","maxLength":131072}}}]}}},{"type":"object","additionalProperties":false,"required":["conflict"],"properties":{"conflict":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"counter":{"type":"string","maxLength":131072},"replica":{"type":"string","maxLength":131072},"value":{"oneOf":[{"type":"object","additionalProperties":false,"required":["null"],"properties":{"null":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["type_error"],"properties":{"type_error":{"type":"string","enum":["unknown","int64","uint64","float64","boolean","utf8","binary","null_value","map","list","text","character"]}}},{"type":"object","additionalProperties":false,"required":["value"],"properties":{"value":{"oneOf":[{"type":"object","additionalProperties":false,"required":["int64"],"properties":{"int64":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["uint64"],"properties":{"uint64":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"type":"boolean"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"type":"string","maxLength":131072}}}]}}}]}},"required":["counter","replica","value"]}}}}]}}}},"required":["evidence","cells"]}}},{"type":"object","additionalProperties":false,"required":["draft"],"properties":{"draft":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"generation":{"type":"string","maxLength":131072},"limit":{"type":"integer","minimum":0,"maximum":255},"starts":{"type":"integer","minimum":0,"maximum":255},"enabled":{"type":"boolean"},"contract":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"budgets":{"type":"object","additionalProperties":false,"properties":{"pages":{"type":"string","maxLength":131072},"segments":{"type":"string","maxLength":131072},"result_bytes":{"type":"string","maxLength":131072}},"required":["pages","segments","result_bytes"]},"namespaces":{"type":"array","minItems":8,"maxItems":8,"items":{"type":"string","maxLength":131072}}},"required":["generation","limit","starts","enabled","contract","budgets","namespaces"]},{"type":"null"}]}}}]};
const func19 = Object.prototype.hasOwnProperty;
const pattern4 = new RegExp("^(?:[0-9a-f]{2})*$", "u");

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
if(!(func19.call(schema33.oneOf[0].properties.description.properties.source.properties.capabilities.properties, key4))){
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
if(!(func19.call(schema33.oneOf[0].properties.description.properties.sql.properties, key18))){
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
if((data.suggestions === undefined) && (missing21 = "suggestions")){
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
if(!(key21 === "suggestions")){
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
if(data.suggestions !== undefined){
let data88 = data.suggestions;
const _errs217 = errors;
if(errors === _errs217){
if(data88 && typeof data88 == "object" && !Array.isArray(data88)){
let missing22;
if((((data88.resource === undefined) && (missing22 = "resource")) || ((data88.contract === undefined) && (missing22 = "contract"))) || ((data88.items === undefined) && (missing22 = "items"))){
const err230 = {instancePath:instancePath+"/suggestions",schemaPath:"#/oneOf/1/properties/suggestions/required",keyword:"required",params:{missingProperty: missing22},message:"must have required property '"+missing22+"'"};
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
if(!(((key22 === "resource") || (key22 === "contract")) || (key22 === "items"))){
const err231 = {instancePath:instancePath+"/suggestions",schemaPath:"#/oneOf/1/properties/suggestions/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key22},message:"must NOT have additional properties"};
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
if(data88.resource !== undefined){
let data89 = data88.resource;
const _errs220 = errors;
if(!(((typeof data89 == "number") && (!(data89 % 1) && !isNaN(data89))) && (isFinite(data89)))){
const err232 = {instancePath:instancePath+"/suggestions/resource",schemaPath:"#/oneOf/1/properties/suggestions/properties/resource/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
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
if(data89 > 9007199254740991 || isNaN(data89)){
const err233 = {instancePath:instancePath+"/suggestions/resource",schemaPath:"#/oneOf/1/properties/suggestions/properties/resource/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
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
const err234 = {instancePath:instancePath+"/suggestions/resource",schemaPath:"#/oneOf/1/properties/suggestions/properties/resource/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
if(data88.contract !== undefined){
let data90 = data88.contract;
const _errs222 = errors;
if(errors === _errs222){
if(Array.isArray(data90)){
if(data90.length > 32){
const err235 = {instancePath:instancePath+"/suggestions/contract",schemaPath:"#/oneOf/1/properties/suggestions/properties/contract/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err235];
}
else {
vErrors.push(err235);
}
errors++;
}
else {
if(data90.length < 32){
const err236 = {instancePath:instancePath+"/suggestions/contract",schemaPath:"#/oneOf/1/properties/suggestions/properties/contract/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err236];
}
else {
vErrors.push(err236);
}
errors++;
}
else {
var valid32 = true;
const len5 = data90.length;
for(let i5=0; i5<len5; i5++){
let data91 = data90[i5];
const _errs224 = errors;
if(!(((typeof data91 == "number") && (!(data91 % 1) && !isNaN(data91))) && (isFinite(data91)))){
const err237 = {instancePath:instancePath+"/suggestions/contract/" + i5,schemaPath:"#/oneOf/1/properties/suggestions/properties/contract/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err237];
}
else {
vErrors.push(err237);
}
errors++;
}
if(errors === _errs224){
if((typeof data91 == "number") && (isFinite(data91))){
if(data91 > 255 || isNaN(data91)){
const err238 = {instancePath:instancePath+"/suggestions/contract/" + i5,schemaPath:"#/oneOf/1/properties/suggestions/properties/contract/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err238];
}
else {
vErrors.push(err238);
}
errors++;
}
else {
if(data91 < 0 || isNaN(data91)){
const err239 = {instancePath:instancePath+"/suggestions/contract/" + i5,schemaPath:"#/oneOf/1/properties/suggestions/properties/contract/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err239];
}
else {
vErrors.push(err239);
}
errors++;
}
}
}
}
var valid32 = _errs224 === errors;
if(!valid32){
break;
}
}
}
}
}
else {
const err240 = {instancePath:instancePath+"/suggestions/contract",schemaPath:"#/oneOf/1/properties/suggestions/properties/contract/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err240];
}
else {
vErrors.push(err240);
}
errors++;
}
}
var valid31 = _errs222 === errors;
}
else {
var valid31 = true;
}
if(valid31){
if(data88.items !== undefined){
let data92 = data88.items;
const _errs226 = errors;
if(errors === _errs226){
if(Array.isArray(data92)){
if(data92.length > 8){
const err241 = {instancePath:instancePath+"/suggestions/items",schemaPath:"#/oneOf/1/properties/suggestions/properties/items/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err241];
}
else {
vErrors.push(err241);
}
errors++;
}
else {
var valid33 = true;
const len6 = data92.length;
for(let i6=0; i6<len6; i6++){
let data93 = data92[i6];
const _errs228 = errors;
if(errors === _errs228){
if(data93 && typeof data93 == "object" && !Array.isArray(data93)){
let missing23;
if(((data93.label === undefined) && (missing23 = "label")) || ((data93.sql === undefined) && (missing23 = "sql"))){
const err242 = {instancePath:instancePath+"/suggestions/items/" + i6,schemaPath:"#/oneOf/1/properties/suggestions/properties/items/items/required",keyword:"required",params:{missingProperty: missing23},message:"must have required property '"+missing23+"'"};
if(vErrors === null){
vErrors = [err242];
}
else {
vErrors.push(err242);
}
errors++;
}
else {
const _errs230 = errors;
for(const key23 in data93){
if(!((key23 === "label") || (key23 === "sql"))){
const err243 = {instancePath:instancePath+"/suggestions/items/" + i6,schemaPath:"#/oneOf/1/properties/suggestions/properties/items/items/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key23},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err243];
}
else {
vErrors.push(err243);
}
errors++;
break;
}
}
if(_errs230 === errors){
if(data93.label !== undefined){
let data94 = data93.label;
const _errs231 = errors;
if(errors === _errs231){
if(typeof data94 === "string"){
if(func1(data94) > 131072){
const err244 = {instancePath:instancePath+"/suggestions/items/" + i6+"/label",schemaPath:"#/oneOf/1/properties/suggestions/properties/items/items/properties/label/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err244];
}
else {
vErrors.push(err244);
}
errors++;
}
}
else {
const err245 = {instancePath:instancePath+"/suggestions/items/" + i6+"/label",schemaPath:"#/oneOf/1/properties/suggestions/properties/items/items/properties/label/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err245];
}
else {
vErrors.push(err245);
}
errors++;
}
}
var valid34 = _errs231 === errors;
}
else {
var valid34 = true;
}
if(valid34){
if(data93.sql !== undefined){
let data95 = data93.sql;
const _errs233 = errors;
if(errors === _errs233){
if(typeof data95 === "string"){
if(func1(data95) > 131072){
const err246 = {instancePath:instancePath+"/suggestions/items/" + i6+"/sql",schemaPath:"#/oneOf/1/properties/suggestions/properties/items/items/properties/sql/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err246];
}
else {
vErrors.push(err246);
}
errors++;
}
}
else {
const err247 = {instancePath:instancePath+"/suggestions/items/" + i6+"/sql",schemaPath:"#/oneOf/1/properties/suggestions/properties/items/items/properties/sql/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err247];
}
else {
vErrors.push(err247);
}
errors++;
}
}
var valid34 = _errs233 === errors;
}
else {
var valid34 = true;
}
}
}
}
}
else {
const err248 = {instancePath:instancePath+"/suggestions/items/" + i6,schemaPath:"#/oneOf/1/properties/suggestions/properties/items/items/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err248];
}
else {
vErrors.push(err248);
}
errors++;
}
}
var valid33 = _errs228 === errors;
if(!valid33){
break;
}
}
}
}
else {
const err249 = {instancePath:instancePath+"/suggestions/items",schemaPath:"#/oneOf/1/properties/suggestions/properties/items/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err249];
}
else {
vErrors.push(err249);
}
errors++;
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
else {
const err250 = {instancePath:instancePath+"/suggestions",schemaPath:"#/oneOf/1/properties/suggestions/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err251 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err251];
}
else {
vErrors.push(err251);
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
const _errs235 = errors;
if(errors === _errs235){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing24;
if((data.assistance === undefined) && (missing24 = "assistance")){
const err252 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing24},message:"must have required property '"+missing24+"'"};
if(vErrors === null){
vErrors = [err252];
}
else {
vErrors.push(err252);
}
errors++;
}
else {
const _errs237 = errors;
for(const key24 in data){
if(!(key24 === "assistance")){
const err253 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key24},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err253];
}
else {
vErrors.push(err253);
}
errors++;
break;
}
}
if(_errs237 === errors){
if(data.assistance !== undefined){
let data96 = data.assistance;
const _errs238 = errors;
if(errors === _errs238){
if(data96 && typeof data96 == "object" && !Array.isArray(data96)){
let missing25;
if((((((((((data96.version === undefined) && (missing25 = "version")) || ((data96.generation === undefined) && (missing25 = "generation"))) || ((data96.profile === undefined) && (missing25 = "profile"))) || ((data96.resource === undefined) && (missing25 = "resource"))) || ((data96.contract === undefined) && (missing25 = "contract"))) || ((data96.resource_revision === undefined) && (missing25 = "resource_revision"))) || ((data96.policy_revision === undefined) && (missing25 = "policy_revision"))) || ((data96.range === undefined) && (missing25 = "range"))) || ((data96.items === undefined) && (missing25 = "items"))){
const err254 = {instancePath:instancePath+"/assistance",schemaPath:"#/oneOf/2/properties/assistance/required",keyword:"required",params:{missingProperty: missing25},message:"must have required property '"+missing25+"'"};
if(vErrors === null){
vErrors = [err254];
}
else {
vErrors.push(err254);
}
errors++;
}
else {
const _errs240 = errors;
for(const key25 in data96){
if(!(func19.call(schema33.oneOf[2].properties.assistance.properties, key25))){
const err255 = {instancePath:instancePath+"/assistance",schemaPath:"#/oneOf/2/properties/assistance/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key25},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err255];
}
else {
vErrors.push(err255);
}
errors++;
break;
}
}
if(_errs240 === errors){
if(data96.version !== undefined){
let data97 = data96.version;
const _errs241 = errors;
if(!(((typeof data97 == "number") && (!(data97 % 1) && !isNaN(data97))) && (isFinite(data97)))){
const err256 = {instancePath:instancePath+"/assistance/version",schemaPath:"#/oneOf/2/properties/assistance/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err256];
}
else {
vErrors.push(err256);
}
errors++;
}
if(errors === _errs241){
if((typeof data97 == "number") && (isFinite(data97))){
if(data97 > 255 || isNaN(data97)){
const err257 = {instancePath:instancePath+"/assistance/version",schemaPath:"#/oneOf/2/properties/assistance/properties/version/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err257];
}
else {
vErrors.push(err257);
}
errors++;
}
else {
if(data97 < 0 || isNaN(data97)){
const err258 = {instancePath:instancePath+"/assistance/version",schemaPath:"#/oneOf/2/properties/assistance/properties/version/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err258];
}
else {
vErrors.push(err258);
}
errors++;
}
}
}
}
var valid36 = _errs241 === errors;
}
else {
var valid36 = true;
}
if(valid36){
if(data96.generation !== undefined){
let data98 = data96.generation;
const _errs243 = errors;
if(!(((typeof data98 == "number") && (!(data98 % 1) && !isNaN(data98))) && (isFinite(data98)))){
const err259 = {instancePath:instancePath+"/assistance/generation",schemaPath:"#/oneOf/2/properties/assistance/properties/generation/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err259];
}
else {
vErrors.push(err259);
}
errors++;
}
if(errors === _errs243){
if((typeof data98 == "number") && (isFinite(data98))){
if(data98 > 4294967295 || isNaN(data98)){
const err260 = {instancePath:instancePath+"/assistance/generation",schemaPath:"#/oneOf/2/properties/assistance/properties/generation/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err260];
}
else {
vErrors.push(err260);
}
errors++;
}
else {
if(data98 < 0 || isNaN(data98)){
const err261 = {instancePath:instancePath+"/assistance/generation",schemaPath:"#/oneOf/2/properties/assistance/properties/generation/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err261];
}
else {
vErrors.push(err261);
}
errors++;
}
}
}
}
var valid36 = _errs243 === errors;
}
else {
var valid36 = true;
}
if(valid36){
if(data96.profile !== undefined){
let data99 = data96.profile;
const _errs245 = errors;
if(typeof data99 !== "string"){
const err262 = {instancePath:instancePath+"/assistance/profile",schemaPath:"#/oneOf/2/properties/assistance/properties/profile/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err262];
}
else {
vErrors.push(err262);
}
errors++;
}
if(!(data99 === "unified_v1")){
const err263 = {instancePath:instancePath+"/assistance/profile",schemaPath:"#/oneOf/2/properties/assistance/properties/profile/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[2].properties.assistance.properties.profile.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err263];
}
else {
vErrors.push(err263);
}
errors++;
}
var valid36 = _errs245 === errors;
}
else {
var valid36 = true;
}
if(valid36){
if(data96.resource !== undefined){
let data100 = data96.resource;
const _errs247 = errors;
if(!(((typeof data100 == "number") && (!(data100 % 1) && !isNaN(data100))) && (isFinite(data100)))){
const err264 = {instancePath:instancePath+"/assistance/resource",schemaPath:"#/oneOf/2/properties/assistance/properties/resource/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err264];
}
else {
vErrors.push(err264);
}
errors++;
}
if(errors === _errs247){
if((typeof data100 == "number") && (isFinite(data100))){
if(data100 > 9007199254740991 || isNaN(data100)){
const err265 = {instancePath:instancePath+"/assistance/resource",schemaPath:"#/oneOf/2/properties/assistance/properties/resource/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err265];
}
else {
vErrors.push(err265);
}
errors++;
}
else {
if(data100 < 0 || isNaN(data100)){
const err266 = {instancePath:instancePath+"/assistance/resource",schemaPath:"#/oneOf/2/properties/assistance/properties/resource/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid36 = _errs247 === errors;
}
else {
var valid36 = true;
}
if(valid36){
if(data96.contract !== undefined){
let data101 = data96.contract;
const _errs249 = errors;
if(errors === _errs249){
if(Array.isArray(data101)){
if(data101.length > 32){
const err267 = {instancePath:instancePath+"/assistance/contract",schemaPath:"#/oneOf/2/properties/assistance/properties/contract/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err267];
}
else {
vErrors.push(err267);
}
errors++;
}
else {
if(data101.length < 32){
const err268 = {instancePath:instancePath+"/assistance/contract",schemaPath:"#/oneOf/2/properties/assistance/properties/contract/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err268];
}
else {
vErrors.push(err268);
}
errors++;
}
else {
var valid37 = true;
const len7 = data101.length;
for(let i7=0; i7<len7; i7++){
let data102 = data101[i7];
const _errs251 = errors;
if(!(((typeof data102 == "number") && (!(data102 % 1) && !isNaN(data102))) && (isFinite(data102)))){
const err269 = {instancePath:instancePath+"/assistance/contract/" + i7,schemaPath:"#/oneOf/2/properties/assistance/properties/contract/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err269];
}
else {
vErrors.push(err269);
}
errors++;
}
if(errors === _errs251){
if((typeof data102 == "number") && (isFinite(data102))){
if(data102 > 255 || isNaN(data102)){
const err270 = {instancePath:instancePath+"/assistance/contract/" + i7,schemaPath:"#/oneOf/2/properties/assistance/properties/contract/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err270];
}
else {
vErrors.push(err270);
}
errors++;
}
else {
if(data102 < 0 || isNaN(data102)){
const err271 = {instancePath:instancePath+"/assistance/contract/" + i7,schemaPath:"#/oneOf/2/properties/assistance/properties/contract/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err271];
}
else {
vErrors.push(err271);
}
errors++;
}
}
}
}
var valid37 = _errs251 === errors;
if(!valid37){
break;
}
}
}
}
}
else {
const err272 = {instancePath:instancePath+"/assistance/contract",schemaPath:"#/oneOf/2/properties/assistance/properties/contract/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err272];
}
else {
vErrors.push(err272);
}
errors++;
}
}
var valid36 = _errs249 === errors;
}
else {
var valid36 = true;
}
if(valid36){
if(data96.resource_revision !== undefined){
let data103 = data96.resource_revision;
const _errs253 = errors;
if(!(((typeof data103 == "number") && (!(data103 % 1) && !isNaN(data103))) && (isFinite(data103)))){
const err273 = {instancePath:instancePath+"/assistance/resource_revision",schemaPath:"#/oneOf/2/properties/assistance/properties/resource_revision/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err273];
}
else {
vErrors.push(err273);
}
errors++;
}
if(errors === _errs253){
if((typeof data103 == "number") && (isFinite(data103))){
if(data103 > 9007199254740991 || isNaN(data103)){
const err274 = {instancePath:instancePath+"/assistance/resource_revision",schemaPath:"#/oneOf/2/properties/assistance/properties/resource_revision/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err274];
}
else {
vErrors.push(err274);
}
errors++;
}
else {
if(data103 < 0 || isNaN(data103)){
const err275 = {instancePath:instancePath+"/assistance/resource_revision",schemaPath:"#/oneOf/2/properties/assistance/properties/resource_revision/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err275];
}
else {
vErrors.push(err275);
}
errors++;
}
}
}
}
var valid36 = _errs253 === errors;
}
else {
var valid36 = true;
}
if(valid36){
if(data96.policy_revision !== undefined){
let data104 = data96.policy_revision;
const _errs255 = errors;
if(errors === _errs255){
if(typeof data104 === "string"){
if(func1(data104) > 131072){
const err276 = {instancePath:instancePath+"/assistance/policy_revision",schemaPath:"#/oneOf/2/properties/assistance/properties/policy_revision/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err276];
}
else {
vErrors.push(err276);
}
errors++;
}
}
else {
const err277 = {instancePath:instancePath+"/assistance/policy_revision",schemaPath:"#/oneOf/2/properties/assistance/properties/policy_revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err277];
}
else {
vErrors.push(err277);
}
errors++;
}
}
var valid36 = _errs255 === errors;
}
else {
var valid36 = true;
}
if(valid36){
if(data96.range !== undefined){
let data105 = data96.range;
const _errs257 = errors;
const _errs258 = errors;
let valid38 = false;
const _errs259 = errors;
if(errors === _errs259){
if(data105 && typeof data105 == "object" && !Array.isArray(data105)){
let missing26;
if((((data105.start === undefined) && (missing26 = "start")) || ((data105.end === undefined) && (missing26 = "end"))) || ((data105.quoted === undefined) && (missing26 = "quoted"))){
const err278 = {instancePath:instancePath+"/assistance/range",schemaPath:"#/oneOf/2/properties/assistance/properties/range/anyOf/0/required",keyword:"required",params:{missingProperty: missing26},message:"must have required property '"+missing26+"'"};
if(vErrors === null){
vErrors = [err278];
}
else {
vErrors.push(err278);
}
errors++;
}
else {
const _errs261 = errors;
for(const key26 in data105){
if(!(((key26 === "start") || (key26 === "end")) || (key26 === "quoted"))){
const err279 = {instancePath:instancePath+"/assistance/range",schemaPath:"#/oneOf/2/properties/assistance/properties/range/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key26},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err279];
}
else {
vErrors.push(err279);
}
errors++;
break;
}
}
if(_errs261 === errors){
if(data105.start !== undefined){
let data106 = data105.start;
const _errs262 = errors;
if(!(((typeof data106 == "number") && (!(data106 % 1) && !isNaN(data106))) && (isFinite(data106)))){
const err280 = {instancePath:instancePath+"/assistance/range/start",schemaPath:"#/oneOf/2/properties/assistance/properties/range/anyOf/0/properties/start/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err280];
}
else {
vErrors.push(err280);
}
errors++;
}
if(errors === _errs262){
if((typeof data106 == "number") && (isFinite(data106))){
if(data106 > 65535 || isNaN(data106)){
const err281 = {instancePath:instancePath+"/assistance/range/start",schemaPath:"#/oneOf/2/properties/assistance/properties/range/anyOf/0/properties/start/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
if(vErrors === null){
vErrors = [err281];
}
else {
vErrors.push(err281);
}
errors++;
}
else {
if(data106 < 0 || isNaN(data106)){
const err282 = {instancePath:instancePath+"/assistance/range/start",schemaPath:"#/oneOf/2/properties/assistance/properties/range/anyOf/0/properties/start/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid39 = _errs262 === errors;
}
else {
var valid39 = true;
}
if(valid39){
if(data105.end !== undefined){
let data107 = data105.end;
const _errs264 = errors;
if(!(((typeof data107 == "number") && (!(data107 % 1) && !isNaN(data107))) && (isFinite(data107)))){
const err283 = {instancePath:instancePath+"/assistance/range/end",schemaPath:"#/oneOf/2/properties/assistance/properties/range/anyOf/0/properties/end/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err283];
}
else {
vErrors.push(err283);
}
errors++;
}
if(errors === _errs264){
if((typeof data107 == "number") && (isFinite(data107))){
if(data107 > 65535 || isNaN(data107)){
const err284 = {instancePath:instancePath+"/assistance/range/end",schemaPath:"#/oneOf/2/properties/assistance/properties/range/anyOf/0/properties/end/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
if(vErrors === null){
vErrors = [err284];
}
else {
vErrors.push(err284);
}
errors++;
}
else {
if(data107 < 0 || isNaN(data107)){
const err285 = {instancePath:instancePath+"/assistance/range/end",schemaPath:"#/oneOf/2/properties/assistance/properties/range/anyOf/0/properties/end/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err285];
}
else {
vErrors.push(err285);
}
errors++;
}
}
}
}
var valid39 = _errs264 === errors;
}
else {
var valid39 = true;
}
if(valid39){
if(data105.quoted !== undefined){
const _errs266 = errors;
if(typeof data105.quoted !== "boolean"){
const err286 = {instancePath:instancePath+"/assistance/range/quoted",schemaPath:"#/oneOf/2/properties/assistance/properties/range/anyOf/0/properties/quoted/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err286];
}
else {
vErrors.push(err286);
}
errors++;
}
var valid39 = _errs266 === errors;
}
else {
var valid39 = true;
}
}
}
}
}
}
else {
const err287 = {instancePath:instancePath+"/assistance/range",schemaPath:"#/oneOf/2/properties/assistance/properties/range/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err287];
}
else {
vErrors.push(err287);
}
errors++;
}
}
var _valid4 = _errs259 === errors;
valid38 = valid38 || _valid4;
const _errs268 = errors;
if(data105 !== null){
const err288 = {instancePath:instancePath+"/assistance/range",schemaPath:"#/oneOf/2/properties/assistance/properties/range/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err288];
}
else {
vErrors.push(err288);
}
errors++;
}
var _valid4 = _errs268 === errors;
valid38 = valid38 || _valid4;
if(!valid38){
const err289 = {instancePath:instancePath+"/assistance/range",schemaPath:"#/oneOf/2/properties/assistance/properties/range/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err289];
}
else {
vErrors.push(err289);
}
errors++;
}
else {
errors = _errs258;
if(vErrors !== null){
if(_errs258){
vErrors.length = _errs258;
}
else {
vErrors = null;
}
}
}
var valid36 = _errs257 === errors;
}
else {
var valid36 = true;
}
if(valid36){
if(data96.items !== undefined){
let data109 = data96.items;
const _errs270 = errors;
if(errors === _errs270){
if(Array.isArray(data109)){
if(data109.length > 8){
const err290 = {instancePath:instancePath+"/assistance/items",schemaPath:"#/oneOf/2/properties/assistance/properties/items/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err290];
}
else {
vErrors.push(err290);
}
errors++;
}
else {
var valid40 = true;
const len8 = data109.length;
for(let i8=0; i8<len8; i8++){
let data110 = data109[i8];
const _errs272 = errors;
if(errors === _errs272){
if(data110 && typeof data110 == "object" && !Array.isArray(data110)){
let missing27;
if((((data110.text === undefined) && (missing27 = "text")) || ((data110.kind === undefined) && (missing27 = "kind"))) || ((data110.detail === undefined) && (missing27 = "detail"))){
const err291 = {instancePath:instancePath+"/assistance/items/" + i8,schemaPath:"#/oneOf/2/properties/assistance/properties/items/items/required",keyword:"required",params:{missingProperty: missing27},message:"must have required property '"+missing27+"'"};
if(vErrors === null){
vErrors = [err291];
}
else {
vErrors.push(err291);
}
errors++;
}
else {
const _errs274 = errors;
for(const key27 in data110){
if(!(((key27 === "text") || (key27 === "kind")) || (key27 === "detail"))){
const err292 = {instancePath:instancePath+"/assistance/items/" + i8,schemaPath:"#/oneOf/2/properties/assistance/properties/items/items/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key27},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err292];
}
else {
vErrors.push(err292);
}
errors++;
break;
}
}
if(_errs274 === errors){
if(data110.text !== undefined){
let data111 = data110.text;
const _errs275 = errors;
if(errors === _errs275){
if(typeof data111 === "string"){
if(func1(data111) > 131072){
const err293 = {instancePath:instancePath+"/assistance/items/" + i8+"/text",schemaPath:"#/oneOf/2/properties/assistance/properties/items/items/properties/text/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err293];
}
else {
vErrors.push(err293);
}
errors++;
}
}
else {
const err294 = {instancePath:instancePath+"/assistance/items/" + i8+"/text",schemaPath:"#/oneOf/2/properties/assistance/properties/items/items/properties/text/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err294];
}
else {
vErrors.push(err294);
}
errors++;
}
}
var valid41 = _errs275 === errors;
}
else {
var valid41 = true;
}
if(valid41){
if(data110.kind !== undefined){
let data112 = data110.kind;
const _errs277 = errors;
if(typeof data112 !== "string"){
const err295 = {instancePath:instancePath+"/assistance/items/" + i8+"/kind",schemaPath:"#/oneOf/2/properties/assistance/properties/items/items/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err295];
}
else {
vErrors.push(err295);
}
errors++;
}
if(!((((((data112 === "keyword") || (data112 === "source")) || (data112 === "column")) || (data112 === "symbol")) || (data112 === "literal")) || (data112 === "meta"))){
const err296 = {instancePath:instancePath+"/assistance/items/" + i8+"/kind",schemaPath:"#/oneOf/2/properties/assistance/properties/items/items/properties/kind/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[2].properties.assistance.properties.items.items.properties.kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err296];
}
else {
vErrors.push(err296);
}
errors++;
}
var valid41 = _errs277 === errors;
}
else {
var valid41 = true;
}
if(valid41){
if(data110.detail !== undefined){
let data113 = data110.detail;
const _errs279 = errors;
if(errors === _errs279){
if(typeof data113 === "string"){
if(func1(data113) > 131072){
const err297 = {instancePath:instancePath+"/assistance/items/" + i8+"/detail",schemaPath:"#/oneOf/2/properties/assistance/properties/items/items/properties/detail/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err297];
}
else {
vErrors.push(err297);
}
errors++;
}
}
else {
const err298 = {instancePath:instancePath+"/assistance/items/" + i8+"/detail",schemaPath:"#/oneOf/2/properties/assistance/properties/items/items/properties/detail/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err298];
}
else {
vErrors.push(err298);
}
errors++;
}
}
var valid41 = _errs279 === errors;
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
const err299 = {instancePath:instancePath+"/assistance/items/" + i8,schemaPath:"#/oneOf/2/properties/assistance/properties/items/items/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err299];
}
else {
vErrors.push(err299);
}
errors++;
}
}
var valid40 = _errs272 === errors;
if(!valid40){
break;
}
}
}
}
else {
const err300 = {instancePath:instancePath+"/assistance/items",schemaPath:"#/oneOf/2/properties/assistance/properties/items/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err300];
}
else {
vErrors.push(err300);
}
errors++;
}
}
var valid36 = _errs270 === errors;
}
else {
var valid36 = true;
}
}
}
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
const err301 = {instancePath:instancePath+"/assistance",schemaPath:"#/oneOf/2/properties/assistance/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err302 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err302];
}
else {
vErrors.push(err302);
}
errors++;
}
}
var _valid0 = _errs235 === errors;
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
const _errs281 = errors;
if(errors === _errs281){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing28;
if((data.compiled === undefined) && (missing28 = "compiled")){
const err303 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing28},message:"must have required property '"+missing28+"'"};
if(vErrors === null){
vErrors = [err303];
}
else {
vErrors.push(err303);
}
errors++;
}
else {
const _errs283 = errors;
for(const key28 in data){
if(!(key28 === "compiled")){
const err304 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key28},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err304];
}
else {
vErrors.push(err304);
}
errors++;
break;
}
}
if(_errs283 === errors){
if(data.compiled !== undefined){
let data114 = data.compiled;
const _errs284 = errors;
if(errors === _errs284){
if(data114 && typeof data114 == "object" && !Array.isArray(data114)){
let missing29;
if(((((((data114.bundle === undefined) && (missing29 = "bundle")) || ((data114.source === undefined) && (missing29 = "source"))) || ((data114.plan === undefined) && (missing29 = "plan"))) || ((data114.limits === undefined) && (missing29 = "limits"))) || ((data114.contract === undefined) && (missing29 = "contract"))) || ((data114.schema === undefined) && (missing29 = "schema"))){
const err305 = {instancePath:instancePath+"/compiled",schemaPath:"#/oneOf/3/properties/compiled/required",keyword:"required",params:{missingProperty: missing29},message:"must have required property '"+missing29+"'"};
if(vErrors === null){
vErrors = [err305];
}
else {
vErrors.push(err305);
}
errors++;
}
else {
const _errs286 = errors;
for(const key29 in data114){
if(!((((((key29 === "bundle") || (key29 === "source")) || (key29 === "plan")) || (key29 === "limits")) || (key29 === "contract")) || (key29 === "schema"))){
const err306 = {instancePath:instancePath+"/compiled",schemaPath:"#/oneOf/3/properties/compiled/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key29},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err306];
}
else {
vErrors.push(err306);
}
errors++;
break;
}
}
if(_errs286 === errors){
if(data114.bundle !== undefined){
let data115 = data114.bundle;
const _errs287 = errors;
if(errors === _errs287){
if(typeof data115 === "string"){
if(func1(data115) > 131072){
const err307 = {instancePath:instancePath+"/compiled/bundle",schemaPath:"#/oneOf/3/properties/compiled/properties/bundle/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err307];
}
else {
vErrors.push(err307);
}
errors++;
}
}
else {
const err308 = {instancePath:instancePath+"/compiled/bundle",schemaPath:"#/oneOf/3/properties/compiled/properties/bundle/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err308];
}
else {
vErrors.push(err308);
}
errors++;
}
}
var valid43 = _errs287 === errors;
}
else {
var valid43 = true;
}
if(valid43){
if(data114.source !== undefined){
let data116 = data114.source;
const _errs289 = errors;
if(errors === _errs289){
if(data116 && typeof data116 == "object" && !Array.isArray(data116)){
let missing30;
if((((data116.version === undefined) && (missing30 = "version")) || ((data116.resource === undefined) && (missing30 = "resource"))) || ((data116.source === undefined) && (missing30 = "source"))){
const err309 = {instancePath:instancePath+"/compiled/source",schemaPath:"#/oneOf/3/properties/compiled/properties/source/required",keyword:"required",params:{missingProperty: missing30},message:"must have required property '"+missing30+"'"};
if(vErrors === null){
vErrors = [err309];
}
else {
vErrors.push(err309);
}
errors++;
}
else {
const _errs291 = errors;
for(const key30 in data116){
if(!(((key30 === "version") || (key30 === "resource")) || (key30 === "source"))){
const err310 = {instancePath:instancePath+"/compiled/source",schemaPath:"#/oneOf/3/properties/compiled/properties/source/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key30},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err310];
}
else {
vErrors.push(err310);
}
errors++;
break;
}
}
if(_errs291 === errors){
if(data116.version !== undefined){
let data117 = data116.version;
const _errs292 = errors;
if(!(((typeof data117 == "number") && (!(data117 % 1) && !isNaN(data117))) && (isFinite(data117)))){
const err311 = {instancePath:instancePath+"/compiled/source/version",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err311];
}
else {
vErrors.push(err311);
}
errors++;
}
if(errors === _errs292){
if((typeof data117 == "number") && (isFinite(data117))){
if(data117 > 255 || isNaN(data117)){
const err312 = {instancePath:instancePath+"/compiled/source/version",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/version/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err312];
}
else {
vErrors.push(err312);
}
errors++;
}
else {
if(data117 < 0 || isNaN(data117)){
const err313 = {instancePath:instancePath+"/compiled/source/version",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/version/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err313];
}
else {
vErrors.push(err313);
}
errors++;
}
}
}
}
var valid44 = _errs292 === errors;
}
else {
var valid44 = true;
}
if(valid44){
if(data116.resource !== undefined){
let data118 = data116.resource;
const _errs294 = errors;
if(!(((typeof data118 == "number") && (!(data118 % 1) && !isNaN(data118))) && (isFinite(data118)))){
const err314 = {instancePath:instancePath+"/compiled/source/resource",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/resource/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err314];
}
else {
vErrors.push(err314);
}
errors++;
}
if(errors === _errs294){
if((typeof data118 == "number") && (isFinite(data118))){
if(data118 > 9007199254740991 || isNaN(data118)){
const err315 = {instancePath:instancePath+"/compiled/source/resource",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/resource/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err315];
}
else {
vErrors.push(err315);
}
errors++;
}
else {
if(data118 < 0 || isNaN(data118)){
const err316 = {instancePath:instancePath+"/compiled/source/resource",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/resource/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err316];
}
else {
vErrors.push(err316);
}
errors++;
}
}
}
}
var valid44 = _errs294 === errors;
}
else {
var valid44 = true;
}
if(valid44){
if(data116.source !== undefined){
let data119 = data116.source;
const _errs296 = errors;
const _errs297 = errors;
let valid45 = false;
let passing2 = null;
const _errs298 = errors;
if(errors === _errs298){
if(data119 && typeof data119 == "object" && !Array.isArray(data119)){
let missing31;
if((data119.kv === undefined) && (missing31 = "kv")){
const err317 = {instancePath:instancePath+"/compiled/source/source",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/0/required",keyword:"required",params:{missingProperty: missing31},message:"must have required property '"+missing31+"'"};
if(vErrors === null){
vErrors = [err317];
}
else {
vErrors.push(err317);
}
errors++;
}
else {
const _errs300 = errors;
for(const key31 in data119){
if(!(key31 === "kv")){
const err318 = {instancePath:instancePath+"/compiled/source/source",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key31},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err318];
}
else {
vErrors.push(err318);
}
errors++;
break;
}
}
if(_errs300 === errors){
if(data119.kv !== undefined){
let data120 = data119.kv;
const _errs301 = errors;
if(errors === _errs301){
if(data120 && typeof data120 == "object" && !Array.isArray(data120)){
let missing32;
if((((data120.prefix === undefined) && (missing32 = "prefix")) || ((data120.key === undefined) && (missing32 = "key"))) || ((data120.value === undefined) && (missing32 = "value"))){
const err319 = {instancePath:instancePath+"/compiled/source/source/kv",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/required",keyword:"required",params:{missingProperty: missing32},message:"must have required property '"+missing32+"'"};
if(vErrors === null){
vErrors = [err319];
}
else {
vErrors.push(err319);
}
errors++;
}
else {
const _errs303 = errors;
for(const key32 in data120){
if(!(((key32 === "prefix") || (key32 === "key")) || (key32 === "value"))){
const err320 = {instancePath:instancePath+"/compiled/source/source/kv",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key32},message:"must NOT have additional properties"};
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
if(_errs303 === errors){
if(data120.prefix !== undefined){
let data121 = data120.prefix;
const _errs304 = errors;
if(errors === _errs304){
if(typeof data121 === "string"){
if(func1(data121) > 131072){
const err321 = {instancePath:instancePath+"/compiled/source/source/kv/prefix",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/prefix/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err321];
}
else {
vErrors.push(err321);
}
errors++;
}
}
else {
const err322 = {instancePath:instancePath+"/compiled/source/source/kv/prefix",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/prefix/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err322];
}
else {
vErrors.push(err322);
}
errors++;
}
}
var valid47 = _errs304 === errors;
}
else {
var valid47 = true;
}
if(valid47){
if(data120.key !== undefined){
let data122 = data120.key;
const _errs306 = errors;
if(errors === _errs306){
if(data122 && typeof data122 == "object" && !Array.isArray(data122)){
let missing33;
if(((data122.version === undefined) && (missing33 = "version")) || ((data122.type === undefined) && (missing33 = "type"))){
const err323 = {instancePath:instancePath+"/compiled/source/source/kv/key",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/key/required",keyword:"required",params:{missingProperty: missing33},message:"must have required property '"+missing33+"'"};
if(vErrors === null){
vErrors = [err323];
}
else {
vErrors.push(err323);
}
errors++;
}
else {
const _errs308 = errors;
for(const key33 in data122){
if(!((key33 === "version") || (key33 === "type"))){
const err324 = {instancePath:instancePath+"/compiled/source/source/kv/key",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/key/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key33},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err324];
}
else {
vErrors.push(err324);
}
errors++;
break;
}
}
if(_errs308 === errors){
if(data122.version !== undefined){
let data123 = data122.version;
const _errs309 = errors;
if(!(((typeof data123 == "number") && (!(data123 % 1) && !isNaN(data123))) && (isFinite(data123)))){
const err325 = {instancePath:instancePath+"/compiled/source/source/kv/key/version",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/key/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err325];
}
else {
vErrors.push(err325);
}
errors++;
}
if(errors === _errs309){
if((typeof data123 == "number") && (isFinite(data123))){
if(data123 > 255 || isNaN(data123)){
const err326 = {instancePath:instancePath+"/compiled/source/source/kv/key/version",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/key/properties/version/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err326];
}
else {
vErrors.push(err326);
}
errors++;
}
else {
if(data123 < 0 || isNaN(data123)){
const err327 = {instancePath:instancePath+"/compiled/source/source/kv/key/version",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/key/properties/version/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err327];
}
else {
vErrors.push(err327);
}
errors++;
}
}
}
}
var valid48 = _errs309 === errors;
}
else {
var valid48 = true;
}
if(valid48){
if(data122.type !== undefined){
let data124 = data122.type;
const _errs311 = errors;
if(typeof data124 !== "string"){
const err328 = {instancePath:instancePath+"/compiled/source/source/kv/key/type",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/key/properties/type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err328];
}
else {
vErrors.push(err328);
}
errors++;
}
if(!((((((data124 === "int64") || (data124 === "uint64")) || (data124 === "float64")) || (data124 === "boolean")) || (data124 === "utf8")) || (data124 === "binary"))){
const err329 = {instancePath:instancePath+"/compiled/source/source/kv/key/type",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/key/properties/type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[3].properties.compiled.properties.source.properties.source.oneOf[0].properties.kv.properties.key.properties.type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err329];
}
else {
vErrors.push(err329);
}
errors++;
}
var valid48 = _errs311 === errors;
}
else {
var valid48 = true;
}
}
}
}
}
else {
const err330 = {instancePath:instancePath+"/compiled/source/source/kv/key",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/key/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err330];
}
else {
vErrors.push(err330);
}
errors++;
}
}
var valid47 = _errs306 === errors;
}
else {
var valid47 = true;
}
if(valid47){
if(data120.value !== undefined){
let data125 = data120.value;
const _errs313 = errors;
if(errors === _errs313){
if(data125 && typeof data125 == "object" && !Array.isArray(data125)){
let missing34;
if(((data125.version === undefined) && (missing34 = "version")) || ((data125.type === undefined) && (missing34 = "type"))){
const err331 = {instancePath:instancePath+"/compiled/source/source/kv/value",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/value/required",keyword:"required",params:{missingProperty: missing34},message:"must have required property '"+missing34+"'"};
if(vErrors === null){
vErrors = [err331];
}
else {
vErrors.push(err331);
}
errors++;
}
else {
const _errs315 = errors;
for(const key34 in data125){
if(!((key34 === "version") || (key34 === "type"))){
const err332 = {instancePath:instancePath+"/compiled/source/source/kv/value",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/value/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key34},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err332];
}
else {
vErrors.push(err332);
}
errors++;
break;
}
}
if(_errs315 === errors){
if(data125.version !== undefined){
let data126 = data125.version;
const _errs316 = errors;
if(!(((typeof data126 == "number") && (!(data126 % 1) && !isNaN(data126))) && (isFinite(data126)))){
const err333 = {instancePath:instancePath+"/compiled/source/source/kv/value/version",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/value/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err333];
}
else {
vErrors.push(err333);
}
errors++;
}
if(errors === _errs316){
if((typeof data126 == "number") && (isFinite(data126))){
if(data126 > 255 || isNaN(data126)){
const err334 = {instancePath:instancePath+"/compiled/source/source/kv/value/version",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/value/properties/version/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err334];
}
else {
vErrors.push(err334);
}
errors++;
}
else {
if(data126 < 0 || isNaN(data126)){
const err335 = {instancePath:instancePath+"/compiled/source/source/kv/value/version",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/value/properties/version/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err335];
}
else {
vErrors.push(err335);
}
errors++;
}
}
}
}
var valid49 = _errs316 === errors;
}
else {
var valid49 = true;
}
if(valid49){
if(data125.type !== undefined){
let data127 = data125.type;
const _errs318 = errors;
if(typeof data127 !== "string"){
const err336 = {instancePath:instancePath+"/compiled/source/source/kv/value/type",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/value/properties/type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err336];
}
else {
vErrors.push(err336);
}
errors++;
}
if(!((((((data127 === "int64") || (data127 === "uint64")) || (data127 === "float64")) || (data127 === "boolean")) || (data127 === "utf8")) || (data127 === "binary"))){
const err337 = {instancePath:instancePath+"/compiled/source/source/kv/value/type",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/value/properties/type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[3].properties.compiled.properties.source.properties.source.oneOf[0].properties.kv.properties.value.properties.type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err337];
}
else {
vErrors.push(err337);
}
errors++;
}
var valid49 = _errs318 === errors;
}
else {
var valid49 = true;
}
}
}
}
}
else {
const err338 = {instancePath:instancePath+"/compiled/source/source/kv/value",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/value/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err338];
}
else {
vErrors.push(err338);
}
errors++;
}
}
var valid47 = _errs313 === errors;
}
else {
var valid47 = true;
}
}
}
}
}
}
else {
const err339 = {instancePath:instancePath+"/compiled/source/source/kv",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err339];
}
else {
vErrors.push(err339);
}
errors++;
}
}
}
}
}
}
else {
const err340 = {instancePath:instancePath+"/compiled/source/source",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err340];
}
else {
vErrors.push(err340);
}
errors++;
}
}
var _valid5 = _errs298 === errors;
if(_valid5){
valid45 = true;
passing2 = 0;
var props3 = true;
}
const _errs320 = errors;
if(errors === _errs320){
if(data119 && typeof data119 == "object" && !Array.isArray(data119)){
let missing35;
if((data119.table === undefined) && (missing35 = "table")){
const err341 = {instancePath:instancePath+"/compiled/source/source",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/1/required",keyword:"required",params:{missingProperty: missing35},message:"must have required property '"+missing35+"'"};
if(vErrors === null){
vErrors = [err341];
}
else {
vErrors.push(err341);
}
errors++;
}
else {
const _errs322 = errors;
for(const key35 in data119){
if(!(key35 === "table")){
const err342 = {instancePath:instancePath+"/compiled/source/source",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key35},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err342];
}
else {
vErrors.push(err342);
}
errors++;
break;
}
}
if(_errs322 === errors){
if(data119.table !== undefined){
let data128 = data119.table;
const _errs323 = errors;
if(errors === _errs323){
if(data128 && typeof data128 == "object" && !Array.isArray(data128)){
let missing36;
if((((data128.id === undefined) && (missing36 = "id")) || ((data128.names === undefined) && (missing36 = "names"))) || ((data128.value_type === undefined) && (missing36 = "value_type"))){
const err343 = {instancePath:instancePath+"/compiled/source/source/table",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/required",keyword:"required",params:{missingProperty: missing36},message:"must have required property '"+missing36+"'"};
if(vErrors === null){
vErrors = [err343];
}
else {
vErrors.push(err343);
}
errors++;
}
else {
const _errs325 = errors;
for(const key36 in data128){
if(!(((key36 === "id") || (key36 === "names")) || (key36 === "value_type"))){
const err344 = {instancePath:instancePath+"/compiled/source/source/table",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key36},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err344];
}
else {
vErrors.push(err344);
}
errors++;
break;
}
}
if(_errs325 === errors){
if(data128.id !== undefined){
let data129 = data128.id;
const _errs326 = errors;
if(!(((typeof data129 == "number") && (!(data129 % 1) && !isNaN(data129))) && (isFinite(data129)))){
const err345 = {instancePath:instancePath+"/compiled/source/source/table/id",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/properties/id/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err345];
}
else {
vErrors.push(err345);
}
errors++;
}
if(errors === _errs326){
if((typeof data129 == "number") && (isFinite(data129))){
if(data129 > 4294967295 || isNaN(data129)){
const err346 = {instancePath:instancePath+"/compiled/source/source/table/id",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/properties/id/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err346];
}
else {
vErrors.push(err346);
}
errors++;
}
else {
if(data129 < 0 || isNaN(data129)){
const err347 = {instancePath:instancePath+"/compiled/source/source/table/id",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/properties/id/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err347];
}
else {
vErrors.push(err347);
}
errors++;
}
}
}
}
var valid51 = _errs326 === errors;
}
else {
var valid51 = true;
}
if(valid51){
if(data128.names !== undefined){
let data130 = data128.names;
const _errs328 = errors;
if(errors === _errs328){
if(Array.isArray(data130)){
if(data130.length > 2){
const err348 = {instancePath:instancePath+"/compiled/source/source/table/names",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/properties/names/maxItems",keyword:"maxItems",params:{limit: 2},message:"must NOT have more than 2 items"};
if(vErrors === null){
vErrors = [err348];
}
else {
vErrors.push(err348);
}
errors++;
}
else {
if(data130.length < 2){
const err349 = {instancePath:instancePath+"/compiled/source/source/table/names",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/properties/names/minItems",keyword:"minItems",params:{limit: 2},message:"must NOT have fewer than 2 items"};
if(vErrors === null){
vErrors = [err349];
}
else {
vErrors.push(err349);
}
errors++;
}
else {
var valid52 = true;
const len9 = data130.length;
for(let i9=0; i9<len9; i9++){
let data131 = data130[i9];
const _errs330 = errors;
if(errors === _errs330){
if(typeof data131 === "string"){
if(func1(data131) > 131072){
const err350 = {instancePath:instancePath+"/compiled/source/source/table/names/" + i9,schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/properties/names/items/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err350];
}
else {
vErrors.push(err350);
}
errors++;
}
}
else {
const err351 = {instancePath:instancePath+"/compiled/source/source/table/names/" + i9,schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/properties/names/items/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err351];
}
else {
vErrors.push(err351);
}
errors++;
}
}
var valid52 = _errs330 === errors;
if(!valid52){
break;
}
}
}
}
}
else {
const err352 = {instancePath:instancePath+"/compiled/source/source/table/names",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/properties/names/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err352];
}
else {
vErrors.push(err352);
}
errors++;
}
}
var valid51 = _errs328 === errors;
}
else {
var valid51 = true;
}
if(valid51){
if(data128.value_type !== undefined){
let data132 = data128.value_type;
const _errs332 = errors;
if(typeof data132 !== "string"){
const err353 = {instancePath:instancePath+"/compiled/source/source/table/value_type",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/properties/value_type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err353];
}
else {
vErrors.push(err353);
}
errors++;
}
if(!((((data132 === "int64") || (data132 === "boolean")) || (data132 === "utf8")) || (data132 === "binary"))){
const err354 = {instancePath:instancePath+"/compiled/source/source/table/value_type",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/properties/value_type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[3].properties.compiled.properties.source.properties.source.oneOf[1].properties.table.properties.value_type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err354];
}
else {
vErrors.push(err354);
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
}
else {
const err355 = {instancePath:instancePath+"/compiled/source/source/table",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err356 = {instancePath:instancePath+"/compiled/source/source",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err356];
}
else {
vErrors.push(err356);
}
errors++;
}
}
var _valid5 = _errs320 === errors;
if(_valid5 && valid45){
valid45 = false;
passing2 = [passing2, 1];
}
else {
if(_valid5){
valid45 = true;
passing2 = 1;
if(props3 !== true){
props3 = true;
}
}
const _errs334 = errors;
if(errors === _errs334){
if(data119 && typeof data119 == "object" && !Array.isArray(data119)){
let missing37;
if((data119.document === undefined) && (missing37 = "document")){
const err357 = {instancePath:instancePath+"/compiled/source/source",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/required",keyword:"required",params:{missingProperty: missing37},message:"must have required property '"+missing37+"'"};
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
for(const key37 in data119){
if(!(key37 === "document")){
const err358 = {instancePath:instancePath+"/compiled/source/source",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key37},message:"must NOT have additional properties"};
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
if(data119.document !== undefined){
let data133 = data119.document;
const _errs337 = errors;
if(errors === _errs337){
if(data133 && typeof data133 == "object" && !Array.isArray(data133)){
let missing38;
if(((((data133.reference === undefined) && (missing38 = "reference")) || ((data133.change_format === undefined) && (missing38 = "change_format"))) || ((data133.expand === undefined) && (missing38 = "expand"))) || ((data133.projections === undefined) && (missing38 = "projections"))){
const err359 = {instancePath:instancePath+"/compiled/source/source/document",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/required",keyword:"required",params:{missingProperty: missing38},message:"must have required property '"+missing38+"'"};
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
if(!((((key38 === "reference") || (key38 === "change_format")) || (key38 === "expand")) || (key38 === "projections"))){
const err360 = {instancePath:instancePath+"/compiled/source/source/document",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key38},message:"must NOT have additional properties"};
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
if(data133.reference !== undefined){
let data134 = data133.reference;
const _errs340 = errors;
if(errors === _errs340){
if(data134 && typeof data134 == "object" && !Array.isArray(data134)){
let missing39;
if((((((data134.resource === undefined) && (missing39 = "resource")) || ((data134.document === undefined) && (missing39 = "document"))) || ((data134.epoch === undefined) && (missing39 = "epoch"))) || ((data134.type_revision === undefined) && (missing39 = "type_revision"))) || ((data134.revision === undefined) && (missing39 = "revision"))){
const err361 = {instancePath:instancePath+"/compiled/source/source/document/reference",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/required",keyword:"required",params:{missingProperty: missing39},message:"must have required property '"+missing39+"'"};
if(vErrors === null){
vErrors = [err361];
}
else {
vErrors.push(err361);
}
errors++;
}
else {
const _errs342 = errors;
for(const key39 in data134){
if(!(((((key39 === "resource") || (key39 === "document")) || (key39 === "epoch")) || (key39 === "type_revision")) || (key39 === "revision"))){
const err362 = {instancePath:instancePath+"/compiled/source/source/document/reference",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key39},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err362];
}
else {
vErrors.push(err362);
}
errors++;
break;
}
}
if(_errs342 === errors){
if(data134.resource !== undefined){
let data135 = data134.resource;
const _errs343 = errors;
if(!(((typeof data135 == "number") && (!(data135 % 1) && !isNaN(data135))) && (isFinite(data135)))){
const err363 = {instancePath:instancePath+"/compiled/source/source/document/reference/resource",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/resource/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err363];
}
else {
vErrors.push(err363);
}
errors++;
}
if(errors === _errs343){
if((typeof data135 == "number") && (isFinite(data135))){
if(data135 > 9007199254740991 || isNaN(data135)){
const err364 = {instancePath:instancePath+"/compiled/source/source/document/reference/resource",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/resource/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err364];
}
else {
vErrors.push(err364);
}
errors++;
}
else {
if(data135 < 0 || isNaN(data135)){
const err365 = {instancePath:instancePath+"/compiled/source/source/document/reference/resource",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/resource/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err365];
}
else {
vErrors.push(err365);
}
errors++;
}
}
}
}
var valid55 = _errs343 === errors;
}
else {
var valid55 = true;
}
if(valid55){
if(data134.document !== undefined){
let data136 = data134.document;
const _errs345 = errors;
if(errors === _errs345){
if(typeof data136 === "string"){
if(func1(data136) > 131072){
const err366 = {instancePath:instancePath+"/compiled/source/source/document/reference/document",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/document/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err367 = {instancePath:instancePath+"/compiled/source/source/document/reference/document",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/document/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err367];
}
else {
vErrors.push(err367);
}
errors++;
}
}
var valid55 = _errs345 === errors;
}
else {
var valid55 = true;
}
if(valid55){
if(data134.epoch !== undefined){
let data137 = data134.epoch;
const _errs347 = errors;
if(errors === _errs347){
if(typeof data137 === "string"){
if(func1(data137) > 131072){
const err368 = {instancePath:instancePath+"/compiled/source/source/document/reference/epoch",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/epoch/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err368];
}
else {
vErrors.push(err368);
}
errors++;
}
}
else {
const err369 = {instancePath:instancePath+"/compiled/source/source/document/reference/epoch",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/epoch/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err369];
}
else {
vErrors.push(err369);
}
errors++;
}
}
var valid55 = _errs347 === errors;
}
else {
var valid55 = true;
}
if(valid55){
if(data134.type_revision !== undefined){
let data138 = data134.type_revision;
const _errs349 = errors;
if(!(((typeof data138 == "number") && (!(data138 % 1) && !isNaN(data138))) && (isFinite(data138)))){
const err370 = {instancePath:instancePath+"/compiled/source/source/document/reference/type_revision",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/type_revision/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err370];
}
else {
vErrors.push(err370);
}
errors++;
}
if(errors === _errs349){
if((typeof data138 == "number") && (isFinite(data138))){
if(data138 > 4294967295 || isNaN(data138)){
const err371 = {instancePath:instancePath+"/compiled/source/source/document/reference/type_revision",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/type_revision/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err371];
}
else {
vErrors.push(err371);
}
errors++;
}
else {
if(data138 < 0 || isNaN(data138)){
const err372 = {instancePath:instancePath+"/compiled/source/source/document/reference/type_revision",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/type_revision/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err372];
}
else {
vErrors.push(err372);
}
errors++;
}
}
}
}
var valid55 = _errs349 === errors;
}
else {
var valid55 = true;
}
if(valid55){
if(data134.revision !== undefined){
let data139 = data134.revision;
const _errs351 = errors;
if(errors === _errs351){
if(typeof data139 === "string"){
if(func1(data139) > 131072){
const err373 = {instancePath:instancePath+"/compiled/source/source/document/reference/revision",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/revision/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err373];
}
else {
vErrors.push(err373);
}
errors++;
}
}
else {
const err374 = {instancePath:instancePath+"/compiled/source/source/document/reference/revision",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err374];
}
else {
vErrors.push(err374);
}
errors++;
}
}
var valid55 = _errs351 === errors;
}
else {
var valid55 = true;
}
}
}
}
}
}
}
}
else {
const err375 = {instancePath:instancePath+"/compiled/source/source/document/reference",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err375];
}
else {
vErrors.push(err375);
}
errors++;
}
}
var valid54 = _errs340 === errors;
}
else {
var valid54 = true;
}
if(valid54){
if(data133.change_format !== undefined){
let data140 = data133.change_format;
const _errs353 = errors;
if(!(((typeof data140 == "number") && (!(data140 % 1) && !isNaN(data140))) && (isFinite(data140)))){
const err376 = {instancePath:instancePath+"/compiled/source/source/document/change_format",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/change_format/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err376];
}
else {
vErrors.push(err376);
}
errors++;
}
if(errors === _errs353){
if((typeof data140 == "number") && (isFinite(data140))){
if(data140 > 4294967295 || isNaN(data140)){
const err377 = {instancePath:instancePath+"/compiled/source/source/document/change_format",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/change_format/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err377];
}
else {
vErrors.push(err377);
}
errors++;
}
else {
if(data140 < 0 || isNaN(data140)){
const err378 = {instancePath:instancePath+"/compiled/source/source/document/change_format",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/change_format/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err378];
}
else {
vErrors.push(err378);
}
errors++;
}
}
}
}
var valid54 = _errs353 === errors;
}
else {
var valid54 = true;
}
if(valid54){
if(data133.expand !== undefined){
let data141 = data133.expand;
const _errs355 = errors;
const _errs356 = errors;
let valid56 = false;
const _errs357 = errors;
if(errors === _errs357){
if(Array.isArray(data141)){
if(data141.length > 8){
const err379 = {instancePath:instancePath+"/compiled/source/source/document/expand",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/expand/anyOf/0/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err379];
}
else {
vErrors.push(err379);
}
errors++;
}
else {
var valid57 = true;
const len10 = data141.length;
for(let i10=0; i10<len10; i10++){
let data142 = data141[i10];
const _errs359 = errors;
if(errors === _errs359){
if(typeof data142 === "string"){
if(func1(data142) > 131072){
const err380 = {instancePath:instancePath+"/compiled/source/source/document/expand/" + i10,schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/expand/anyOf/0/items/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err380];
}
else {
vErrors.push(err380);
}
errors++;
}
}
else {
const err381 = {instancePath:instancePath+"/compiled/source/source/document/expand/" + i10,schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/expand/anyOf/0/items/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err381];
}
else {
vErrors.push(err381);
}
errors++;
}
}
var valid57 = _errs359 === errors;
if(!valid57){
break;
}
}
}
}
else {
const err382 = {instancePath:instancePath+"/compiled/source/source/document/expand",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/expand/anyOf/0/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err382];
}
else {
vErrors.push(err382);
}
errors++;
}
}
var _valid6 = _errs357 === errors;
valid56 = valid56 || _valid6;
const _errs361 = errors;
if(data141 !== null){
const err383 = {instancePath:instancePath+"/compiled/source/source/document/expand",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/expand/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err383];
}
else {
vErrors.push(err383);
}
errors++;
}
var _valid6 = _errs361 === errors;
valid56 = valid56 || _valid6;
if(!valid56){
const err384 = {instancePath:instancePath+"/compiled/source/source/document/expand",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/expand/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err384];
}
else {
vErrors.push(err384);
}
errors++;
}
else {
errors = _errs356;
if(vErrors !== null){
if(_errs356){
vErrors.length = _errs356;
}
else {
vErrors = null;
}
}
}
var valid54 = _errs355 === errors;
}
else {
var valid54 = true;
}
if(valid54){
if(data133.projections !== undefined){
let data143 = data133.projections;
const _errs363 = errors;
if(errors === _errs363){
if(Array.isArray(data143)){
if(data143.length > 8){
const err385 = {instancePath:instancePath+"/compiled/source/source/document/projections",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err385];
}
else {
vErrors.push(err385);
}
errors++;
}
else {
var valid58 = true;
const len11 = data143.length;
for(let i11=0; i11<len11; i11++){
let data144 = data143[i11];
const _errs365 = errors;
if(errors === _errs365){
if(data144 && typeof data144 == "object" && !Array.isArray(data144)){
let missing40;
if(((((((data144.column === undefined) && (missing40 = "column")) || ((data144.path === undefined) && (missing40 = "path"))) || ((data144.relative === undefined) && (missing40 = "relative"))) || ((data144.mode === undefined) && (missing40 = "mode"))) || ((data144.text_bytes === undefined) && (missing40 = "text_bytes"))) || ((data144.text_steps === undefined) && (missing40 = "text_steps"))){
const err386 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11,schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/required",keyword:"required",params:{missingProperty: missing40},message:"must have required property '"+missing40+"'"};
if(vErrors === null){
vErrors = [err386];
}
else {
vErrors.push(err386);
}
errors++;
}
else {
const _errs367 = errors;
for(const key40 in data144){
if(!((((((key40 === "column") || (key40 === "path")) || (key40 === "relative")) || (key40 === "mode")) || (key40 === "text_bytes")) || (key40 === "text_steps"))){
const err387 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11,schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key40},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err387];
}
else {
vErrors.push(err387);
}
errors++;
break;
}
}
if(_errs367 === errors){
if(data144.column !== undefined){
let data145 = data144.column;
const _errs368 = errors;
if(errors === _errs368){
if(data145 && typeof data145 == "object" && !Array.isArray(data145)){
let missing41;
if(((data145.name === undefined) && (missing41 = "name")) || ((data145.type === undefined) && (missing41 = "type"))){
const err388 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/column",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/column/required",keyword:"required",params:{missingProperty: missing41},message:"must have required property '"+missing41+"'"};
if(vErrors === null){
vErrors = [err388];
}
else {
vErrors.push(err388);
}
errors++;
}
else {
const _errs370 = errors;
for(const key41 in data145){
if(!((key41 === "name") || (key41 === "type"))){
const err389 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/column",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/column/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key41},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err389];
}
else {
vErrors.push(err389);
}
errors++;
break;
}
}
if(_errs370 === errors){
if(data145.name !== undefined){
let data146 = data145.name;
const _errs371 = errors;
if(errors === _errs371){
if(typeof data146 === "string"){
if(func1(data146) > 131072){
const err390 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/column/name",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/column/properties/name/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err390];
}
else {
vErrors.push(err390);
}
errors++;
}
}
else {
const err391 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/column/name",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/column/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err391];
}
else {
vErrors.push(err391);
}
errors++;
}
}
var valid60 = _errs371 === errors;
}
else {
var valid60 = true;
}
if(valid60){
if(data145.type !== undefined){
let data147 = data145.type;
const _errs373 = errors;
if(typeof data147 !== "string"){
const err392 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/column/type",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/column/properties/type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err392];
}
else {
vErrors.push(err392);
}
errors++;
}
if(!((((((data147 === "int64") || (data147 === "uint64")) || (data147 === "float64")) || (data147 === "boolean")) || (data147 === "utf8")) || (data147 === "binary"))){
const err393 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/column/type",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/column/properties/type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[3].properties.compiled.properties.source.properties.source.oneOf[2].properties.document.properties.projections.items.properties.column.properties.type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err393];
}
else {
vErrors.push(err393);
}
errors++;
}
var valid60 = _errs373 === errors;
}
else {
var valid60 = true;
}
}
}
}
}
else {
const err394 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/column",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/column/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err394];
}
else {
vErrors.push(err394);
}
errors++;
}
}
var valid59 = _errs368 === errors;
}
else {
var valid59 = true;
}
if(valid59){
if(data144.path !== undefined){
let data148 = data144.path;
const _errs375 = errors;
if(errors === _errs375){
if(Array.isArray(data148)){
if(data148.length > 8){
const err395 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/path",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/path/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err395];
}
else {
vErrors.push(err395);
}
errors++;
}
else {
var valid61 = true;
const len12 = data148.length;
for(let i12=0; i12<len12; i12++){
let data149 = data148[i12];
const _errs377 = errors;
if(errors === _errs377){
if(typeof data149 === "string"){
if(func1(data149) > 131072){
const err396 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/path/" + i12,schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/path/items/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err397 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/path/" + i12,schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/path/items/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err397];
}
else {
vErrors.push(err397);
}
errors++;
}
}
var valid61 = _errs377 === errors;
if(!valid61){
break;
}
}
}
}
else {
const err398 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/path",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/path/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err398];
}
else {
vErrors.push(err398);
}
errors++;
}
}
var valid59 = _errs375 === errors;
}
else {
var valid59 = true;
}
if(valid59){
if(data144.relative !== undefined){
const _errs379 = errors;
if(typeof data144.relative !== "boolean"){
const err399 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/relative",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/relative/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err399];
}
else {
vErrors.push(err399);
}
errors++;
}
var valid59 = _errs379 === errors;
}
else {
var valid59 = true;
}
if(valid59){
if(data144.mode !== undefined){
let data151 = data144.mode;
const _errs381 = errors;
if(typeof data151 !== "string"){
const err400 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/mode",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/mode/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err400];
}
else {
vErrors.push(err400);
}
errors++;
}
if(!((((data151 === "scalar") || (data151 === "text")) || (data151 === "element_counter")) || (data151 === "element_replica"))){
const err401 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/mode",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/mode/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[3].properties.compiled.properties.source.properties.source.oneOf[2].properties.document.properties.projections.items.properties.mode.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err401];
}
else {
vErrors.push(err401);
}
errors++;
}
var valid59 = _errs381 === errors;
}
else {
var valid59 = true;
}
if(valid59){
if(data144.text_bytes !== undefined){
let data152 = data144.text_bytes;
const _errs383 = errors;
if(!(((typeof data152 == "number") && (!(data152 % 1) && !isNaN(data152))) && (isFinite(data152)))){
const err402 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/text_bytes",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/text_bytes/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err402];
}
else {
vErrors.push(err402);
}
errors++;
}
if(errors === _errs383){
if((typeof data152 == "number") && (isFinite(data152))){
if(data152 > 65535 || isNaN(data152)){
const err403 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/text_bytes",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/text_bytes/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
if(vErrors === null){
vErrors = [err403];
}
else {
vErrors.push(err403);
}
errors++;
}
else {
if(data152 < 0 || isNaN(data152)){
const err404 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/text_bytes",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/text_bytes/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err404];
}
else {
vErrors.push(err404);
}
errors++;
}
}
}
}
var valid59 = _errs383 === errors;
}
else {
var valid59 = true;
}
if(valid59){
if(data144.text_steps !== undefined){
let data153 = data144.text_steps;
const _errs385 = errors;
if(!(((typeof data153 == "number") && (!(data153 % 1) && !isNaN(data153))) && (isFinite(data153)))){
const err405 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/text_steps",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/text_steps/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err405];
}
else {
vErrors.push(err405);
}
errors++;
}
if(errors === _errs385){
if((typeof data153 == "number") && (isFinite(data153))){
if(data153 > 65535 || isNaN(data153)){
const err406 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/text_steps",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/text_steps/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
if(vErrors === null){
vErrors = [err406];
}
else {
vErrors.push(err406);
}
errors++;
}
else {
if(data153 < 0 || isNaN(data153)){
const err407 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/text_steps",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/text_steps/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err407];
}
else {
vErrors.push(err407);
}
errors++;
}
}
}
}
var valid59 = _errs385 === errors;
}
else {
var valid59 = true;
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
const err408 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11,schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err408];
}
else {
vErrors.push(err408);
}
errors++;
}
}
var valid58 = _errs365 === errors;
if(!valid58){
break;
}
}
}
}
else {
const err409 = {instancePath:instancePath+"/compiled/source/source/document/projections",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err409];
}
else {
vErrors.push(err409);
}
errors++;
}
}
var valid54 = _errs363 === errors;
}
else {
var valid54 = true;
}
}
}
}
}
}
}
else {
const err410 = {instancePath:instancePath+"/compiled/source/source/document",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err410];
}
else {
vErrors.push(err410);
}
errors++;
}
}
}
}
}
}
else {
const err411 = {instancePath:instancePath+"/compiled/source/source",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err411];
}
else {
vErrors.push(err411);
}
errors++;
}
}
var _valid5 = _errs334 === errors;
if(_valid5 && valid45){
valid45 = false;
passing2 = [passing2, 2];
}
else {
if(_valid5){
valid45 = true;
passing2 = 2;
if(props3 !== true){
props3 = true;
}
}
}
}
if(!valid45){
const err412 = {instancePath:instancePath+"/compiled/source/source",schemaPath:"#/oneOf/3/properties/compiled/properties/source/properties/source/oneOf",keyword:"oneOf",params:{passingSchemas: passing2},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err412];
}
else {
vErrors.push(err412);
}
errors++;
}
else {
errors = _errs297;
if(vErrors !== null){
if(_errs297){
vErrors.length = _errs297;
}
else {
vErrors = null;
}
}
}
var valid44 = _errs296 === errors;
}
else {
var valid44 = true;
}
}
}
}
}
}
else {
const err413 = {instancePath:instancePath+"/compiled/source",schemaPath:"#/oneOf/3/properties/compiled/properties/source/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err413];
}
else {
vErrors.push(err413);
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
if(data114.plan !== undefined){
let data154 = data114.plan;
const _errs387 = errors;
if(errors === _errs387){
if(data154 && typeof data154 == "object" && !Array.isArray(data154)){
let missing42;
if((((((data154.version === undefined) && (missing42 = "version")) || ((data154.projection === undefined) && (missing42 = "projection"))) || ((data154.limit === undefined) && (missing42 = "limit"))) || ((data154.aggregate === undefined) && (missing42 = "aggregate"))) || ((data154.predicate === undefined) && (missing42 = "predicate"))){
const err414 = {instancePath:instancePath+"/compiled/plan",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/required",keyword:"required",params:{missingProperty: missing42},message:"must have required property '"+missing42+"'"};
if(vErrors === null){
vErrors = [err414];
}
else {
vErrors.push(err414);
}
errors++;
}
else {
const _errs389 = errors;
for(const key42 in data154){
if(!(((((key42 === "version") || (key42 === "projection")) || (key42 === "limit")) || (key42 === "aggregate")) || (key42 === "predicate"))){
const err415 = {instancePath:instancePath+"/compiled/plan",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key42},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err415];
}
else {
vErrors.push(err415);
}
errors++;
break;
}
}
if(_errs389 === errors){
if(data154.version !== undefined){
let data155 = data154.version;
const _errs390 = errors;
if(!(((typeof data155 == "number") && (!(data155 % 1) && !isNaN(data155))) && (isFinite(data155)))){
const err416 = {instancePath:instancePath+"/compiled/plan/version",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err416];
}
else {
vErrors.push(err416);
}
errors++;
}
if(errors === _errs390){
if((typeof data155 == "number") && (isFinite(data155))){
if(data155 > 255 || isNaN(data155)){
const err417 = {instancePath:instancePath+"/compiled/plan/version",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/version/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err417];
}
else {
vErrors.push(err417);
}
errors++;
}
else {
if(data155 < 0 || isNaN(data155)){
const err418 = {instancePath:instancePath+"/compiled/plan/version",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/version/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err418];
}
else {
vErrors.push(err418);
}
errors++;
}
}
}
}
var valid62 = _errs390 === errors;
}
else {
var valid62 = true;
}
if(valid62){
if(data154.projection !== undefined){
let data156 = data154.projection;
const _errs392 = errors;
if(errors === _errs392){
if(Array.isArray(data156)){
if(data156.length > 8){
const err419 = {instancePath:instancePath+"/compiled/plan/projection",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/projection/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err419];
}
else {
vErrors.push(err419);
}
errors++;
}
else {
var valid63 = true;
const len13 = data156.length;
for(let i13=0; i13<len13; i13++){
let data157 = data156[i13];
const _errs394 = errors;
if(!(((typeof data157 == "number") && (!(data157 % 1) && !isNaN(data157))) && (isFinite(data157)))){
const err420 = {instancePath:instancePath+"/compiled/plan/projection/" + i13,schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/projection/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err420];
}
else {
vErrors.push(err420);
}
errors++;
}
if(errors === _errs394){
if((typeof data157 == "number") && (isFinite(data157))){
if(data157 > 4294967295 || isNaN(data157)){
const err421 = {instancePath:instancePath+"/compiled/plan/projection/" + i13,schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/projection/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err421];
}
else {
vErrors.push(err421);
}
errors++;
}
else {
if(data157 < 0 || isNaN(data157)){
const err422 = {instancePath:instancePath+"/compiled/plan/projection/" + i13,schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/projection/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err422];
}
else {
vErrors.push(err422);
}
errors++;
}
}
}
}
var valid63 = _errs394 === errors;
if(!valid63){
break;
}
}
}
}
else {
const err423 = {instancePath:instancePath+"/compiled/plan/projection",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/projection/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err423];
}
else {
vErrors.push(err423);
}
errors++;
}
}
var valid62 = _errs392 === errors;
}
else {
var valid62 = true;
}
if(valid62){
if(data154.limit !== undefined){
let data158 = data154.limit;
const _errs396 = errors;
const _errs397 = errors;
let valid64 = false;
const _errs398 = errors;
if(errors === _errs398){
if(typeof data158 === "string"){
if(func1(data158) > 131072){
const err424 = {instancePath:instancePath+"/compiled/plan/limit",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/limit/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err424];
}
else {
vErrors.push(err424);
}
errors++;
}
}
else {
const err425 = {instancePath:instancePath+"/compiled/plan/limit",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/limit/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err425];
}
else {
vErrors.push(err425);
}
errors++;
}
}
var _valid7 = _errs398 === errors;
valid64 = valid64 || _valid7;
const _errs400 = errors;
if(data158 !== null){
const err426 = {instancePath:instancePath+"/compiled/plan/limit",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/limit/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err426];
}
else {
vErrors.push(err426);
}
errors++;
}
var _valid7 = _errs400 === errors;
valid64 = valid64 || _valid7;
if(!valid64){
const err427 = {instancePath:instancePath+"/compiled/plan/limit",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/limit/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err427];
}
else {
vErrors.push(err427);
}
errors++;
}
else {
errors = _errs397;
if(vErrors !== null){
if(_errs397){
vErrors.length = _errs397;
}
else {
vErrors = null;
}
}
}
var valid62 = _errs396 === errors;
}
else {
var valid62 = true;
}
if(valid62){
if(data154.aggregate !== undefined){
let data159 = data154.aggregate;
const _errs402 = errors;
if(typeof data159 !== "string"){
const err428 = {instancePath:instancePath+"/compiled/plan/aggregate",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/aggregate/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err428];
}
else {
vErrors.push(err428);
}
errors++;
}
if(!(((data159 === "rows") || (data159 === "count")) || (data159 === "sum"))){
const err429 = {instancePath:instancePath+"/compiled/plan/aggregate",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/aggregate/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[3].properties.compiled.properties.plan.properties.aggregate.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err429];
}
else {
vErrors.push(err429);
}
errors++;
}
var valid62 = _errs402 === errors;
}
else {
var valid62 = true;
}
if(valid62){
if(data154.predicate !== undefined){
let data160 = data154.predicate;
const _errs404 = errors;
const _errs405 = errors;
let valid65 = false;
let passing3 = null;
const _errs406 = errors;
if(errors === _errs406){
if(data160 && typeof data160 == "object" && !Array.isArray(data160)){
let missing43;
if((data160.all === undefined) && (missing43 = "all")){
const err430 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/0/required",keyword:"required",params:{missingProperty: missing43},message:"must have required property '"+missing43+"'"};
if(vErrors === null){
vErrors = [err430];
}
else {
vErrors.push(err430);
}
errors++;
}
else {
const _errs408 = errors;
for(const key43 in data160){
if(!(key43 === "all")){
const err431 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key43},message:"must NOT have additional properties"};
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
if(_errs408 === errors){
if(data160.all !== undefined){
let data161 = data160.all;
const _errs409 = errors;
if(errors === _errs409){
if(data161 && typeof data161 == "object" && !Array.isArray(data161)){
if(Object.keys(data161).length > 0){
const err432 = {instancePath:instancePath+"/compiled/plan/predicate/all",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/0/properties/all/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err432];
}
else {
vErrors.push(err432);
}
errors++;
}
}
else {
const err433 = {instancePath:instancePath+"/compiled/plan/predicate/all",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/0/properties/all/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err433];
}
else {
vErrors.push(err433);
}
errors++;
}
}
}
}
}
}
else {
const err434 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err434];
}
else {
vErrors.push(err434);
}
errors++;
}
}
var _valid8 = _errs406 === errors;
if(_valid8){
valid65 = true;
passing3 = 0;
var props4 = true;
}
const _errs411 = errors;
if(errors === _errs411){
if(data160 && typeof data160 == "object" && !Array.isArray(data160)){
let missing44;
if((data160.state === undefined) && (missing44 = "state")){
const err435 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/1/required",keyword:"required",params:{missingProperty: missing44},message:"must have required property '"+missing44+"'"};
if(vErrors === null){
vErrors = [err435];
}
else {
vErrors.push(err435);
}
errors++;
}
else {
const _errs413 = errors;
for(const key44 in data160){
if(!(key44 === "state")){
const err436 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key44},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err436];
}
else {
vErrors.push(err436);
}
errors++;
break;
}
}
if(_errs413 === errors){
if(data160.state !== undefined){
let data162 = data160.state;
const _errs414 = errors;
if(errors === _errs414){
if(data162 && typeof data162 == "object" && !Array.isArray(data162)){
let missing45;
if(((data162.column === undefined) && (missing45 = "column")) || ((data162.value === undefined) && (missing45 = "value"))){
const err437 = {instancePath:instancePath+"/compiled/plan/predicate/state",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/required",keyword:"required",params:{missingProperty: missing45},message:"must have required property '"+missing45+"'"};
if(vErrors === null){
vErrors = [err437];
}
else {
vErrors.push(err437);
}
errors++;
}
else {
const _errs416 = errors;
for(const key45 in data162){
if(!((key45 === "column") || (key45 === "value"))){
const err438 = {instancePath:instancePath+"/compiled/plan/predicate/state",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key45},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err438];
}
else {
vErrors.push(err438);
}
errors++;
break;
}
}
if(_errs416 === errors){
if(data162.column !== undefined){
let data163 = data162.column;
const _errs417 = errors;
if(!(((typeof data163 == "number") && (!(data163 % 1) && !isNaN(data163))) && (isFinite(data163)))){
const err439 = {instancePath:instancePath+"/compiled/plan/predicate/state/column",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/properties/column/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err439];
}
else {
vErrors.push(err439);
}
errors++;
}
if(errors === _errs417){
if((typeof data163 == "number") && (isFinite(data163))){
if(data163 > 255 || isNaN(data163)){
const err440 = {instancePath:instancePath+"/compiled/plan/predicate/state/column",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/properties/column/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err440];
}
else {
vErrors.push(err440);
}
errors++;
}
else {
if(data163 < 0 || isNaN(data163)){
const err441 = {instancePath:instancePath+"/compiled/plan/predicate/state/column",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/properties/column/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err441];
}
else {
vErrors.push(err441);
}
errors++;
}
}
}
}
var valid68 = _errs417 === errors;
}
else {
var valid68 = true;
}
if(valid68){
if(data162.value !== undefined){
let data164 = data162.value;
const _errs419 = errors;
if(typeof data164 !== "string"){
const err442 = {instancePath:instancePath+"/compiled/plan/predicate/state/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/properties/value/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err442];
}
else {
vErrors.push(err442);
}
errors++;
}
if(!(((((data164 === "missing") || (data164 === "null")) || (data164 === "type_error")) || (data164 === "value")) || (data164 === "conflict"))){
const err443 = {instancePath:instancePath+"/compiled/plan/predicate/state/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/properties/value/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[3].properties.compiled.properties.plan.properties.predicate.oneOf[1].properties.state.properties.value.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err443];
}
else {
vErrors.push(err443);
}
errors++;
}
var valid68 = _errs419 === errors;
}
else {
var valid68 = true;
}
}
}
}
}
else {
const err444 = {instancePath:instancePath+"/compiled/plan/predicate/state",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err444];
}
else {
vErrors.push(err444);
}
errors++;
}
}
}
}
}
}
else {
const err445 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err445];
}
else {
vErrors.push(err445);
}
errors++;
}
}
var _valid8 = _errs411 === errors;
if(_valid8 && valid65){
valid65 = false;
passing3 = [passing3, 1];
}
else {
if(_valid8){
valid65 = true;
passing3 = 1;
if(props4 !== true){
props4 = true;
}
}
const _errs421 = errors;
if(errors === _errs421){
if(data160 && typeof data160 == "object" && !Array.isArray(data160)){
let missing46;
if((data160.compare === undefined) && (missing46 = "compare")){
const err446 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/required",keyword:"required",params:{missingProperty: missing46},message:"must have required property '"+missing46+"'"};
if(vErrors === null){
vErrors = [err446];
}
else {
vErrors.push(err446);
}
errors++;
}
else {
const _errs423 = errors;
for(const key46 in data160){
if(!(key46 === "compare")){
const err447 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key46},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err447];
}
else {
vErrors.push(err447);
}
errors++;
break;
}
}
if(_errs423 === errors){
if(data160.compare !== undefined){
let data165 = data160.compare;
const _errs424 = errors;
if(errors === _errs424){
if(data165 && typeof data165 == "object" && !Array.isArray(data165)){
let missing47;
if((((data165.column === undefined) && (missing47 = "column")) || ((data165.op === undefined) && (missing47 = "op"))) || ((data165.value === undefined) && (missing47 = "value"))){
const err448 = {instancePath:instancePath+"/compiled/plan/predicate/compare",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/required",keyword:"required",params:{missingProperty: missing47},message:"must have required property '"+missing47+"'"};
if(vErrors === null){
vErrors = [err448];
}
else {
vErrors.push(err448);
}
errors++;
}
else {
const _errs426 = errors;
for(const key47 in data165){
if(!(((key47 === "column") || (key47 === "op")) || (key47 === "value"))){
const err449 = {instancePath:instancePath+"/compiled/plan/predicate/compare",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key47},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err449];
}
else {
vErrors.push(err449);
}
errors++;
break;
}
}
if(_errs426 === errors){
if(data165.column !== undefined){
let data166 = data165.column;
const _errs427 = errors;
if(!(((typeof data166 == "number") && (!(data166 % 1) && !isNaN(data166))) && (isFinite(data166)))){
const err450 = {instancePath:instancePath+"/compiled/plan/predicate/compare/column",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/column/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err450];
}
else {
vErrors.push(err450);
}
errors++;
}
if(errors === _errs427){
if((typeof data166 == "number") && (isFinite(data166))){
if(data166 > 255 || isNaN(data166)){
const err451 = {instancePath:instancePath+"/compiled/plan/predicate/compare/column",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/column/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err451];
}
else {
vErrors.push(err451);
}
errors++;
}
else {
if(data166 < 0 || isNaN(data166)){
const err452 = {instancePath:instancePath+"/compiled/plan/predicate/compare/column",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/column/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err452];
}
else {
vErrors.push(err452);
}
errors++;
}
}
}
}
var valid70 = _errs427 === errors;
}
else {
var valid70 = true;
}
if(valid70){
if(data165.op !== undefined){
let data167 = data165.op;
const _errs429 = errors;
if(typeof data167 !== "string"){
const err453 = {instancePath:instancePath+"/compiled/plan/predicate/compare/op",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/op/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err453];
}
else {
vErrors.push(err453);
}
errors++;
}
if(!((((((data167 === "eq") || (data167 === "ne")) || (data167 === "lt")) || (data167 === "le")) || (data167 === "gt")) || (data167 === "ge"))){
const err454 = {instancePath:instancePath+"/compiled/plan/predicate/compare/op",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/op/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[3].properties.compiled.properties.plan.properties.predicate.oneOf[2].properties.compare.properties.op.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err454];
}
else {
vErrors.push(err454);
}
errors++;
}
var valid70 = _errs429 === errors;
}
else {
var valid70 = true;
}
if(valid70){
if(data165.value !== undefined){
let data168 = data165.value;
const _errs431 = errors;
const _errs432 = errors;
let valid71 = false;
let passing4 = null;
const _errs433 = errors;
if(errors === _errs433){
if(data168 && typeof data168 == "object" && !Array.isArray(data168)){
let missing48;
if((data168.int64 === undefined) && (missing48 = "int64")){
const err455 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/0/required",keyword:"required",params:{missingProperty: missing48},message:"must have required property '"+missing48+"'"};
if(vErrors === null){
vErrors = [err455];
}
else {
vErrors.push(err455);
}
errors++;
}
else {
const _errs435 = errors;
for(const key48 in data168){
if(!(key48 === "int64")){
const err456 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key48},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err456];
}
else {
vErrors.push(err456);
}
errors++;
break;
}
}
if(_errs435 === errors){
if(data168.int64 !== undefined){
let data169 = data168.int64;
const _errs436 = errors;
if(errors === _errs436){
if(typeof data169 === "string"){
if(func1(data169) > 131072){
const err457 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/int64",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/0/properties/int64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err457];
}
else {
vErrors.push(err457);
}
errors++;
}
}
else {
const err458 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/int64",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/0/properties/int64/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err458];
}
else {
vErrors.push(err458);
}
errors++;
}
}
}
}
}
}
else {
const err459 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err459];
}
else {
vErrors.push(err459);
}
errors++;
}
}
var _valid9 = _errs433 === errors;
if(_valid9){
valid71 = true;
passing4 = 0;
var props5 = true;
}
const _errs438 = errors;
if(errors === _errs438){
if(data168 && typeof data168 == "object" && !Array.isArray(data168)){
let missing49;
if((data168.uint64 === undefined) && (missing49 = "uint64")){
const err460 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/1/required",keyword:"required",params:{missingProperty: missing49},message:"must have required property '"+missing49+"'"};
if(vErrors === null){
vErrors = [err460];
}
else {
vErrors.push(err460);
}
errors++;
}
else {
const _errs440 = errors;
for(const key49 in data168){
if(!(key49 === "uint64")){
const err461 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key49},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err461];
}
else {
vErrors.push(err461);
}
errors++;
break;
}
}
if(_errs440 === errors){
if(data168.uint64 !== undefined){
let data170 = data168.uint64;
const _errs441 = errors;
if(errors === _errs441){
if(typeof data170 === "string"){
if(func1(data170) > 131072){
const err462 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/uint64",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/1/properties/uint64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err462];
}
else {
vErrors.push(err462);
}
errors++;
}
}
else {
const err463 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/uint64",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/1/properties/uint64/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err463];
}
else {
vErrors.push(err463);
}
errors++;
}
}
}
}
}
}
else {
const err464 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err464];
}
else {
vErrors.push(err464);
}
errors++;
}
}
var _valid9 = _errs438 === errors;
if(_valid9 && valid71){
valid71 = false;
passing4 = [passing4, 1];
}
else {
if(_valid9){
valid71 = true;
passing4 = 1;
if(props5 !== true){
props5 = true;
}
}
const _errs443 = errors;
if(errors === _errs443){
if(data168 && typeof data168 == "object" && !Array.isArray(data168)){
let missing50;
if((data168.float_bits === undefined) && (missing50 = "float_bits")){
const err465 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/2/required",keyword:"required",params:{missingProperty: missing50},message:"must have required property '"+missing50+"'"};
if(vErrors === null){
vErrors = [err465];
}
else {
vErrors.push(err465);
}
errors++;
}
else {
const _errs445 = errors;
for(const key50 in data168){
if(!(key50 === "float_bits")){
const err466 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key50},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err466];
}
else {
vErrors.push(err466);
}
errors++;
break;
}
}
if(_errs445 === errors){
if(data168.float_bits !== undefined){
let data171 = data168.float_bits;
const _errs446 = errors;
if(errors === _errs446){
if(typeof data171 === "string"){
if(func1(data171) > 131072){
const err467 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/float_bits",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/2/properties/float_bits/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err467];
}
else {
vErrors.push(err467);
}
errors++;
}
}
else {
const err468 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/float_bits",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/2/properties/float_bits/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
const err469 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err469];
}
else {
vErrors.push(err469);
}
errors++;
}
}
var _valid9 = _errs443 === errors;
if(_valid9 && valid71){
valid71 = false;
passing4 = [passing4, 2];
}
else {
if(_valid9){
valid71 = true;
passing4 = 2;
if(props5 !== true){
props5 = true;
}
}
const _errs448 = errors;
if(errors === _errs448){
if(data168 && typeof data168 == "object" && !Array.isArray(data168)){
let missing51;
if((data168.boolean === undefined) && (missing51 = "boolean")){
const err470 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/3/required",keyword:"required",params:{missingProperty: missing51},message:"must have required property '"+missing51+"'"};
if(vErrors === null){
vErrors = [err470];
}
else {
vErrors.push(err470);
}
errors++;
}
else {
const _errs450 = errors;
for(const key51 in data168){
if(!(key51 === "boolean")){
const err471 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key51},message:"must NOT have additional properties"};
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
if(_errs450 === errors){
if(data168.boolean !== undefined){
if(typeof data168.boolean !== "boolean"){
const err472 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/boolean",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/3/properties/boolean/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err472];
}
else {
vErrors.push(err472);
}
errors++;
}
}
}
}
}
else {
const err473 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err473];
}
else {
vErrors.push(err473);
}
errors++;
}
}
var _valid9 = _errs448 === errors;
if(_valid9 && valid71){
valid71 = false;
passing4 = [passing4, 3];
}
else {
if(_valid9){
valid71 = true;
passing4 = 3;
if(props5 !== true){
props5 = true;
}
}
const _errs453 = errors;
if(errors === _errs453){
if(data168 && typeof data168 == "object" && !Array.isArray(data168)){
let missing52;
if((data168.utf8 === undefined) && (missing52 = "utf8")){
const err474 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/4/required",keyword:"required",params:{missingProperty: missing52},message:"must have required property '"+missing52+"'"};
if(vErrors === null){
vErrors = [err474];
}
else {
vErrors.push(err474);
}
errors++;
}
else {
const _errs455 = errors;
for(const key52 in data168){
if(!(key52 === "utf8")){
const err475 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key52},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err475];
}
else {
vErrors.push(err475);
}
errors++;
break;
}
}
if(_errs455 === errors){
if(data168.utf8 !== undefined){
let data173 = data168.utf8;
const _errs456 = errors;
if(errors === _errs456){
if(typeof data173 === "string"){
if(func1(data173) > 131072){
const err476 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/utf8",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/4/properties/utf8/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err476];
}
else {
vErrors.push(err476);
}
errors++;
}
}
else {
const err477 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/utf8",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/4/properties/utf8/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err477];
}
else {
vErrors.push(err477);
}
errors++;
}
}
}
}
}
}
else {
const err478 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err478];
}
else {
vErrors.push(err478);
}
errors++;
}
}
var _valid9 = _errs453 === errors;
if(_valid9 && valid71){
valid71 = false;
passing4 = [passing4, 4];
}
else {
if(_valid9){
valid71 = true;
passing4 = 4;
if(props5 !== true){
props5 = true;
}
}
const _errs458 = errors;
if(errors === _errs458){
if(data168 && typeof data168 == "object" && !Array.isArray(data168)){
let missing53;
if((data168.binary === undefined) && (missing53 = "binary")){
const err479 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/5/required",keyword:"required",params:{missingProperty: missing53},message:"must have required property '"+missing53+"'"};
if(vErrors === null){
vErrors = [err479];
}
else {
vErrors.push(err479);
}
errors++;
}
else {
const _errs460 = errors;
for(const key53 in data168){
if(!(key53 === "binary")){
const err480 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key53},message:"must NOT have additional properties"};
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
if(_errs460 === errors){
if(data168.binary !== undefined){
let data174 = data168.binary;
const _errs461 = errors;
if(errors === _errs461){
if(typeof data174 === "string"){
if(func1(data174) > 131072){
const err481 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/binary",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/5/properties/binary/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err482 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/binary",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/5/properties/binary/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
const err483 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err483];
}
else {
vErrors.push(err483);
}
errors++;
}
}
var _valid9 = _errs458 === errors;
if(_valid9 && valid71){
valid71 = false;
passing4 = [passing4, 5];
}
else {
if(_valid9){
valid71 = true;
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
if(!valid71){
const err484 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf",keyword:"oneOf",params:{passingSchemas: passing4},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err484];
}
else {
vErrors.push(err484);
}
errors++;
}
else {
errors = _errs432;
if(vErrors !== null){
if(_errs432){
vErrors.length = _errs432;
}
else {
vErrors = null;
}
}
}
var valid70 = _errs431 === errors;
}
else {
var valid70 = true;
}
}
}
}
}
}
else {
const err485 = {instancePath:instancePath+"/compiled/plan/predicate/compare",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err485];
}
else {
vErrors.push(err485);
}
errors++;
}
}
}
}
}
}
else {
const err486 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err486];
}
else {
vErrors.push(err486);
}
errors++;
}
}
var _valid8 = _errs421 === errors;
if(_valid8 && valid65){
valid65 = false;
passing3 = [passing3, 2];
}
else {
if(_valid8){
valid65 = true;
passing3 = 2;
if(props4 !== true){
props4 = true;
}
}
}
}
if(!valid65){
const err487 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf",keyword:"oneOf",params:{passingSchemas: passing3},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err487];
}
else {
vErrors.push(err487);
}
errors++;
}
else {
errors = _errs405;
if(vErrors !== null){
if(_errs405){
vErrors.length = _errs405;
}
else {
vErrors = null;
}
}
}
var valid62 = _errs404 === errors;
}
else {
var valid62 = true;
}
}
}
}
}
}
}
}
else {
const err488 = {instancePath:instancePath+"/compiled/plan",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err488];
}
else {
vErrors.push(err488);
}
errors++;
}
}
var valid43 = _errs387 === errors;
}
else {
var valid43 = true;
}
if(valid43){
if(data114.limits !== undefined){
let data175 = data114.limits;
const _errs463 = errors;
if(errors === _errs463){
if(data175 && typeof data175 == "object" && !Array.isArray(data175)){
let missing54;
if((((data175.pages === undefined) && (missing54 = "pages")) || ((data175.segments === undefined) && (missing54 = "segments"))) || ((data175.result_bytes === undefined) && (missing54 = "result_bytes"))){
const err489 = {instancePath:instancePath+"/compiled/limits",schemaPath:"#/oneOf/3/properties/compiled/properties/limits/required",keyword:"required",params:{missingProperty: missing54},message:"must have required property '"+missing54+"'"};
if(vErrors === null){
vErrors = [err489];
}
else {
vErrors.push(err489);
}
errors++;
}
else {
const _errs465 = errors;
for(const key54 in data175){
if(!(((key54 === "pages") || (key54 === "segments")) || (key54 === "result_bytes"))){
const err490 = {instancePath:instancePath+"/compiled/limits",schemaPath:"#/oneOf/3/properties/compiled/properties/limits/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key54},message:"must NOT have additional properties"};
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
if(_errs465 === errors){
if(data175.pages !== undefined){
let data176 = data175.pages;
const _errs466 = errors;
if(errors === _errs466){
if(typeof data176 === "string"){
if(func1(data176) > 131072){
const err491 = {instancePath:instancePath+"/compiled/limits/pages",schemaPath:"#/oneOf/3/properties/compiled/properties/limits/properties/pages/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err492 = {instancePath:instancePath+"/compiled/limits/pages",schemaPath:"#/oneOf/3/properties/compiled/properties/limits/properties/pages/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err492];
}
else {
vErrors.push(err492);
}
errors++;
}
}
var valid78 = _errs466 === errors;
}
else {
var valid78 = true;
}
if(valid78){
if(data175.segments !== undefined){
let data177 = data175.segments;
const _errs468 = errors;
if(errors === _errs468){
if(typeof data177 === "string"){
if(func1(data177) > 131072){
const err493 = {instancePath:instancePath+"/compiled/limits/segments",schemaPath:"#/oneOf/3/properties/compiled/properties/limits/properties/segments/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err493];
}
else {
vErrors.push(err493);
}
errors++;
}
}
else {
const err494 = {instancePath:instancePath+"/compiled/limits/segments",schemaPath:"#/oneOf/3/properties/compiled/properties/limits/properties/segments/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err494];
}
else {
vErrors.push(err494);
}
errors++;
}
}
var valid78 = _errs468 === errors;
}
else {
var valid78 = true;
}
if(valid78){
if(data175.result_bytes !== undefined){
let data178 = data175.result_bytes;
const _errs470 = errors;
if(errors === _errs470){
if(typeof data178 === "string"){
if(func1(data178) > 131072){
const err495 = {instancePath:instancePath+"/compiled/limits/result_bytes",schemaPath:"#/oneOf/3/properties/compiled/properties/limits/properties/result_bytes/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err495];
}
else {
vErrors.push(err495);
}
errors++;
}
}
else {
const err496 = {instancePath:instancePath+"/compiled/limits/result_bytes",schemaPath:"#/oneOf/3/properties/compiled/properties/limits/properties/result_bytes/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err496];
}
else {
vErrors.push(err496);
}
errors++;
}
}
var valid78 = _errs470 === errors;
}
else {
var valid78 = true;
}
}
}
}
}
}
else {
const err497 = {instancePath:instancePath+"/compiled/limits",schemaPath:"#/oneOf/3/properties/compiled/properties/limits/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err497];
}
else {
vErrors.push(err497);
}
errors++;
}
}
var valid43 = _errs463 === errors;
}
else {
var valid43 = true;
}
if(valid43){
if(data114.contract !== undefined){
let data179 = data114.contract;
const _errs472 = errors;
if(errors === _errs472){
if(Array.isArray(data179)){
if(data179.length > 32){
const err498 = {instancePath:instancePath+"/compiled/contract",schemaPath:"#/oneOf/3/properties/compiled/properties/contract/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err498];
}
else {
vErrors.push(err498);
}
errors++;
}
else {
if(data179.length < 32){
const err499 = {instancePath:instancePath+"/compiled/contract",schemaPath:"#/oneOf/3/properties/compiled/properties/contract/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err499];
}
else {
vErrors.push(err499);
}
errors++;
}
else {
var valid79 = true;
const len14 = data179.length;
for(let i14=0; i14<len14; i14++){
let data180 = data179[i14];
const _errs474 = errors;
if(!(((typeof data180 == "number") && (!(data180 % 1) && !isNaN(data180))) && (isFinite(data180)))){
const err500 = {instancePath:instancePath+"/compiled/contract/" + i14,schemaPath:"#/oneOf/3/properties/compiled/properties/contract/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err500];
}
else {
vErrors.push(err500);
}
errors++;
}
if(errors === _errs474){
if((typeof data180 == "number") && (isFinite(data180))){
if(data180 > 255 || isNaN(data180)){
const err501 = {instancePath:instancePath+"/compiled/contract/" + i14,schemaPath:"#/oneOf/3/properties/compiled/properties/contract/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err501];
}
else {
vErrors.push(err501);
}
errors++;
}
else {
if(data180 < 0 || isNaN(data180)){
const err502 = {instancePath:instancePath+"/compiled/contract/" + i14,schemaPath:"#/oneOf/3/properties/compiled/properties/contract/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err502];
}
else {
vErrors.push(err502);
}
errors++;
}
}
}
}
var valid79 = _errs474 === errors;
if(!valid79){
break;
}
}
}
}
}
else {
const err503 = {instancePath:instancePath+"/compiled/contract",schemaPath:"#/oneOf/3/properties/compiled/properties/contract/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err503];
}
else {
vErrors.push(err503);
}
errors++;
}
}
var valid43 = _errs472 === errors;
}
else {
var valid43 = true;
}
if(valid43){
if(data114.schema !== undefined){
let data181 = data114.schema;
const _errs476 = errors;
if(errors === _errs476){
if(Array.isArray(data181)){
if(data181.length > 32){
const err504 = {instancePath:instancePath+"/compiled/schema",schemaPath:"#/oneOf/3/properties/compiled/properties/schema/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err504];
}
else {
vErrors.push(err504);
}
errors++;
}
else {
if(data181.length < 32){
const err505 = {instancePath:instancePath+"/compiled/schema",schemaPath:"#/oneOf/3/properties/compiled/properties/schema/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err505];
}
else {
vErrors.push(err505);
}
errors++;
}
else {
var valid80 = true;
const len15 = data181.length;
for(let i15=0; i15<len15; i15++){
let data182 = data181[i15];
const _errs478 = errors;
if(!(((typeof data182 == "number") && (!(data182 % 1) && !isNaN(data182))) && (isFinite(data182)))){
const err506 = {instancePath:instancePath+"/compiled/schema/" + i15,schemaPath:"#/oneOf/3/properties/compiled/properties/schema/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err506];
}
else {
vErrors.push(err506);
}
errors++;
}
if(errors === _errs478){
if((typeof data182 == "number") && (isFinite(data182))){
if(data182 > 255 || isNaN(data182)){
const err507 = {instancePath:instancePath+"/compiled/schema/" + i15,schemaPath:"#/oneOf/3/properties/compiled/properties/schema/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err507];
}
else {
vErrors.push(err507);
}
errors++;
}
else {
if(data182 < 0 || isNaN(data182)){
const err508 = {instancePath:instancePath+"/compiled/schema/" + i15,schemaPath:"#/oneOf/3/properties/compiled/properties/schema/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err508];
}
else {
vErrors.push(err508);
}
errors++;
}
}
}
}
var valid80 = _errs478 === errors;
if(!valid80){
break;
}
}
}
}
}
else {
const err509 = {instancePath:instancePath+"/compiled/schema",schemaPath:"#/oneOf/3/properties/compiled/properties/schema/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err509];
}
else {
vErrors.push(err509);
}
errors++;
}
}
var valid43 = _errs476 === errors;
}
else {
var valid43 = true;
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
const err510 = {instancePath:instancePath+"/compiled",schemaPath:"#/oneOf/3/properties/compiled/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err510];
}
else {
vErrors.push(err510);
}
errors++;
}
}
}
}
}
}
else {
const err511 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err511];
}
else {
vErrors.push(err511);
}
errors++;
}
}
var _valid0 = _errs281 === errors;
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
const _errs480 = errors;
if(errors === _errs480){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing55;
if((data.inspection === undefined) && (missing55 = "inspection")){
const err512 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing55},message:"must have required property '"+missing55+"'"};
if(vErrors === null){
vErrors = [err512];
}
else {
vErrors.push(err512);
}
errors++;
}
else {
const _errs482 = errors;
for(const key55 in data){
if(!(key55 === "inspection")){
const err513 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key55},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err513];
}
else {
vErrors.push(err513);
}
errors++;
break;
}
}
if(_errs482 === errors){
if(data.inspection !== undefined){
let data183 = data.inspection;
const _errs483 = errors;
if(errors === _errs483){
if(data183 && typeof data183 == "object" && !Array.isArray(data183)){
let missing56;
if(((((((((((data183.version === undefined) && (missing56 = "version")) || ((data183.scope === undefined) && (missing56 = "scope"))) || ((data183.name === undefined) && (missing56 = "name"))) || ((data183.resource === undefined) && (missing56 = "resource"))) || ((data183.source_kind === undefined) && (missing56 = "source_kind"))) || ((data183.contract === undefined) && (missing56 = "contract"))) || ((data183.schema === undefined) && (missing56 = "schema"))) || ((data183.resource_revision === undefined) && (missing56 = "resource_revision"))) || ((data183.policy_revision === undefined) && (missing56 = "policy_revision"))) || ((data183.details === undefined) && (missing56 = "details"))){
const err514 = {instancePath:instancePath+"/inspection",schemaPath:"#/oneOf/4/properties/inspection/required",keyword:"required",params:{missingProperty: missing56},message:"must have required property '"+missing56+"'"};
if(vErrors === null){
vErrors = [err514];
}
else {
vErrors.push(err514);
}
errors++;
}
else {
const _errs485 = errors;
for(const key56 in data183){
if(!(func19.call(schema33.oneOf[4].properties.inspection.properties, key56))){
const err515 = {instancePath:instancePath+"/inspection",schemaPath:"#/oneOf/4/properties/inspection/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key56},message:"must NOT have additional properties"};
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
if(_errs485 === errors){
if(data183.version !== undefined){
let data184 = data183.version;
const _errs486 = errors;
if(!(((typeof data184 == "number") && (!(data184 % 1) && !isNaN(data184))) && (isFinite(data184)))){
const err516 = {instancePath:instancePath+"/inspection/version",schemaPath:"#/oneOf/4/properties/inspection/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err516];
}
else {
vErrors.push(err516);
}
errors++;
}
if(errors === _errs486){
if((typeof data184 == "number") && (isFinite(data184))){
if(data184 > 255 || isNaN(data184)){
const err517 = {instancePath:instancePath+"/inspection/version",schemaPath:"#/oneOf/4/properties/inspection/properties/version/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err517];
}
else {
vErrors.push(err517);
}
errors++;
}
else {
if(data184 < 0 || isNaN(data184)){
const err518 = {instancePath:instancePath+"/inspection/version",schemaPath:"#/oneOf/4/properties/inspection/properties/version/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err518];
}
else {
vErrors.push(err518);
}
errors++;
}
}
}
}
var valid82 = _errs486 === errors;
}
else {
var valid82 = true;
}
if(valid82){
if(data183.scope !== undefined){
let data185 = data183.scope;
const _errs488 = errors;
if(typeof data185 !== "string"){
const err519 = {instancePath:instancePath+"/inspection/scope",schemaPath:"#/oneOf/4/properties/inspection/properties/scope/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err519];
}
else {
vErrors.push(err519);
}
errors++;
}
if(!(data185 === "configured_source")){
const err520 = {instancePath:instancePath+"/inspection/scope",schemaPath:"#/oneOf/4/properties/inspection/properties/scope/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.inspection.properties.scope.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err520];
}
else {
vErrors.push(err520);
}
errors++;
}
var valid82 = _errs488 === errors;
}
else {
var valid82 = true;
}
if(valid82){
if(data183.name !== undefined){
let data186 = data183.name;
const _errs490 = errors;
if(errors === _errs490){
if(typeof data186 === "string"){
if(func1(data186) > 131072){
const err521 = {instancePath:instancePath+"/inspection/name",schemaPath:"#/oneOf/4/properties/inspection/properties/name/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err521];
}
else {
vErrors.push(err521);
}
errors++;
}
}
else {
const err522 = {instancePath:instancePath+"/inspection/name",schemaPath:"#/oneOf/4/properties/inspection/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err522];
}
else {
vErrors.push(err522);
}
errors++;
}
}
var valid82 = _errs490 === errors;
}
else {
var valid82 = true;
}
if(valid82){
if(data183.resource !== undefined){
let data187 = data183.resource;
const _errs492 = errors;
if(!(((typeof data187 == "number") && (!(data187 % 1) && !isNaN(data187))) && (isFinite(data187)))){
const err523 = {instancePath:instancePath+"/inspection/resource",schemaPath:"#/oneOf/4/properties/inspection/properties/resource/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err523];
}
else {
vErrors.push(err523);
}
errors++;
}
if(errors === _errs492){
if((typeof data187 == "number") && (isFinite(data187))){
if(data187 > 9007199254740991 || isNaN(data187)){
const err524 = {instancePath:instancePath+"/inspection/resource",schemaPath:"#/oneOf/4/properties/inspection/properties/resource/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err524];
}
else {
vErrors.push(err524);
}
errors++;
}
else {
if(data187 < 0 || isNaN(data187)){
const err525 = {instancePath:instancePath+"/inspection/resource",schemaPath:"#/oneOf/4/properties/inspection/properties/resource/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err525];
}
else {
vErrors.push(err525);
}
errors++;
}
}
}
}
var valid82 = _errs492 === errors;
}
else {
var valid82 = true;
}
if(valid82){
if(data183.source_kind !== undefined){
let data188 = data183.source_kind;
const _errs494 = errors;
if(typeof data188 !== "string"){
const err526 = {instancePath:instancePath+"/inspection/source_kind",schemaPath:"#/oneOf/4/properties/inspection/properties/source_kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err526];
}
else {
vErrors.push(err526);
}
errors++;
}
if(!(((data188 === "kv") || (data188 === "table")) || (data188 === "document"))){
const err527 = {instancePath:instancePath+"/inspection/source_kind",schemaPath:"#/oneOf/4/properties/inspection/properties/source_kind/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.inspection.properties.source_kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err527];
}
else {
vErrors.push(err527);
}
errors++;
}
var valid82 = _errs494 === errors;
}
else {
var valid82 = true;
}
if(valid82){
if(data183.contract !== undefined){
let data189 = data183.contract;
const _errs496 = errors;
if(errors === _errs496){
if(Array.isArray(data189)){
if(data189.length > 32){
const err528 = {instancePath:instancePath+"/inspection/contract",schemaPath:"#/oneOf/4/properties/inspection/properties/contract/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err528];
}
else {
vErrors.push(err528);
}
errors++;
}
else {
if(data189.length < 32){
const err529 = {instancePath:instancePath+"/inspection/contract",schemaPath:"#/oneOf/4/properties/inspection/properties/contract/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err529];
}
else {
vErrors.push(err529);
}
errors++;
}
else {
var valid83 = true;
const len16 = data189.length;
for(let i16=0; i16<len16; i16++){
let data190 = data189[i16];
const _errs498 = errors;
if(!(((typeof data190 == "number") && (!(data190 % 1) && !isNaN(data190))) && (isFinite(data190)))){
const err530 = {instancePath:instancePath+"/inspection/contract/" + i16,schemaPath:"#/oneOf/4/properties/inspection/properties/contract/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err530];
}
else {
vErrors.push(err530);
}
errors++;
}
if(errors === _errs498){
if((typeof data190 == "number") && (isFinite(data190))){
if(data190 > 255 || isNaN(data190)){
const err531 = {instancePath:instancePath+"/inspection/contract/" + i16,schemaPath:"#/oneOf/4/properties/inspection/properties/contract/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err531];
}
else {
vErrors.push(err531);
}
errors++;
}
else {
if(data190 < 0 || isNaN(data190)){
const err532 = {instancePath:instancePath+"/inspection/contract/" + i16,schemaPath:"#/oneOf/4/properties/inspection/properties/contract/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err532];
}
else {
vErrors.push(err532);
}
errors++;
}
}
}
}
var valid83 = _errs498 === errors;
if(!valid83){
break;
}
}
}
}
}
else {
const err533 = {instancePath:instancePath+"/inspection/contract",schemaPath:"#/oneOf/4/properties/inspection/properties/contract/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err533];
}
else {
vErrors.push(err533);
}
errors++;
}
}
var valid82 = _errs496 === errors;
}
else {
var valid82 = true;
}
if(valid82){
if(data183.schema !== undefined){
let data191 = data183.schema;
const _errs500 = errors;
if(errors === _errs500){
if(Array.isArray(data191)){
if(data191.length > 32){
const err534 = {instancePath:instancePath+"/inspection/schema",schemaPath:"#/oneOf/4/properties/inspection/properties/schema/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err534];
}
else {
vErrors.push(err534);
}
errors++;
}
else {
if(data191.length < 32){
const err535 = {instancePath:instancePath+"/inspection/schema",schemaPath:"#/oneOf/4/properties/inspection/properties/schema/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err535];
}
else {
vErrors.push(err535);
}
errors++;
}
else {
var valid84 = true;
const len17 = data191.length;
for(let i17=0; i17<len17; i17++){
let data192 = data191[i17];
const _errs502 = errors;
if(!(((typeof data192 == "number") && (!(data192 % 1) && !isNaN(data192))) && (isFinite(data192)))){
const err536 = {instancePath:instancePath+"/inspection/schema/" + i17,schemaPath:"#/oneOf/4/properties/inspection/properties/schema/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err536];
}
else {
vErrors.push(err536);
}
errors++;
}
if(errors === _errs502){
if((typeof data192 == "number") && (isFinite(data192))){
if(data192 > 255 || isNaN(data192)){
const err537 = {instancePath:instancePath+"/inspection/schema/" + i17,schemaPath:"#/oneOf/4/properties/inspection/properties/schema/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err537];
}
else {
vErrors.push(err537);
}
errors++;
}
else {
if(data192 < 0 || isNaN(data192)){
const err538 = {instancePath:instancePath+"/inspection/schema/" + i17,schemaPath:"#/oneOf/4/properties/inspection/properties/schema/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid84 = _errs502 === errors;
if(!valid84){
break;
}
}
}
}
}
else {
const err539 = {instancePath:instancePath+"/inspection/schema",schemaPath:"#/oneOf/4/properties/inspection/properties/schema/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err539];
}
else {
vErrors.push(err539);
}
errors++;
}
}
var valid82 = _errs500 === errors;
}
else {
var valid82 = true;
}
if(valid82){
if(data183.resource_revision !== undefined){
let data193 = data183.resource_revision;
const _errs504 = errors;
if(!(((typeof data193 == "number") && (!(data193 % 1) && !isNaN(data193))) && (isFinite(data193)))){
const err540 = {instancePath:instancePath+"/inspection/resource_revision",schemaPath:"#/oneOf/4/properties/inspection/properties/resource_revision/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err540];
}
else {
vErrors.push(err540);
}
errors++;
}
if(errors === _errs504){
if((typeof data193 == "number") && (isFinite(data193))){
if(data193 > 9007199254740991 || isNaN(data193)){
const err541 = {instancePath:instancePath+"/inspection/resource_revision",schemaPath:"#/oneOf/4/properties/inspection/properties/resource_revision/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err541];
}
else {
vErrors.push(err541);
}
errors++;
}
else {
if(data193 < 0 || isNaN(data193)){
const err542 = {instancePath:instancePath+"/inspection/resource_revision",schemaPath:"#/oneOf/4/properties/inspection/properties/resource_revision/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err542];
}
else {
vErrors.push(err542);
}
errors++;
}
}
}
}
var valid82 = _errs504 === errors;
}
else {
var valid82 = true;
}
if(valid82){
if(data183.policy_revision !== undefined){
let data194 = data183.policy_revision;
const _errs506 = errors;
if(errors === _errs506){
if(typeof data194 === "string"){
if(func1(data194) > 131072){
const err543 = {instancePath:instancePath+"/inspection/policy_revision",schemaPath:"#/oneOf/4/properties/inspection/properties/policy_revision/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err544 = {instancePath:instancePath+"/inspection/policy_revision",schemaPath:"#/oneOf/4/properties/inspection/properties/policy_revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err544];
}
else {
vErrors.push(err544);
}
errors++;
}
}
var valid82 = _errs506 === errors;
}
else {
var valid82 = true;
}
if(valid82){
if(data183.details !== undefined){
let data195 = data183.details;
const _errs508 = errors;
const _errs509 = errors;
let valid85 = false;
let passing5 = null;
const _errs510 = errors;
if(errors === _errs510){
if(data195 && typeof data195 == "object" && !Array.isArray(data195)){
let missing57;
if((data195.description === undefined) && (missing57 = "description")){
const err545 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/0/required",keyword:"required",params:{missingProperty: missing57},message:"must have required property '"+missing57+"'"};
if(vErrors === null){
vErrors = [err545];
}
else {
vErrors.push(err545);
}
errors++;
}
else {
const _errs512 = errors;
for(const key57 in data195){
if(!(key57 === "description")){
const err546 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key57},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err546];
}
else {
vErrors.push(err546);
}
errors++;
break;
}
}
if(_errs512 === errors){
if(data195.description !== undefined){
let data196 = data195.description;
const _errs513 = errors;
if(errors === _errs513){
if(data196 && typeof data196 == "object" && !Array.isArray(data196)){
let missing58;
if((data196.columns === undefined) && (missing58 = "columns")){
const err547 = {instancePath:instancePath+"/inspection/details/description",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/0/properties/description/required",keyword:"required",params:{missingProperty: missing58},message:"must have required property '"+missing58+"'"};
if(vErrors === null){
vErrors = [err547];
}
else {
vErrors.push(err547);
}
errors++;
}
else {
const _errs515 = errors;
for(const key58 in data196){
if(!(key58 === "columns")){
const err548 = {instancePath:instancePath+"/inspection/details/description",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/0/properties/description/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key58},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err548];
}
else {
vErrors.push(err548);
}
errors++;
break;
}
}
if(_errs515 === errors){
if(data196.columns !== undefined){
let data197 = data196.columns;
const _errs516 = errors;
if(errors === _errs516){
if(Array.isArray(data197)){
if(data197.length > 8){
const err549 = {instancePath:instancePath+"/inspection/details/description/columns",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/0/properties/description/properties/columns/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err549];
}
else {
vErrors.push(err549);
}
errors++;
}
else {
var valid88 = true;
const len18 = data197.length;
for(let i18=0; i18<len18; i18++){
let data198 = data197[i18];
const _errs518 = errors;
if(errors === _errs518){
if(data198 && typeof data198 == "object" && !Array.isArray(data198)){
let missing59;
if(((data198.name === undefined) && (missing59 = "name")) || ((data198.type === undefined) && (missing59 = "type"))){
const err550 = {instancePath:instancePath+"/inspection/details/description/columns/" + i18,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/0/properties/description/properties/columns/items/required",keyword:"required",params:{missingProperty: missing59},message:"must have required property '"+missing59+"'"};
if(vErrors === null){
vErrors = [err550];
}
else {
vErrors.push(err550);
}
errors++;
}
else {
const _errs520 = errors;
for(const key59 in data198){
if(!((key59 === "name") || (key59 === "type"))){
const err551 = {instancePath:instancePath+"/inspection/details/description/columns/" + i18,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/0/properties/description/properties/columns/items/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key59},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err551];
}
else {
vErrors.push(err551);
}
errors++;
break;
}
}
if(_errs520 === errors){
if(data198.name !== undefined){
let data199 = data198.name;
const _errs521 = errors;
if(errors === _errs521){
if(typeof data199 === "string"){
if(func1(data199) > 131072){
const err552 = {instancePath:instancePath+"/inspection/details/description/columns/" + i18+"/name",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/0/properties/description/properties/columns/items/properties/name/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err552];
}
else {
vErrors.push(err552);
}
errors++;
}
}
else {
const err553 = {instancePath:instancePath+"/inspection/details/description/columns/" + i18+"/name",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/0/properties/description/properties/columns/items/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err553];
}
else {
vErrors.push(err553);
}
errors++;
}
}
var valid89 = _errs521 === errors;
}
else {
var valid89 = true;
}
if(valid89){
if(data198.type !== undefined){
let data200 = data198.type;
const _errs523 = errors;
if(typeof data200 !== "string"){
const err554 = {instancePath:instancePath+"/inspection/details/description/columns/" + i18+"/type",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/0/properties/description/properties/columns/items/properties/type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err554];
}
else {
vErrors.push(err554);
}
errors++;
}
if(!((((((data200 === "int64") || (data200 === "uint64")) || (data200 === "float64")) || (data200 === "boolean")) || (data200 === "utf8")) || (data200 === "binary"))){
const err555 = {instancePath:instancePath+"/inspection/details/description/columns/" + i18+"/type",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/0/properties/description/properties/columns/items/properties/type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.inspection.properties.details.oneOf[0].properties.description.properties.columns.items.properties.type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err555];
}
else {
vErrors.push(err555);
}
errors++;
}
var valid89 = _errs523 === errors;
}
else {
var valid89 = true;
}
}
}
}
}
else {
const err556 = {instancePath:instancePath+"/inspection/details/description/columns/" + i18,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/0/properties/description/properties/columns/items/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err556];
}
else {
vErrors.push(err556);
}
errors++;
}
}
var valid88 = _errs518 === errors;
if(!valid88){
break;
}
}
}
}
else {
const err557 = {instancePath:instancePath+"/inspection/details/description/columns",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/0/properties/description/properties/columns/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err557];
}
else {
vErrors.push(err557);
}
errors++;
}
}
}
}
}
}
else {
const err558 = {instancePath:instancePath+"/inspection/details/description",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/0/properties/description/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
else {
const err559 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err559];
}
else {
vErrors.push(err559);
}
errors++;
}
}
var _valid10 = _errs510 === errors;
if(_valid10){
valid85 = true;
passing5 = 0;
var props6 = true;
}
const _errs525 = errors;
if(errors === _errs525){
if(data195 && typeof data195 == "object" && !Array.isArray(data195)){
let missing60;
if((data195.tables === undefined) && (missing60 = "tables")){
const err560 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/1/required",keyword:"required",params:{missingProperty: missing60},message:"must have required property '"+missing60+"'"};
if(vErrors === null){
vErrors = [err560];
}
else {
vErrors.push(err560);
}
errors++;
}
else {
const _errs527 = errors;
for(const key60 in data195){
if(!(key60 === "tables")){
const err561 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key60},message:"must NOT have additional properties"};
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
if(_errs527 === errors){
if(data195.tables !== undefined){
let data201 = data195.tables;
const _errs528 = errors;
if(errors === _errs528){
if(Array.isArray(data201)){
if(data201.length > 8){
const err562 = {instancePath:instancePath+"/inspection/details/tables",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/1/properties/tables/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err562];
}
else {
vErrors.push(err562);
}
errors++;
}
else {
var valid91 = true;
const len19 = data201.length;
for(let i19=0; i19<len19; i19++){
let data202 = data201[i19];
const _errs530 = errors;
if(errors === _errs530){
if(typeof data202 === "string"){
if(func1(data202) > 131072){
const err563 = {instancePath:instancePath+"/inspection/details/tables/" + i19,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/1/properties/tables/items/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err563];
}
else {
vErrors.push(err563);
}
errors++;
}
}
else {
const err564 = {instancePath:instancePath+"/inspection/details/tables/" + i19,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/1/properties/tables/items/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err564];
}
else {
vErrors.push(err564);
}
errors++;
}
}
var valid91 = _errs530 === errors;
if(!valid91){
break;
}
}
}
}
else {
const err565 = {instancePath:instancePath+"/inspection/details/tables",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/1/properties/tables/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err565];
}
else {
vErrors.push(err565);
}
errors++;
}
}
}
}
}
}
else {
const err566 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err566];
}
else {
vErrors.push(err566);
}
errors++;
}
}
var _valid10 = _errs525 === errors;
if(_valid10 && valid85){
valid85 = false;
passing5 = [passing5, 1];
}
else {
if(_valid10){
valid85 = true;
passing5 = 1;
if(props6 !== true){
props6 = true;
}
}
const _errs532 = errors;
if(errors === _errs532){
if(data195 && typeof data195 == "object" && !Array.isArray(data195)){
let missing61;
if((data195.explanation === undefined) && (missing61 = "explanation")){
const err567 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/required",keyword:"required",params:{missingProperty: missing61},message:"must have required property '"+missing61+"'"};
if(vErrors === null){
vErrors = [err567];
}
else {
vErrors.push(err567);
}
errors++;
}
else {
const _errs534 = errors;
for(const key61 in data195){
if(!(key61 === "explanation")){
const err568 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key61},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err568];
}
else {
vErrors.push(err568);
}
errors++;
break;
}
}
if(_errs534 === errors){
if(data195.explanation !== undefined){
let data203 = data195.explanation;
const _errs535 = errors;
if(errors === _errs535){
if(data203 && typeof data203 == "object" && !Array.isArray(data203)){
let missing62;
if((((((((data203.operators === undefined) && (missing62 = "operators")) || ((data203.predicate === undefined) && (missing62 = "predicate"))) || ((data203.projection === undefined) && (missing62 = "projection"))) || ((data203.limit === undefined) && (missing62 = "limit"))) || ((data203.aggregate === undefined) && (missing62 = "aggregate"))) || ((data203.columns === undefined) && (missing62 = "columns"))) || ((data203.budgets === undefined) && (missing62 = "budgets"))){
const err569 = {instancePath:instancePath+"/inspection/details/explanation",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/required",keyword:"required",params:{missingProperty: missing62},message:"must have required property '"+missing62+"'"};
if(vErrors === null){
vErrors = [err569];
}
else {
vErrors.push(err569);
}
errors++;
}
else {
const _errs537 = errors;
for(const key62 in data203){
if(!(((((((key62 === "operators") || (key62 === "predicate")) || (key62 === "projection")) || (key62 === "limit")) || (key62 === "aggregate")) || (key62 === "columns")) || (key62 === "budgets"))){
const err570 = {instancePath:instancePath+"/inspection/details/explanation",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key62},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err570];
}
else {
vErrors.push(err570);
}
errors++;
break;
}
}
if(_errs537 === errors){
if(data203.operators !== undefined){
let data204 = data203.operators;
const _errs538 = errors;
if(errors === _errs538){
if(Array.isArray(data204)){
if(data204.length > 8){
const err571 = {instancePath:instancePath+"/inspection/details/explanation/operators",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/operators/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err571];
}
else {
vErrors.push(err571);
}
errors++;
}
else {
var valid94 = true;
const len20 = data204.length;
for(let i20=0; i20<len20; i20++){
let data205 = data204[i20];
const _errs540 = errors;
if(typeof data205 !== "string"){
const err572 = {instancePath:instancePath+"/inspection/details/explanation/operators/" + i20,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/operators/items/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err572];
}
else {
vErrors.push(err572);
}
errors++;
}
if(!((((((data205 === "scan") || (data205 === "filter")) || (data205 === "limit")) || (data205 === "project")) || (data205 === "count")) || (data205 === "sum"))){
const err573 = {instancePath:instancePath+"/inspection/details/explanation/operators/" + i20,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/operators/items/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.inspection.properties.details.oneOf[2].properties.explanation.properties.operators.items.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err573];
}
else {
vErrors.push(err573);
}
errors++;
}
var valid94 = _errs540 === errors;
if(!valid94){
break;
}
}
}
}
else {
const err574 = {instancePath:instancePath+"/inspection/details/explanation/operators",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/operators/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err574];
}
else {
vErrors.push(err574);
}
errors++;
}
}
var valid93 = _errs538 === errors;
}
else {
var valid93 = true;
}
if(valid93){
if(data203.predicate !== undefined){
let data206 = data203.predicate;
const _errs542 = errors;
const _errs543 = errors;
let valid95 = false;
let passing6 = null;
const _errs544 = errors;
if(errors === _errs544){
if(data206 && typeof data206 == "object" && !Array.isArray(data206)){
let missing63;
if((data206.all === undefined) && (missing63 = "all")){
const err575 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/0/required",keyword:"required",params:{missingProperty: missing63},message:"must have required property '"+missing63+"'"};
if(vErrors === null){
vErrors = [err575];
}
else {
vErrors.push(err575);
}
errors++;
}
else {
const _errs546 = errors;
for(const key63 in data206){
if(!(key63 === "all")){
const err576 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key63},message:"must NOT have additional properties"};
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
if(_errs546 === errors){
if(data206.all !== undefined){
let data207 = data206.all;
const _errs547 = errors;
if(errors === _errs547){
if(data207 && typeof data207 == "object" && !Array.isArray(data207)){
if(Object.keys(data207).length > 0){
const err577 = {instancePath:instancePath+"/inspection/details/explanation/predicate/all",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/0/properties/all/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
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
const err578 = {instancePath:instancePath+"/inspection/details/explanation/predicate/all",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/0/properties/all/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err579 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err579];
}
else {
vErrors.push(err579);
}
errors++;
}
}
var _valid11 = _errs544 === errors;
if(_valid11){
valid95 = true;
passing6 = 0;
var props7 = true;
}
const _errs549 = errors;
if(errors === _errs549){
if(data206 && typeof data206 == "object" && !Array.isArray(data206)){
let missing64;
if((data206.state === undefined) && (missing64 = "state")){
const err580 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/1/required",keyword:"required",params:{missingProperty: missing64},message:"must have required property '"+missing64+"'"};
if(vErrors === null){
vErrors = [err580];
}
else {
vErrors.push(err580);
}
errors++;
}
else {
const _errs551 = errors;
for(const key64 in data206){
if(!(key64 === "state")){
const err581 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key64},message:"must NOT have additional properties"};
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
if(_errs551 === errors){
if(data206.state !== undefined){
let data208 = data206.state;
const _errs552 = errors;
if(errors === _errs552){
if(data208 && typeof data208 == "object" && !Array.isArray(data208)){
let missing65;
if(((data208.column === undefined) && (missing65 = "column")) || ((data208.value === undefined) && (missing65 = "value"))){
const err582 = {instancePath:instancePath+"/inspection/details/explanation/predicate/state",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/1/properties/state/required",keyword:"required",params:{missingProperty: missing65},message:"must have required property '"+missing65+"'"};
if(vErrors === null){
vErrors = [err582];
}
else {
vErrors.push(err582);
}
errors++;
}
else {
const _errs554 = errors;
for(const key65 in data208){
if(!((key65 === "column") || (key65 === "value"))){
const err583 = {instancePath:instancePath+"/inspection/details/explanation/predicate/state",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/1/properties/state/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key65},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err583];
}
else {
vErrors.push(err583);
}
errors++;
break;
}
}
if(_errs554 === errors){
if(data208.column !== undefined){
let data209 = data208.column;
const _errs555 = errors;
if(errors === _errs555){
if(typeof data209 === "string"){
if(func1(data209) > 131072){
const err584 = {instancePath:instancePath+"/inspection/details/explanation/predicate/state/column",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/1/properties/state/properties/column/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err584];
}
else {
vErrors.push(err584);
}
errors++;
}
}
else {
const err585 = {instancePath:instancePath+"/inspection/details/explanation/predicate/state/column",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/1/properties/state/properties/column/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err585];
}
else {
vErrors.push(err585);
}
errors++;
}
}
var valid98 = _errs555 === errors;
}
else {
var valid98 = true;
}
if(valid98){
if(data208.value !== undefined){
let data210 = data208.value;
const _errs557 = errors;
if(typeof data210 !== "string"){
const err586 = {instancePath:instancePath+"/inspection/details/explanation/predicate/state/value",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/1/properties/state/properties/value/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err586];
}
else {
vErrors.push(err586);
}
errors++;
}
if(!(((((data210 === "missing") || (data210 === "null")) || (data210 === "type_error")) || (data210 === "value")) || (data210 === "conflict"))){
const err587 = {instancePath:instancePath+"/inspection/details/explanation/predicate/state/value",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/1/properties/state/properties/value/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.inspection.properties.details.oneOf[2].properties.explanation.properties.predicate.oneOf[1].properties.state.properties.value.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err587];
}
else {
vErrors.push(err587);
}
errors++;
}
var valid98 = _errs557 === errors;
}
else {
var valid98 = true;
}
}
}
}
}
else {
const err588 = {instancePath:instancePath+"/inspection/details/explanation/predicate/state",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/1/properties/state/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err589 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err589];
}
else {
vErrors.push(err589);
}
errors++;
}
}
var _valid11 = _errs549 === errors;
if(_valid11 && valid95){
valid95 = false;
passing6 = [passing6, 1];
}
else {
if(_valid11){
valid95 = true;
passing6 = 1;
if(props7 !== true){
props7 = true;
}
}
const _errs559 = errors;
if(errors === _errs559){
if(data206 && typeof data206 == "object" && !Array.isArray(data206)){
let missing66;
if((data206.compare === undefined) && (missing66 = "compare")){
const err590 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/required",keyword:"required",params:{missingProperty: missing66},message:"must have required property '"+missing66+"'"};
if(vErrors === null){
vErrors = [err590];
}
else {
vErrors.push(err590);
}
errors++;
}
else {
const _errs561 = errors;
for(const key66 in data206){
if(!(key66 === "compare")){
const err591 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key66},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err591];
}
else {
vErrors.push(err591);
}
errors++;
break;
}
}
if(_errs561 === errors){
if(data206.compare !== undefined){
let data211 = data206.compare;
const _errs562 = errors;
if(errors === _errs562){
if(data211 && typeof data211 == "object" && !Array.isArray(data211)){
let missing67;
if((((data211.column === undefined) && (missing67 = "column")) || ((data211.op === undefined) && (missing67 = "op"))) || ((data211.type === undefined) && (missing67 = "type"))){
const err592 = {instancePath:instancePath+"/inspection/details/explanation/predicate/compare",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/properties/compare/required",keyword:"required",params:{missingProperty: missing67},message:"must have required property '"+missing67+"'"};
if(vErrors === null){
vErrors = [err592];
}
else {
vErrors.push(err592);
}
errors++;
}
else {
const _errs564 = errors;
for(const key67 in data211){
if(!(((key67 === "column") || (key67 === "op")) || (key67 === "type"))){
const err593 = {instancePath:instancePath+"/inspection/details/explanation/predicate/compare",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/properties/compare/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key67},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err593];
}
else {
vErrors.push(err593);
}
errors++;
break;
}
}
if(_errs564 === errors){
if(data211.column !== undefined){
let data212 = data211.column;
const _errs565 = errors;
if(errors === _errs565){
if(typeof data212 === "string"){
if(func1(data212) > 131072){
const err594 = {instancePath:instancePath+"/inspection/details/explanation/predicate/compare/column",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/properties/compare/properties/column/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err594];
}
else {
vErrors.push(err594);
}
errors++;
}
}
else {
const err595 = {instancePath:instancePath+"/inspection/details/explanation/predicate/compare/column",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/properties/compare/properties/column/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err595];
}
else {
vErrors.push(err595);
}
errors++;
}
}
var valid100 = _errs565 === errors;
}
else {
var valid100 = true;
}
if(valid100){
if(data211.op !== undefined){
let data213 = data211.op;
const _errs567 = errors;
if(typeof data213 !== "string"){
const err596 = {instancePath:instancePath+"/inspection/details/explanation/predicate/compare/op",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/properties/compare/properties/op/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err596];
}
else {
vErrors.push(err596);
}
errors++;
}
if(!((((((data213 === "eq") || (data213 === "ne")) || (data213 === "lt")) || (data213 === "le")) || (data213 === "gt")) || (data213 === "ge"))){
const err597 = {instancePath:instancePath+"/inspection/details/explanation/predicate/compare/op",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/properties/compare/properties/op/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.inspection.properties.details.oneOf[2].properties.explanation.properties.predicate.oneOf[2].properties.compare.properties.op.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err597];
}
else {
vErrors.push(err597);
}
errors++;
}
var valid100 = _errs567 === errors;
}
else {
var valid100 = true;
}
if(valid100){
if(data211.type !== undefined){
let data214 = data211.type;
const _errs569 = errors;
if(typeof data214 !== "string"){
const err598 = {instancePath:instancePath+"/inspection/details/explanation/predicate/compare/type",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/properties/compare/properties/type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err598];
}
else {
vErrors.push(err598);
}
errors++;
}
if(!((((((data214 === "int64") || (data214 === "uint64")) || (data214 === "float64")) || (data214 === "boolean")) || (data214 === "utf8")) || (data214 === "binary"))){
const err599 = {instancePath:instancePath+"/inspection/details/explanation/predicate/compare/type",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/properties/compare/properties/type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.inspection.properties.details.oneOf[2].properties.explanation.properties.predicate.oneOf[2].properties.compare.properties.type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err599];
}
else {
vErrors.push(err599);
}
errors++;
}
var valid100 = _errs569 === errors;
}
else {
var valid100 = true;
}
}
}
}
}
}
else {
const err600 = {instancePath:instancePath+"/inspection/details/explanation/predicate/compare",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/properties/compare/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err600];
}
else {
vErrors.push(err600);
}
errors++;
}
}
}
}
}
}
else {
const err601 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err601];
}
else {
vErrors.push(err601);
}
errors++;
}
}
var _valid11 = _errs559 === errors;
if(_valid11 && valid95){
valid95 = false;
passing6 = [passing6, 2];
}
else {
if(_valid11){
valid95 = true;
passing6 = 2;
if(props7 !== true){
props7 = true;
}
}
}
}
if(!valid95){
const err602 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf",keyword:"oneOf",params:{passingSchemas: passing6},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err602];
}
else {
vErrors.push(err602);
}
errors++;
}
else {
errors = _errs543;
if(vErrors !== null){
if(_errs543){
vErrors.length = _errs543;
}
else {
vErrors = null;
}
}
}
var valid93 = _errs542 === errors;
}
else {
var valid93 = true;
}
if(valid93){
if(data203.projection !== undefined){
let data215 = data203.projection;
const _errs571 = errors;
if(errors === _errs571){
if(Array.isArray(data215)){
if(data215.length > 8){
const err603 = {instancePath:instancePath+"/inspection/details/explanation/projection",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/projection/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err603];
}
else {
vErrors.push(err603);
}
errors++;
}
else {
var valid101 = true;
const len21 = data215.length;
for(let i21=0; i21<len21; i21++){
let data216 = data215[i21];
const _errs573 = errors;
if(errors === _errs573){
if(typeof data216 === "string"){
if(func1(data216) > 131072){
const err604 = {instancePath:instancePath+"/inspection/details/explanation/projection/" + i21,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/projection/items/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err604];
}
else {
vErrors.push(err604);
}
errors++;
}
}
else {
const err605 = {instancePath:instancePath+"/inspection/details/explanation/projection/" + i21,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/projection/items/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err605];
}
else {
vErrors.push(err605);
}
errors++;
}
}
var valid101 = _errs573 === errors;
if(!valid101){
break;
}
}
}
}
else {
const err606 = {instancePath:instancePath+"/inspection/details/explanation/projection",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/projection/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err606];
}
else {
vErrors.push(err606);
}
errors++;
}
}
var valid93 = _errs571 === errors;
}
else {
var valid93 = true;
}
if(valid93){
if(data203.limit !== undefined){
let data217 = data203.limit;
const _errs575 = errors;
const _errs576 = errors;
let valid102 = false;
const _errs577 = errors;
if(errors === _errs577){
if(typeof data217 === "string"){
if(func1(data217) > 131072){
const err607 = {instancePath:instancePath+"/inspection/details/explanation/limit",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/limit/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err607];
}
else {
vErrors.push(err607);
}
errors++;
}
}
else {
const err608 = {instancePath:instancePath+"/inspection/details/explanation/limit",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/limit/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err608];
}
else {
vErrors.push(err608);
}
errors++;
}
}
var _valid12 = _errs577 === errors;
valid102 = valid102 || _valid12;
const _errs579 = errors;
if(data217 !== null){
const err609 = {instancePath:instancePath+"/inspection/details/explanation/limit",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/limit/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err609];
}
else {
vErrors.push(err609);
}
errors++;
}
var _valid12 = _errs579 === errors;
valid102 = valid102 || _valid12;
if(!valid102){
const err610 = {instancePath:instancePath+"/inspection/details/explanation/limit",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/limit/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err610];
}
else {
vErrors.push(err610);
}
errors++;
}
else {
errors = _errs576;
if(vErrors !== null){
if(_errs576){
vErrors.length = _errs576;
}
else {
vErrors = null;
}
}
}
var valid93 = _errs575 === errors;
}
else {
var valid93 = true;
}
if(valid93){
if(data203.aggregate !== undefined){
let data218 = data203.aggregate;
const _errs581 = errors;
if(typeof data218 !== "string"){
const err611 = {instancePath:instancePath+"/inspection/details/explanation/aggregate",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/aggregate/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err611];
}
else {
vErrors.push(err611);
}
errors++;
}
if(!(((data218 === "rows") || (data218 === "count")) || (data218 === "sum"))){
const err612 = {instancePath:instancePath+"/inspection/details/explanation/aggregate",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/aggregate/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.inspection.properties.details.oneOf[2].properties.explanation.properties.aggregate.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err612];
}
else {
vErrors.push(err612);
}
errors++;
}
var valid93 = _errs581 === errors;
}
else {
var valid93 = true;
}
if(valid93){
if(data203.columns !== undefined){
let data219 = data203.columns;
const _errs583 = errors;
if(errors === _errs583){
if(Array.isArray(data219)){
if(data219.length > 8){
const err613 = {instancePath:instancePath+"/inspection/details/explanation/columns",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/columns/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err613];
}
else {
vErrors.push(err613);
}
errors++;
}
else {
var valid103 = true;
const len22 = data219.length;
for(let i22=0; i22<len22; i22++){
let data220 = data219[i22];
const _errs585 = errors;
if(errors === _errs585){
if(data220 && typeof data220 == "object" && !Array.isArray(data220)){
let missing68;
if(((data220.name === undefined) && (missing68 = "name")) || ((data220.type === undefined) && (missing68 = "type"))){
const err614 = {instancePath:instancePath+"/inspection/details/explanation/columns/" + i22,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/columns/items/required",keyword:"required",params:{missingProperty: missing68},message:"must have required property '"+missing68+"'"};
if(vErrors === null){
vErrors = [err614];
}
else {
vErrors.push(err614);
}
errors++;
}
else {
const _errs587 = errors;
for(const key68 in data220){
if(!((key68 === "name") || (key68 === "type"))){
const err615 = {instancePath:instancePath+"/inspection/details/explanation/columns/" + i22,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/columns/items/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key68},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err615];
}
else {
vErrors.push(err615);
}
errors++;
break;
}
}
if(_errs587 === errors){
if(data220.name !== undefined){
let data221 = data220.name;
const _errs588 = errors;
if(errors === _errs588){
if(typeof data221 === "string"){
if(func1(data221) > 131072){
const err616 = {instancePath:instancePath+"/inspection/details/explanation/columns/" + i22+"/name",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/columns/items/properties/name/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err616];
}
else {
vErrors.push(err616);
}
errors++;
}
}
else {
const err617 = {instancePath:instancePath+"/inspection/details/explanation/columns/" + i22+"/name",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/columns/items/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err617];
}
else {
vErrors.push(err617);
}
errors++;
}
}
var valid104 = _errs588 === errors;
}
else {
var valid104 = true;
}
if(valid104){
if(data220.type !== undefined){
let data222 = data220.type;
const _errs590 = errors;
if(typeof data222 !== "string"){
const err618 = {instancePath:instancePath+"/inspection/details/explanation/columns/" + i22+"/type",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/columns/items/properties/type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err618];
}
else {
vErrors.push(err618);
}
errors++;
}
if(!((((((data222 === "int64") || (data222 === "uint64")) || (data222 === "float64")) || (data222 === "boolean")) || (data222 === "utf8")) || (data222 === "binary"))){
const err619 = {instancePath:instancePath+"/inspection/details/explanation/columns/" + i22+"/type",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/columns/items/properties/type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.inspection.properties.details.oneOf[2].properties.explanation.properties.columns.items.properties.type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err619];
}
else {
vErrors.push(err619);
}
errors++;
}
var valid104 = _errs590 === errors;
}
else {
var valid104 = true;
}
}
}
}
}
else {
const err620 = {instancePath:instancePath+"/inspection/details/explanation/columns/" + i22,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/columns/items/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err620];
}
else {
vErrors.push(err620);
}
errors++;
}
}
var valid103 = _errs585 === errors;
if(!valid103){
break;
}
}
}
}
else {
const err621 = {instancePath:instancePath+"/inspection/details/explanation/columns",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/columns/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err621];
}
else {
vErrors.push(err621);
}
errors++;
}
}
var valid93 = _errs583 === errors;
}
else {
var valid93 = true;
}
if(valid93){
if(data203.budgets !== undefined){
let data223 = data203.budgets;
const _errs592 = errors;
if(errors === _errs592){
if(data223 && typeof data223 == "object" && !Array.isArray(data223)){
let missing69;
if((((data223.pages === undefined) && (missing69 = "pages")) || ((data223.segments === undefined) && (missing69 = "segments"))) || ((data223.result_bytes === undefined) && (missing69 = "result_bytes"))){
const err622 = {instancePath:instancePath+"/inspection/details/explanation/budgets",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/budgets/required",keyword:"required",params:{missingProperty: missing69},message:"must have required property '"+missing69+"'"};
if(vErrors === null){
vErrors = [err622];
}
else {
vErrors.push(err622);
}
errors++;
}
else {
const _errs594 = errors;
for(const key69 in data223){
if(!(((key69 === "pages") || (key69 === "segments")) || (key69 === "result_bytes"))){
const err623 = {instancePath:instancePath+"/inspection/details/explanation/budgets",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/budgets/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key69},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err623];
}
else {
vErrors.push(err623);
}
errors++;
break;
}
}
if(_errs594 === errors){
if(data223.pages !== undefined){
let data224 = data223.pages;
const _errs595 = errors;
if(errors === _errs595){
if(typeof data224 === "string"){
if(func1(data224) > 131072){
const err624 = {instancePath:instancePath+"/inspection/details/explanation/budgets/pages",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/budgets/properties/pages/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err624];
}
else {
vErrors.push(err624);
}
errors++;
}
}
else {
const err625 = {instancePath:instancePath+"/inspection/details/explanation/budgets/pages",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/budgets/properties/pages/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err625];
}
else {
vErrors.push(err625);
}
errors++;
}
}
var valid105 = _errs595 === errors;
}
else {
var valid105 = true;
}
if(valid105){
if(data223.segments !== undefined){
let data225 = data223.segments;
const _errs597 = errors;
if(errors === _errs597){
if(typeof data225 === "string"){
if(func1(data225) > 131072){
const err626 = {instancePath:instancePath+"/inspection/details/explanation/budgets/segments",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/budgets/properties/segments/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err626];
}
else {
vErrors.push(err626);
}
errors++;
}
}
else {
const err627 = {instancePath:instancePath+"/inspection/details/explanation/budgets/segments",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/budgets/properties/segments/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err627];
}
else {
vErrors.push(err627);
}
errors++;
}
}
var valid105 = _errs597 === errors;
}
else {
var valid105 = true;
}
if(valid105){
if(data223.result_bytes !== undefined){
let data226 = data223.result_bytes;
const _errs599 = errors;
if(errors === _errs599){
if(typeof data226 === "string"){
if(func1(data226) > 131072){
const err628 = {instancePath:instancePath+"/inspection/details/explanation/budgets/result_bytes",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/budgets/properties/result_bytes/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err628];
}
else {
vErrors.push(err628);
}
errors++;
}
}
else {
const err629 = {instancePath:instancePath+"/inspection/details/explanation/budgets/result_bytes",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/budgets/properties/result_bytes/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err629];
}
else {
vErrors.push(err629);
}
errors++;
}
}
var valid105 = _errs599 === errors;
}
else {
var valid105 = true;
}
}
}
}
}
}
else {
const err630 = {instancePath:instancePath+"/inspection/details/explanation/budgets",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/budgets/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err630];
}
else {
vErrors.push(err630);
}
errors++;
}
}
var valid93 = _errs592 === errors;
}
else {
var valid93 = true;
}
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
const err631 = {instancePath:instancePath+"/inspection/details/explanation",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err632 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err632];
}
else {
vErrors.push(err632);
}
errors++;
}
}
var _valid10 = _errs532 === errors;
if(_valid10 && valid85){
valid85 = false;
passing5 = [passing5, 2];
}
else {
if(_valid10){
valid85 = true;
passing5 = 2;
if(props6 !== true){
props6 = true;
}
}
}
}
if(!valid85){
const err633 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf",keyword:"oneOf",params:{passingSchemas: passing5},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err633];
}
else {
vErrors.push(err633);
}
errors++;
}
else {
errors = _errs509;
if(vErrors !== null){
if(_errs509){
vErrors.length = _errs509;
}
else {
vErrors = null;
}
}
}
var valid82 = _errs508 === errors;
}
else {
var valid82 = true;
}
}
}
}
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
const err634 = {instancePath:instancePath+"/inspection",schemaPath:"#/oneOf/4/properties/inspection/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err634];
}
else {
vErrors.push(err634);
}
errors++;
}
}
}
}
}
}
else {
const err635 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err635];
}
else {
vErrors.push(err635);
}
errors++;
}
}
var _valid0 = _errs480 === errors;
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
const _errs601 = errors;
if(errors === _errs601){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing70;
if((data.prepared === undefined) && (missing70 = "prepared")){
const err636 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing70},message:"must have required property '"+missing70+"'"};
if(vErrors === null){
vErrors = [err636];
}
else {
vErrors.push(err636);
}
errors++;
}
else {
const _errs603 = errors;
for(const key70 in data){
if(!(key70 === "prepared")){
const err637 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key70},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err637];
}
else {
vErrors.push(err637);
}
errors++;
break;
}
}
if(_errs603 === errors){
if(data.prepared !== undefined){
let data227 = data.prepared;
const _errs605 = errors;
let valid107 = false;
const _errs606 = errors;
if(errors === _errs606){
if(data227 && typeof data227 == "object" && !Array.isArray(data227)){
let missing71;
if((data227.token === undefined) && (missing71 = "token")){
const err638 = {instancePath:instancePath+"/prepared",schemaPath:"#/oneOf/5/properties/prepared/anyOf/0/required",keyword:"required",params:{missingProperty: missing71},message:"must have required property '"+missing71+"'"};
if(vErrors === null){
vErrors = [err638];
}
else {
vErrors.push(err638);
}
errors++;
}
else {
const _errs608 = errors;
for(const key71 in data227){
if(!(key71 === "token")){
const err639 = {instancePath:instancePath+"/prepared",schemaPath:"#/oneOf/5/properties/prepared/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key71},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err639];
}
else {
vErrors.push(err639);
}
errors++;
break;
}
}
if(_errs608 === errors){
if(data227.token !== undefined){
let data228 = data227.token;
const _errs609 = errors;
if(errors === _errs609){
if(typeof data228 === "string"){
if(func1(data228) > 131072){
const err640 = {instancePath:instancePath+"/prepared/token",schemaPath:"#/oneOf/5/properties/prepared/anyOf/0/properties/token/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err640];
}
else {
vErrors.push(err640);
}
errors++;
}
}
else {
const err641 = {instancePath:instancePath+"/prepared/token",schemaPath:"#/oneOf/5/properties/prepared/anyOf/0/properties/token/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err641];
}
else {
vErrors.push(err641);
}
errors++;
}
}
}
}
}
}
else {
const err642 = {instancePath:instancePath+"/prepared",schemaPath:"#/oneOf/5/properties/prepared/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err642];
}
else {
vErrors.push(err642);
}
errors++;
}
}
var _valid13 = _errs606 === errors;
valid107 = valid107 || _valid13;
const _errs611 = errors;
if(data227 !== null){
const err643 = {instancePath:instancePath+"/prepared",schemaPath:"#/oneOf/5/properties/prepared/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err643];
}
else {
vErrors.push(err643);
}
errors++;
}
var _valid13 = _errs611 === errors;
valid107 = valid107 || _valid13;
if(!valid107){
const err644 = {instancePath:instancePath+"/prepared",schemaPath:"#/oneOf/5/properties/prepared/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err644];
}
else {
vErrors.push(err644);
}
errors++;
}
else {
errors = _errs605;
if(vErrors !== null){
if(_errs605){
vErrors.length = _errs605;
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
const err645 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err645];
}
else {
vErrors.push(err645);
}
errors++;
}
}
var _valid0 = _errs601 === errors;
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
const _errs613 = errors;
if(errors === _errs613){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing72;
if((data.receipt === undefined) && (missing72 = "receipt")){
const err646 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing72},message:"must have required property '"+missing72+"'"};
if(vErrors === null){
vErrors = [err646];
}
else {
vErrors.push(err646);
}
errors++;
}
else {
const _errs615 = errors;
for(const key72 in data){
if(!(key72 === "receipt")){
const err647 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key72},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err647];
}
else {
vErrors.push(err647);
}
errors++;
break;
}
}
if(_errs615 === errors){
if(data.receipt !== undefined){
let data229 = data.receipt;
const _errs616 = errors;
if(errors === _errs616){
if(data229 && typeof data229 == "object" && !Array.isArray(data229)){
let missing73;
if((data229.position === undefined) && (missing73 = "position")){
const err648 = {instancePath:instancePath+"/receipt",schemaPath:"#/oneOf/6/properties/receipt/required",keyword:"required",params:{missingProperty: missing73},message:"must have required property '"+missing73+"'"};
if(vErrors === null){
vErrors = [err648];
}
else {
vErrors.push(err648);
}
errors++;
}
else {
const _errs618 = errors;
for(const key73 in data229){
if(!(key73 === "position")){
const err649 = {instancePath:instancePath+"/receipt",schemaPath:"#/oneOf/6/properties/receipt/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key73},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err649];
}
else {
vErrors.push(err649);
}
errors++;
break;
}
}
if(_errs618 === errors){
if(data229.position !== undefined){
let data230 = data229.position;
const _errs619 = errors;
if(!(((typeof data230 == "number") && (!(data230 % 1) && !isNaN(data230))) && (isFinite(data230)))){
const err650 = {instancePath:instancePath+"/receipt/position",schemaPath:"#/oneOf/6/properties/receipt/properties/position/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err650];
}
else {
vErrors.push(err650);
}
errors++;
}
if(errors === _errs619){
if((typeof data230 == "number") && (isFinite(data230))){
if(data230 > 9007199254740991 || isNaN(data230)){
const err651 = {instancePath:instancePath+"/receipt/position",schemaPath:"#/oneOf/6/properties/receipt/properties/position/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err651];
}
else {
vErrors.push(err651);
}
errors++;
}
else {
if(data230 < 0 || isNaN(data230)){
const err652 = {instancePath:instancePath+"/receipt/position",schemaPath:"#/oneOf/6/properties/receipt/properties/position/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err652];
}
else {
vErrors.push(err652);
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
const err653 = {instancePath:instancePath+"/receipt",schemaPath:"#/oneOf/6/properties/receipt/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err653];
}
else {
vErrors.push(err653);
}
errors++;
}
}
}
}
}
}
else {
const err654 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err654];
}
else {
vErrors.push(err654);
}
errors++;
}
}
var _valid0 = _errs613 === errors;
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
const _errs621 = errors;
if(errors === _errs621){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing74;
if((data.observation === undefined) && (missing74 = "observation")){
const err655 = {instancePath,schemaPath:"#/oneOf/7/required",keyword:"required",params:{missingProperty: missing74},message:"must have required property '"+missing74+"'"};
if(vErrors === null){
vErrors = [err655];
}
else {
vErrors.push(err655);
}
errors++;
}
else {
const _errs623 = errors;
for(const key74 in data){
if(!(key74 === "observation")){
const err656 = {instancePath,schemaPath:"#/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key74},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err656];
}
else {
vErrors.push(err656);
}
errors++;
break;
}
}
if(_errs623 === errors){
if(data.observation !== undefined){
let data231 = data.observation;
const _errs625 = errors;
let valid112 = false;
let passing7 = null;
const _errs626 = errors;
if(errors === _errs626){
if(data231 && typeof data231 == "object" && !Array.isArray(data231)){
let missing75;
if((data231.pending === undefined) && (missing75 = "pending")){
const err657 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/7/properties/observation/oneOf/0/required",keyword:"required",params:{missingProperty: missing75},message:"must have required property '"+missing75+"'"};
if(vErrors === null){
vErrors = [err657];
}
else {
vErrors.push(err657);
}
errors++;
}
else {
const _errs628 = errors;
for(const key75 in data231){
if(!(key75 === "pending")){
const err658 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/7/properties/observation/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key75},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err658];
}
else {
vErrors.push(err658);
}
errors++;
break;
}
}
if(_errs628 === errors){
if(data231.pending !== undefined){
let data232 = data231.pending;
const _errs629 = errors;
if(errors === _errs629){
if(data232 && typeof data232 == "object" && !Array.isArray(data232)){
if(Object.keys(data232).length > 0){
const err659 = {instancePath:instancePath+"/observation/pending",schemaPath:"#/oneOf/7/properties/observation/oneOf/0/properties/pending/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err659];
}
else {
vErrors.push(err659);
}
errors++;
}
}
else {
const err660 = {instancePath:instancePath+"/observation/pending",schemaPath:"#/oneOf/7/properties/observation/oneOf/0/properties/pending/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err660];
}
else {
vErrors.push(err660);
}
errors++;
}
}
}
}
}
}
else {
const err661 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/7/properties/observation/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err661];
}
else {
vErrors.push(err661);
}
errors++;
}
}
var _valid14 = _errs626 === errors;
if(_valid14){
valid112 = true;
passing7 = 0;
var props9 = true;
}
const _errs631 = errors;
if(errors === _errs631){
if(data231 && typeof data231 == "object" && !Array.isArray(data231)){
let missing76;
if((data231.committed === undefined) && (missing76 = "committed")){
const err662 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/7/properties/observation/oneOf/1/required",keyword:"required",params:{missingProperty: missing76},message:"must have required property '"+missing76+"'"};
if(vErrors === null){
vErrors = [err662];
}
else {
vErrors.push(err662);
}
errors++;
}
else {
const _errs633 = errors;
for(const key76 in data231){
if(!(key76 === "committed")){
const err663 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/7/properties/observation/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key76},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err663];
}
else {
vErrors.push(err663);
}
errors++;
break;
}
}
if(_errs633 === errors){
if(data231.committed !== undefined){
let data233 = data231.committed;
const _errs634 = errors;
if(errors === _errs634){
if(data233 && typeof data233 == "object" && !Array.isArray(data233)){
if(Object.keys(data233).length > 0){
const err664 = {instancePath:instancePath+"/observation/committed",schemaPath:"#/oneOf/7/properties/observation/oneOf/1/properties/committed/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err664];
}
else {
vErrors.push(err664);
}
errors++;
}
}
else {
const err665 = {instancePath:instancePath+"/observation/committed",schemaPath:"#/oneOf/7/properties/observation/oneOf/1/properties/committed/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err665];
}
else {
vErrors.push(err665);
}
errors++;
}
}
}
}
}
}
else {
const err666 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/7/properties/observation/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err666];
}
else {
vErrors.push(err666);
}
errors++;
}
}
var _valid14 = _errs631 === errors;
if(_valid14 && valid112){
valid112 = false;
passing7 = [passing7, 1];
}
else {
if(_valid14){
valid112 = true;
passing7 = 1;
if(props9 !== true){
props9 = true;
}
}
const _errs636 = errors;
if(errors === _errs636){
if(data231 && typeof data231 == "object" && !Array.isArray(data231)){
let missing77;
if((data231.rejected === undefined) && (missing77 = "rejected")){
const err667 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/7/properties/observation/oneOf/2/required",keyword:"required",params:{missingProperty: missing77},message:"must have required property '"+missing77+"'"};
if(vErrors === null){
vErrors = [err667];
}
else {
vErrors.push(err667);
}
errors++;
}
else {
const _errs638 = errors;
for(const key77 in data231){
if(!(key77 === "rejected")){
const err668 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/7/properties/observation/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key77},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err668];
}
else {
vErrors.push(err668);
}
errors++;
break;
}
}
if(_errs638 === errors){
if(data231.rejected !== undefined){
let data234 = data231.rejected;
const _errs639 = errors;
if(errors === _errs639){
if(typeof data234 === "string"){
if(func1(data234) > 512){
const err669 = {instancePath:instancePath+"/observation/rejected",schemaPath:"#/oneOf/7/properties/observation/oneOf/2/properties/rejected/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err669];
}
else {
vErrors.push(err669);
}
errors++;
}
else {
if(!pattern4.test(data234)){
const err670 = {instancePath:instancePath+"/observation/rejected",schemaPath:"#/oneOf/7/properties/observation/oneOf/2/properties/rejected/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
if(vErrors === null){
vErrors = [err670];
}
else {
vErrors.push(err670);
}
errors++;
}
}
}
else {
const err671 = {instancePath:instancePath+"/observation/rejected",schemaPath:"#/oneOf/7/properties/observation/oneOf/2/properties/rejected/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
const err672 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/7/properties/observation/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err672];
}
else {
vErrors.push(err672);
}
errors++;
}
}
var _valid14 = _errs636 === errors;
if(_valid14 && valid112){
valid112 = false;
passing7 = [passing7, 2];
}
else {
if(_valid14){
valid112 = true;
passing7 = 2;
if(props9 !== true){
props9 = true;
}
}
}
}
if(!valid112){
const err673 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/7/properties/observation/oneOf",keyword:"oneOf",params:{passingSchemas: passing7},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err673];
}
else {
vErrors.push(err673);
}
errors++;
}
else {
errors = _errs625;
if(vErrors !== null){
if(_errs625){
vErrors.length = _errs625;
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
const err674 = {instancePath,schemaPath:"#/oneOf/7/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err674];
}
else {
vErrors.push(err674);
}
errors++;
}
}
var _valid0 = _errs621 === errors;
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
const _errs641 = errors;
if(errors === _errs641){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing78;
if((data.status === undefined) && (missing78 = "status")){
const err675 = {instancePath,schemaPath:"#/oneOf/8/required",keyword:"required",params:{missingProperty: missing78},message:"must have required property '"+missing78+"'"};
if(vErrors === null){
vErrors = [err675];
}
else {
vErrors.push(err675);
}
errors++;
}
else {
const _errs643 = errors;
for(const key78 in data){
if(!(key78 === "status")){
const err676 = {instancePath,schemaPath:"#/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key78},message:"must NOT have additional properties"};
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
if(_errs643 === errors){
if(data.status !== undefined){
let data235 = data.status;
const _errs645 = errors;
let valid117 = false;
const _errs646 = errors;
if(errors === _errs646){
if(data235 && typeof data235 == "object" && !Array.isArray(data235)){
let missing79;
if((((((data235.reference === undefined) && (missing79 = "reference")) || ((data235.phase === undefined) && (missing79 = "phase"))) || ((data235.correlation === undefined) && (missing79 = "correlation"))) || ((data235.manifest === undefined) && (missing79 = "manifest"))) || ((data235.collected === undefined) && (missing79 = "collected"))){
const err677 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/8/properties/status/anyOf/0/required",keyword:"required",params:{missingProperty: missing79},message:"must have required property '"+missing79+"'"};
if(vErrors === null){
vErrors = [err677];
}
else {
vErrors.push(err677);
}
errors++;
}
else {
const _errs648 = errors;
for(const key79 in data235){
if(!(((((key79 === "reference") || (key79 === "phase")) || (key79 === "correlation")) || (key79 === "manifest")) || (key79 === "collected"))){
const err678 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/8/properties/status/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key79},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err678];
}
else {
vErrors.push(err678);
}
errors++;
break;
}
}
if(_errs648 === errors){
if(data235.reference !== undefined){
let data236 = data235.reference;
const _errs649 = errors;
if(errors === _errs649){
if(typeof data236 === "string"){
if(func1(data236) > 512){
const err679 = {instancePath:instancePath+"/status/reference",schemaPath:"#/oneOf/8/properties/status/anyOf/0/properties/reference/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err679];
}
else {
vErrors.push(err679);
}
errors++;
}
else {
if(!pattern4.test(data236)){
const err680 = {instancePath:instancePath+"/status/reference",schemaPath:"#/oneOf/8/properties/status/anyOf/0/properties/reference/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
if(vErrors === null){
vErrors = [err680];
}
else {
vErrors.push(err680);
}
errors++;
}
}
}
else {
const err681 = {instancePath:instancePath+"/status/reference",schemaPath:"#/oneOf/8/properties/status/anyOf/0/properties/reference/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err681];
}
else {
vErrors.push(err681);
}
errors++;
}
}
var valid118 = _errs649 === errors;
}
else {
var valid118 = true;
}
if(valid118){
if(data235.phase !== undefined){
let data237 = data235.phase;
const _errs651 = errors;
if(typeof data237 !== "string"){
const err682 = {instancePath:instancePath+"/status/phase",schemaPath:"#/oneOf/8/properties/status/anyOf/0/properties/phase/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err682];
}
else {
vErrors.push(err682);
}
errors++;
}
if(!((((((((data237 === "uploading") || (data237 === "sealed")) || (data237 === "admitted")) || (data237 === "complete")) || (data237 === "cancelled")) || (data237 === "denied")) || (data237 === "rejected")) || (data237 === "retired"))){
const err683 = {instancePath:instancePath+"/status/phase",schemaPath:"#/oneOf/8/properties/status/anyOf/0/properties/phase/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[8].properties.status.anyOf[0].properties.phase.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err683];
}
else {
vErrors.push(err683);
}
errors++;
}
var valid118 = _errs651 === errors;
}
else {
var valid118 = true;
}
if(valid118){
if(data235.correlation !== undefined){
let data238 = data235.correlation;
const _errs653 = errors;
if(errors === _errs653){
if(typeof data238 === "string"){
if(func1(data238) > 131072){
const err684 = {instancePath:instancePath+"/status/correlation",schemaPath:"#/oneOf/8/properties/status/anyOf/0/properties/correlation/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err684];
}
else {
vErrors.push(err684);
}
errors++;
}
}
else {
const err685 = {instancePath:instancePath+"/status/correlation",schemaPath:"#/oneOf/8/properties/status/anyOf/0/properties/correlation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err685];
}
else {
vErrors.push(err685);
}
errors++;
}
}
var valid118 = _errs653 === errors;
}
else {
var valid118 = true;
}
if(valid118){
if(data235.manifest !== undefined){
let data239 = data235.manifest;
const _errs655 = errors;
const _errs656 = errors;
let valid119 = false;
const _errs657 = errors;
if(errors === _errs657){
if(typeof data239 === "string"){
if(func1(data239) > 512){
const err686 = {instancePath:instancePath+"/status/manifest",schemaPath:"#/oneOf/8/properties/status/anyOf/0/properties/manifest/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err686];
}
else {
vErrors.push(err686);
}
errors++;
}
else {
if(!pattern4.test(data239)){
const err687 = {instancePath:instancePath+"/status/manifest",schemaPath:"#/oneOf/8/properties/status/anyOf/0/properties/manifest/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
if(vErrors === null){
vErrors = [err687];
}
else {
vErrors.push(err687);
}
errors++;
}
}
}
else {
const err688 = {instancePath:instancePath+"/status/manifest",schemaPath:"#/oneOf/8/properties/status/anyOf/0/properties/manifest/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err688];
}
else {
vErrors.push(err688);
}
errors++;
}
}
var _valid16 = _errs657 === errors;
valid119 = valid119 || _valid16;
const _errs659 = errors;
if(data239 !== null){
const err689 = {instancePath:instancePath+"/status/manifest",schemaPath:"#/oneOf/8/properties/status/anyOf/0/properties/manifest/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err689];
}
else {
vErrors.push(err689);
}
errors++;
}
var _valid16 = _errs659 === errors;
valid119 = valid119 || _valid16;
if(!valid119){
const err690 = {instancePath:instancePath+"/status/manifest",schemaPath:"#/oneOf/8/properties/status/anyOf/0/properties/manifest/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err690];
}
else {
vErrors.push(err690);
}
errors++;
}
else {
errors = _errs656;
if(vErrors !== null){
if(_errs656){
vErrors.length = _errs656;
}
else {
vErrors = null;
}
}
}
var valid118 = _errs655 === errors;
}
else {
var valid118 = true;
}
if(valid118){
if(data235.collected !== undefined){
const _errs661 = errors;
if(typeof data235.collected !== "boolean"){
const err691 = {instancePath:instancePath+"/status/collected",schemaPath:"#/oneOf/8/properties/status/anyOf/0/properties/collected/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err691];
}
else {
vErrors.push(err691);
}
errors++;
}
var valid118 = _errs661 === errors;
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
else {
const err692 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/8/properties/status/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err692];
}
else {
vErrors.push(err692);
}
errors++;
}
}
var _valid15 = _errs646 === errors;
valid117 = valid117 || _valid15;
const _errs663 = errors;
if(data235 !== null){
const err693 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/8/properties/status/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err693];
}
else {
vErrors.push(err693);
}
errors++;
}
var _valid15 = _errs663 === errors;
valid117 = valid117 || _valid15;
if(!valid117){
const err694 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/8/properties/status/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err694];
}
else {
vErrors.push(err694);
}
errors++;
}
else {
errors = _errs645;
if(vErrors !== null){
if(_errs645){
vErrors.length = _errs645;
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
const err695 = {instancePath,schemaPath:"#/oneOf/8/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err695];
}
else {
vErrors.push(err695);
}
errors++;
}
}
var _valid0 = _errs641 === errors;
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
const _errs665 = errors;
if(errors === _errs665){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing80;
if((data.page === undefined) && (missing80 = "page")){
const err696 = {instancePath,schemaPath:"#/oneOf/9/required",keyword:"required",params:{missingProperty: missing80},message:"must have required property '"+missing80+"'"};
if(vErrors === null){
vErrors = [err696];
}
else {
vErrors.push(err696);
}
errors++;
}
else {
const _errs667 = errors;
for(const key80 in data){
if(!(key80 === "page")){
const err697 = {instancePath,schemaPath:"#/oneOf/9/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key80},message:"must NOT have additional properties"};
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
if(_errs667 === errors){
if(data.page !== undefined){
let data241 = data.page;
const _errs668 = errors;
if(errors === _errs668){
if(data241 && typeof data241 == "object" && !Array.isArray(data241)){
let missing81;
if(((data241.evidence === undefined) && (missing81 = "evidence")) || ((data241.cells === undefined) && (missing81 = "cells"))){
const err698 = {instancePath:instancePath+"/page",schemaPath:"#/oneOf/9/properties/page/required",keyword:"required",params:{missingProperty: missing81},message:"must have required property '"+missing81+"'"};
if(vErrors === null){
vErrors = [err698];
}
else {
vErrors.push(err698);
}
errors++;
}
else {
const _errs670 = errors;
for(const key81 in data241){
if(!((key81 === "evidence") || (key81 === "cells"))){
const err699 = {instancePath:instancePath+"/page",schemaPath:"#/oneOf/9/properties/page/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key81},message:"must NOT have additional properties"};
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
if(_errs670 === errors){
if(data241.evidence !== undefined){
let data242 = data241.evidence;
const _errs671 = errors;
if(errors === _errs671){
if(data242 && typeof data242 == "object" && !Array.isArray(data242)){
let missing82;
if(((((((data242.manifest === undefined) && (missing82 = "manifest")) || ((data242.columns === undefined) && (missing82 = "columns"))) || ((data242.ordinal === undefined) && (missing82 = "ordinal"))) || ((data242.rows === undefined) && (missing82 = "rows"))) || ((data242.ipc === undefined) && (missing82 = "ipc"))) || ((data242.next === undefined) && (missing82 = "next"))){
const err700 = {instancePath:instancePath+"/page/evidence",schemaPath:"#/oneOf/9/properties/page/properties/evidence/required",keyword:"required",params:{missingProperty: missing82},message:"must have required property '"+missing82+"'"};
if(vErrors === null){
vErrors = [err700];
}
else {
vErrors.push(err700);
}
errors++;
}
else {
const _errs673 = errors;
for(const key82 in data242){
if(!((((((key82 === "manifest") || (key82 === "columns")) || (key82 === "ordinal")) || (key82 === "rows")) || (key82 === "ipc")) || (key82 === "next"))){
const err701 = {instancePath:instancePath+"/page/evidence",schemaPath:"#/oneOf/9/properties/page/properties/evidence/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key82},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err701];
}
else {
vErrors.push(err701);
}
errors++;
break;
}
}
if(_errs673 === errors){
if(data242.manifest !== undefined){
let data243 = data242.manifest;
const _errs674 = errors;
if(errors === _errs674){
if(data243 && typeof data243 == "object" && !Array.isArray(data243)){
let missing83;
if((((((((((((((((((data243.job === undefined) && (missing83 = "job")) || ((data243.source === undefined) && (missing83 = "source"))) || ((data243.requester === undefined) && (missing83 = "requester"))) || ((data243.correlation === undefined) && (missing83 = "correlation"))) || ((data243.policy_revision === undefined) && (missing83 = "policy_revision"))) || ((data243.request === undefined) && (missing83 = "request"))) || ((data243.basis === undefined) && (missing83 = "basis"))) || ((data243.plan === undefined) && (missing83 = "plan"))) || ((data243.pages === undefined) && (missing83 = "pages"))) || ((data243.scanned === undefined) && (missing83 = "scanned"))) || ((data243.selected === undefined) && (missing83 = "selected"))) || ((data243.segments === undefined) && (missing83 = "segments"))) || ((data243.rows === undefined) && (missing83 = "rows"))) || ((data243.bytes === undefined) && (missing83 = "bytes"))) || ((data243.sum === undefined) && (missing83 = "sum"))) || ((data243.finished === undefined) && (missing83 = "finished"))) || ((data243.chain === undefined) && (missing83 = "chain"))){
const err702 = {instancePath:instancePath+"/page/evidence/manifest",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/required",keyword:"required",params:{missingProperty: missing83},message:"must have required property '"+missing83+"'"};
if(vErrors === null){
vErrors = [err702];
}
else {
vErrors.push(err702);
}
errors++;
}
else {
const _errs676 = errors;
for(const key83 in data243){
if(!(func19.call(schema33.oneOf[9].properties.page.properties.evidence.properties.manifest.properties, key83))){
const err703 = {instancePath:instancePath+"/page/evidence/manifest",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key83},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err703];
}
else {
vErrors.push(err703);
}
errors++;
break;
}
}
if(_errs676 === errors){
if(data243.job !== undefined){
let data244 = data243.job;
const _errs677 = errors;
if(!(((typeof data244 == "number") && (!(data244 % 1) && !isNaN(data244))) && (isFinite(data244)))){
const err704 = {instancePath:instancePath+"/page/evidence/manifest/job",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/job/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err704];
}
else {
vErrors.push(err704);
}
errors++;
}
if(errors === _errs677){
if((typeof data244 == "number") && (isFinite(data244))){
if(data244 > 9007199254740991 || isNaN(data244)){
const err705 = {instancePath:instancePath+"/page/evidence/manifest/job",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/job/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err705];
}
else {
vErrors.push(err705);
}
errors++;
}
else {
if(data244 < 0 || isNaN(data244)){
const err706 = {instancePath:instancePath+"/page/evidence/manifest/job",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/job/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid123 = _errs677 === errors;
}
else {
var valid123 = true;
}
if(valid123){
if(data243.source !== undefined){
let data245 = data243.source;
const _errs679 = errors;
if(errors === _errs679){
if(data245 && typeof data245 == "object" && !Array.isArray(data245)){
let missing84;
if((((data245.pid === undefined) && (missing84 = "pid")) || ((data245.input === undefined) && (missing84 = "input"))) || ((data245.index === undefined) && (missing84 = "index"))){
const err707 = {instancePath:instancePath+"/page/evidence/manifest/source",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/source/required",keyword:"required",params:{missingProperty: missing84},message:"must have required property '"+missing84+"'"};
if(vErrors === null){
vErrors = [err707];
}
else {
vErrors.push(err707);
}
errors++;
}
else {
const _errs681 = errors;
for(const key84 in data245){
if(!(((key84 === "pid") || (key84 === "input")) || (key84 === "index"))){
const err708 = {instancePath:instancePath+"/page/evidence/manifest/source",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/source/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key84},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err708];
}
else {
vErrors.push(err708);
}
errors++;
break;
}
}
if(_errs681 === errors){
if(data245.pid !== undefined){
let data246 = data245.pid;
const _errs682 = errors;
if(!(((typeof data246 == "number") && (!(data246 % 1) && !isNaN(data246))) && (isFinite(data246)))){
const err709 = {instancePath:instancePath+"/page/evidence/manifest/source/pid",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/source/properties/pid/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err709];
}
else {
vErrors.push(err709);
}
errors++;
}
if(errors === _errs682){
if((typeof data246 == "number") && (isFinite(data246))){
if(data246 > 9007199254740991 || isNaN(data246)){
const err710 = {instancePath:instancePath+"/page/evidence/manifest/source/pid",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/source/properties/pid/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err710];
}
else {
vErrors.push(err710);
}
errors++;
}
else {
if(data246 < 0 || isNaN(data246)){
const err711 = {instancePath:instancePath+"/page/evidence/manifest/source/pid",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/source/properties/pid/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err711];
}
else {
vErrors.push(err711);
}
errors++;
}
}
}
}
var valid124 = _errs682 === errors;
}
else {
var valid124 = true;
}
if(valid124){
if(data245.input !== undefined){
let data247 = data245.input;
const _errs684 = errors;
if(!(((typeof data247 == "number") && (!(data247 % 1) && !isNaN(data247))) && (isFinite(data247)))){
const err712 = {instancePath:instancePath+"/page/evidence/manifest/source/input",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/source/properties/input/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err712];
}
else {
vErrors.push(err712);
}
errors++;
}
if(errors === _errs684){
if((typeof data247 == "number") && (isFinite(data247))){
if(data247 > 9007199254740991 || isNaN(data247)){
const err713 = {instancePath:instancePath+"/page/evidence/manifest/source/input",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/source/properties/input/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err713];
}
else {
vErrors.push(err713);
}
errors++;
}
else {
if(data247 < 0 || isNaN(data247)){
const err714 = {instancePath:instancePath+"/page/evidence/manifest/source/input",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/source/properties/input/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err714];
}
else {
vErrors.push(err714);
}
errors++;
}
}
}
}
var valid124 = _errs684 === errors;
}
else {
var valid124 = true;
}
if(valid124){
if(data245.index !== undefined){
let data248 = data245.index;
const _errs686 = errors;
if(!(((typeof data248 == "number") && (!(data248 % 1) && !isNaN(data248))) && (isFinite(data248)))){
const err715 = {instancePath:instancePath+"/page/evidence/manifest/source/index",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/source/properties/index/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err715];
}
else {
vErrors.push(err715);
}
errors++;
}
if(errors === _errs686){
if((typeof data248 == "number") && (isFinite(data248))){
if(data248 > 255 || isNaN(data248)){
const err716 = {instancePath:instancePath+"/page/evidence/manifest/source/index",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/source/properties/index/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err716];
}
else {
vErrors.push(err716);
}
errors++;
}
else {
if(data248 < 0 || isNaN(data248)){
const err717 = {instancePath:instancePath+"/page/evidence/manifest/source/index",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/source/properties/index/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err717];
}
else {
vErrors.push(err717);
}
errors++;
}
}
}
}
var valid124 = _errs686 === errors;
}
else {
var valid124 = true;
}
}
}
}
}
}
else {
const err718 = {instancePath:instancePath+"/page/evidence/manifest/source",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/source/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err718];
}
else {
vErrors.push(err718);
}
errors++;
}
}
var valid123 = _errs679 === errors;
}
else {
var valid123 = true;
}
if(valid123){
if(data243.requester !== undefined){
let data249 = data243.requester;
const _errs688 = errors;
if(!(((typeof data249 == "number") && (!(data249 % 1) && !isNaN(data249))) && (isFinite(data249)))){
const err719 = {instancePath:instancePath+"/page/evidence/manifest/requester",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/requester/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err719];
}
else {
vErrors.push(err719);
}
errors++;
}
if(errors === _errs688){
if((typeof data249 == "number") && (isFinite(data249))){
if(data249 > 9007199254740991 || isNaN(data249)){
const err720 = {instancePath:instancePath+"/page/evidence/manifest/requester",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/requester/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err720];
}
else {
vErrors.push(err720);
}
errors++;
}
else {
if(data249 < 0 || isNaN(data249)){
const err721 = {instancePath:instancePath+"/page/evidence/manifest/requester",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/requester/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err721];
}
else {
vErrors.push(err721);
}
errors++;
}
}
}
}
var valid123 = _errs688 === errors;
}
else {
var valid123 = true;
}
if(valid123){
if(data243.correlation !== undefined){
let data250 = data243.correlation;
const _errs690 = errors;
if(errors === _errs690){
if(typeof data250 === "string"){
if(func1(data250) > 131072){
const err722 = {instancePath:instancePath+"/page/evidence/manifest/correlation",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/correlation/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err723 = {instancePath:instancePath+"/page/evidence/manifest/correlation",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/correlation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err723];
}
else {
vErrors.push(err723);
}
errors++;
}
}
var valid123 = _errs690 === errors;
}
else {
var valid123 = true;
}
if(valid123){
if(data243.policy_revision !== undefined){
let data251 = data243.policy_revision;
const _errs692 = errors;
if(errors === _errs692){
if(typeof data251 === "string"){
if(func1(data251) > 131072){
const err724 = {instancePath:instancePath+"/page/evidence/manifest/policy_revision",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/policy_revision/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err724];
}
else {
vErrors.push(err724);
}
errors++;
}
}
else {
const err725 = {instancePath:instancePath+"/page/evidence/manifest/policy_revision",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/policy_revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err725];
}
else {
vErrors.push(err725);
}
errors++;
}
}
var valid123 = _errs692 === errors;
}
else {
var valid123 = true;
}
if(valid123){
if(data243.request !== undefined){
let data252 = data243.request;
const _errs694 = errors;
if(errors === _errs694){
if(typeof data252 === "string"){
if(func1(data252) > 512){
const err726 = {instancePath:instancePath+"/page/evidence/manifest/request",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/request/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err726];
}
else {
vErrors.push(err726);
}
errors++;
}
else {
if(!pattern4.test(data252)){
const err727 = {instancePath:instancePath+"/page/evidence/manifest/request",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/request/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
if(vErrors === null){
vErrors = [err727];
}
else {
vErrors.push(err727);
}
errors++;
}
}
}
else {
const err728 = {instancePath:instancePath+"/page/evidence/manifest/request",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/request/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err728];
}
else {
vErrors.push(err728);
}
errors++;
}
}
var valid123 = _errs694 === errors;
}
else {
var valid123 = true;
}
if(valid123){
if(data243.basis !== undefined){
let data253 = data243.basis;
const _errs696 = errors;
if(errors === _errs696){
if(data253 && typeof data253 == "object" && !Array.isArray(data253)){
let missing85;
if((((((data253.kind === undefined) && (missing85 = "kind")) || ((data253.resource === undefined) && (missing85 = "resource"))) || ((data253.revision === undefined) && (missing85 = "revision"))) || ((data253.contract === undefined) && (missing85 = "contract"))) || ((data253.schema === undefined) && (missing85 = "schema"))){
const err729 = {instancePath:instancePath+"/page/evidence/manifest/basis",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/required",keyword:"required",params:{missingProperty: missing85},message:"must have required property '"+missing85+"'"};
if(vErrors === null){
vErrors = [err729];
}
else {
vErrors.push(err729);
}
errors++;
}
else {
const _errs698 = errors;
for(const key85 in data253){
if(!(((((key85 === "kind") || (key85 === "resource")) || (key85 === "revision")) || (key85 === "contract")) || (key85 === "schema"))){
const err730 = {instancePath:instancePath+"/page/evidence/manifest/basis",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key85},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err730];
}
else {
vErrors.push(err730);
}
errors++;
break;
}
}
if(_errs698 === errors){
if(data253.kind !== undefined){
let data254 = data253.kind;
const _errs699 = errors;
if(typeof data254 !== "string"){
const err731 = {instancePath:instancePath+"/page/evidence/manifest/basis/kind",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err731];
}
else {
vErrors.push(err731);
}
errors++;
}
if(!(((data254 === "kv") || (data254 === "table")) || (data254 === "document"))){
const err732 = {instancePath:instancePath+"/page/evidence/manifest/basis/kind",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/kind/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[9].properties.page.properties.evidence.properties.manifest.properties.basis.properties.kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err732];
}
else {
vErrors.push(err732);
}
errors++;
}
var valid125 = _errs699 === errors;
}
else {
var valid125 = true;
}
if(valid125){
if(data253.resource !== undefined){
let data255 = data253.resource;
const _errs701 = errors;
if(!(((typeof data255 == "number") && (!(data255 % 1) && !isNaN(data255))) && (isFinite(data255)))){
const err733 = {instancePath:instancePath+"/page/evidence/manifest/basis/resource",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/resource/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err733];
}
else {
vErrors.push(err733);
}
errors++;
}
if(errors === _errs701){
if((typeof data255 == "number") && (isFinite(data255))){
if(data255 > 9007199254740991 || isNaN(data255)){
const err734 = {instancePath:instancePath+"/page/evidence/manifest/basis/resource",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/resource/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err734];
}
else {
vErrors.push(err734);
}
errors++;
}
else {
if(data255 < 0 || isNaN(data255)){
const err735 = {instancePath:instancePath+"/page/evidence/manifest/basis/resource",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/resource/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err735];
}
else {
vErrors.push(err735);
}
errors++;
}
}
}
}
var valid125 = _errs701 === errors;
}
else {
var valid125 = true;
}
if(valid125){
if(data253.revision !== undefined){
let data256 = data253.revision;
const _errs703 = errors;
if(!(((typeof data256 == "number") && (!(data256 % 1) && !isNaN(data256))) && (isFinite(data256)))){
const err736 = {instancePath:instancePath+"/page/evidence/manifest/basis/revision",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/revision/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err736];
}
else {
vErrors.push(err736);
}
errors++;
}
if(errors === _errs703){
if((typeof data256 == "number") && (isFinite(data256))){
if(data256 > 9007199254740991 || isNaN(data256)){
const err737 = {instancePath:instancePath+"/page/evidence/manifest/basis/revision",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/revision/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err737];
}
else {
vErrors.push(err737);
}
errors++;
}
else {
if(data256 < 0 || isNaN(data256)){
const err738 = {instancePath:instancePath+"/page/evidence/manifest/basis/revision",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/revision/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid125 = _errs703 === errors;
}
else {
var valid125 = true;
}
if(valid125){
if(data253.contract !== undefined){
let data257 = data253.contract;
const _errs705 = errors;
if(errors === _errs705){
if(Array.isArray(data257)){
if(data257.length > 32){
const err739 = {instancePath:instancePath+"/page/evidence/manifest/basis/contract",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/contract/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err739];
}
else {
vErrors.push(err739);
}
errors++;
}
else {
if(data257.length < 32){
const err740 = {instancePath:instancePath+"/page/evidence/manifest/basis/contract",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/contract/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err740];
}
else {
vErrors.push(err740);
}
errors++;
}
else {
var valid126 = true;
const len23 = data257.length;
for(let i23=0; i23<len23; i23++){
let data258 = data257[i23];
const _errs707 = errors;
if(!(((typeof data258 == "number") && (!(data258 % 1) && !isNaN(data258))) && (isFinite(data258)))){
const err741 = {instancePath:instancePath+"/page/evidence/manifest/basis/contract/" + i23,schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/contract/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err741];
}
else {
vErrors.push(err741);
}
errors++;
}
if(errors === _errs707){
if((typeof data258 == "number") && (isFinite(data258))){
if(data258 > 255 || isNaN(data258)){
const err742 = {instancePath:instancePath+"/page/evidence/manifest/basis/contract/" + i23,schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/contract/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err742];
}
else {
vErrors.push(err742);
}
errors++;
}
else {
if(data258 < 0 || isNaN(data258)){
const err743 = {instancePath:instancePath+"/page/evidence/manifest/basis/contract/" + i23,schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/contract/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err743];
}
else {
vErrors.push(err743);
}
errors++;
}
}
}
}
var valid126 = _errs707 === errors;
if(!valid126){
break;
}
}
}
}
}
else {
const err744 = {instancePath:instancePath+"/page/evidence/manifest/basis/contract",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/contract/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err744];
}
else {
vErrors.push(err744);
}
errors++;
}
}
var valid125 = _errs705 === errors;
}
else {
var valid125 = true;
}
if(valid125){
if(data253.schema !== undefined){
let data259 = data253.schema;
const _errs709 = errors;
if(errors === _errs709){
if(Array.isArray(data259)){
if(data259.length > 32){
const err745 = {instancePath:instancePath+"/page/evidence/manifest/basis/schema",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/schema/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err745];
}
else {
vErrors.push(err745);
}
errors++;
}
else {
if(data259.length < 32){
const err746 = {instancePath:instancePath+"/page/evidence/manifest/basis/schema",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/schema/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err746];
}
else {
vErrors.push(err746);
}
errors++;
}
else {
var valid127 = true;
const len24 = data259.length;
for(let i24=0; i24<len24; i24++){
let data260 = data259[i24];
const _errs711 = errors;
if(!(((typeof data260 == "number") && (!(data260 % 1) && !isNaN(data260))) && (isFinite(data260)))){
const err747 = {instancePath:instancePath+"/page/evidence/manifest/basis/schema/" + i24,schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/schema/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err747];
}
else {
vErrors.push(err747);
}
errors++;
}
if(errors === _errs711){
if((typeof data260 == "number") && (isFinite(data260))){
if(data260 > 255 || isNaN(data260)){
const err748 = {instancePath:instancePath+"/page/evidence/manifest/basis/schema/" + i24,schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/schema/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err748];
}
else {
vErrors.push(err748);
}
errors++;
}
else {
if(data260 < 0 || isNaN(data260)){
const err749 = {instancePath:instancePath+"/page/evidence/manifest/basis/schema/" + i24,schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/schema/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err749];
}
else {
vErrors.push(err749);
}
errors++;
}
}
}
}
var valid127 = _errs711 === errors;
if(!valid127){
break;
}
}
}
}
}
else {
const err750 = {instancePath:instancePath+"/page/evidence/manifest/basis/schema",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/schema/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err750];
}
else {
vErrors.push(err750);
}
errors++;
}
}
var valid125 = _errs709 === errors;
}
else {
var valid125 = true;
}
}
}
}
}
}
}
}
else {
const err751 = {instancePath:instancePath+"/page/evidence/manifest/basis",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err751];
}
else {
vErrors.push(err751);
}
errors++;
}
}
var valid123 = _errs696 === errors;
}
else {
var valid123 = true;
}
if(valid123){
if(data243.plan !== undefined){
let data261 = data243.plan;
const _errs713 = errors;
if(errors === _errs713){
if(Array.isArray(data261)){
if(data261.length > 32){
const err752 = {instancePath:instancePath+"/page/evidence/manifest/plan",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/plan/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err752];
}
else {
vErrors.push(err752);
}
errors++;
}
else {
if(data261.length < 32){
const err753 = {instancePath:instancePath+"/page/evidence/manifest/plan",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/plan/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err753];
}
else {
vErrors.push(err753);
}
errors++;
}
else {
var valid128 = true;
const len25 = data261.length;
for(let i25=0; i25<len25; i25++){
let data262 = data261[i25];
const _errs715 = errors;
if(!(((typeof data262 == "number") && (!(data262 % 1) && !isNaN(data262))) && (isFinite(data262)))){
const err754 = {instancePath:instancePath+"/page/evidence/manifest/plan/" + i25,schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/plan/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err754];
}
else {
vErrors.push(err754);
}
errors++;
}
if(errors === _errs715){
if((typeof data262 == "number") && (isFinite(data262))){
if(data262 > 255 || isNaN(data262)){
const err755 = {instancePath:instancePath+"/page/evidence/manifest/plan/" + i25,schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/plan/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err755];
}
else {
vErrors.push(err755);
}
errors++;
}
else {
if(data262 < 0 || isNaN(data262)){
const err756 = {instancePath:instancePath+"/page/evidence/manifest/plan/" + i25,schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/plan/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err756];
}
else {
vErrors.push(err756);
}
errors++;
}
}
}
}
var valid128 = _errs715 === errors;
if(!valid128){
break;
}
}
}
}
}
else {
const err757 = {instancePath:instancePath+"/page/evidence/manifest/plan",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/plan/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err757];
}
else {
vErrors.push(err757);
}
errors++;
}
}
var valid123 = _errs713 === errors;
}
else {
var valid123 = true;
}
if(valid123){
if(data243.pages !== undefined){
let data263 = data243.pages;
const _errs717 = errors;
if(errors === _errs717){
if(typeof data263 === "string"){
if(func1(data263) > 131072){
const err758 = {instancePath:instancePath+"/page/evidence/manifest/pages",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/pages/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err758];
}
else {
vErrors.push(err758);
}
errors++;
}
}
else {
const err759 = {instancePath:instancePath+"/page/evidence/manifest/pages",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/pages/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err759];
}
else {
vErrors.push(err759);
}
errors++;
}
}
var valid123 = _errs717 === errors;
}
else {
var valid123 = true;
}
if(valid123){
if(data243.scanned !== undefined){
let data264 = data243.scanned;
const _errs719 = errors;
if(errors === _errs719){
if(typeof data264 === "string"){
if(func1(data264) > 131072){
const err760 = {instancePath:instancePath+"/page/evidence/manifest/scanned",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/scanned/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err760];
}
else {
vErrors.push(err760);
}
errors++;
}
}
else {
const err761 = {instancePath:instancePath+"/page/evidence/manifest/scanned",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/scanned/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err761];
}
else {
vErrors.push(err761);
}
errors++;
}
}
var valid123 = _errs719 === errors;
}
else {
var valid123 = true;
}
if(valid123){
if(data243.selected !== undefined){
let data265 = data243.selected;
const _errs721 = errors;
if(errors === _errs721){
if(typeof data265 === "string"){
if(func1(data265) > 131072){
const err762 = {instancePath:instancePath+"/page/evidence/manifest/selected",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/selected/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err763 = {instancePath:instancePath+"/page/evidence/manifest/selected",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/selected/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err763];
}
else {
vErrors.push(err763);
}
errors++;
}
}
var valid123 = _errs721 === errors;
}
else {
var valid123 = true;
}
if(valid123){
if(data243.segments !== undefined){
let data266 = data243.segments;
const _errs723 = errors;
if(errors === _errs723){
if(typeof data266 === "string"){
if(func1(data266) > 131072){
const err764 = {instancePath:instancePath+"/page/evidence/manifest/segments",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/segments/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err764];
}
else {
vErrors.push(err764);
}
errors++;
}
}
else {
const err765 = {instancePath:instancePath+"/page/evidence/manifest/segments",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/segments/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err765];
}
else {
vErrors.push(err765);
}
errors++;
}
}
var valid123 = _errs723 === errors;
}
else {
var valid123 = true;
}
if(valid123){
if(data243.rows !== undefined){
let data267 = data243.rows;
const _errs725 = errors;
if(errors === _errs725){
if(typeof data267 === "string"){
if(func1(data267) > 131072){
const err766 = {instancePath:instancePath+"/page/evidence/manifest/rows",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/rows/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err766];
}
else {
vErrors.push(err766);
}
errors++;
}
}
else {
const err767 = {instancePath:instancePath+"/page/evidence/manifest/rows",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/rows/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err767];
}
else {
vErrors.push(err767);
}
errors++;
}
}
var valid123 = _errs725 === errors;
}
else {
var valid123 = true;
}
if(valid123){
if(data243.bytes !== undefined){
let data268 = data243.bytes;
const _errs727 = errors;
if(errors === _errs727){
if(typeof data268 === "string"){
if(func1(data268) > 131072){
const err768 = {instancePath:instancePath+"/page/evidence/manifest/bytes",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/bytes/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err768];
}
else {
vErrors.push(err768);
}
errors++;
}
}
else {
const err769 = {instancePath:instancePath+"/page/evidence/manifest/bytes",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/bytes/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err769];
}
else {
vErrors.push(err769);
}
errors++;
}
}
var valid123 = _errs727 === errors;
}
else {
var valid123 = true;
}
if(valid123){
if(data243.sum !== undefined){
let data269 = data243.sum;
const _errs729 = errors;
const _errs730 = errors;
let valid129 = false;
const _errs731 = errors;
if(errors === _errs731){
if(typeof data269 === "string"){
if(func1(data269) > 131072){
const err770 = {instancePath:instancePath+"/page/evidence/manifest/sum",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/sum/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err770];
}
else {
vErrors.push(err770);
}
errors++;
}
}
else {
const err771 = {instancePath:instancePath+"/page/evidence/manifest/sum",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/sum/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err771];
}
else {
vErrors.push(err771);
}
errors++;
}
}
var _valid17 = _errs731 === errors;
valid129 = valid129 || _valid17;
const _errs733 = errors;
if(data269 !== null){
const err772 = {instancePath:instancePath+"/page/evidence/manifest/sum",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/sum/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err772];
}
else {
vErrors.push(err772);
}
errors++;
}
var _valid17 = _errs733 === errors;
valid129 = valid129 || _valid17;
if(!valid129){
const err773 = {instancePath:instancePath+"/page/evidence/manifest/sum",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/sum/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err773];
}
else {
vErrors.push(err773);
}
errors++;
}
else {
errors = _errs730;
if(vErrors !== null){
if(_errs730){
vErrors.length = _errs730;
}
else {
vErrors = null;
}
}
}
var valid123 = _errs729 === errors;
}
else {
var valid123 = true;
}
if(valid123){
if(data243.finished !== undefined){
let data270 = data243.finished;
const _errs735 = errors;
const _errs736 = errors;
let valid130 = false;
const _errs737 = errors;
if(typeof data270 !== "string"){
const err774 = {instancePath:instancePath+"/page/evidence/manifest/finished",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/finished/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err774];
}
else {
vErrors.push(err774);
}
errors++;
}
if(!((data270 === "source_end") || (data270 === "limit"))){
const err775 = {instancePath:instancePath+"/page/evidence/manifest/finished",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/finished/anyOf/0/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[9].properties.page.properties.evidence.properties.manifest.properties.finished.anyOf[0].enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err775];
}
else {
vErrors.push(err775);
}
errors++;
}
var _valid18 = _errs737 === errors;
valid130 = valid130 || _valid18;
const _errs739 = errors;
if(data270 !== null){
const err776 = {instancePath:instancePath+"/page/evidence/manifest/finished",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/finished/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err776];
}
else {
vErrors.push(err776);
}
errors++;
}
var _valid18 = _errs739 === errors;
valid130 = valid130 || _valid18;
if(!valid130){
const err777 = {instancePath:instancePath+"/page/evidence/manifest/finished",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/finished/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err777];
}
else {
vErrors.push(err777);
}
errors++;
}
else {
errors = _errs736;
if(vErrors !== null){
if(_errs736){
vErrors.length = _errs736;
}
else {
vErrors = null;
}
}
}
var valid123 = _errs735 === errors;
}
else {
var valid123 = true;
}
if(valid123){
if(data243.chain !== undefined){
let data271 = data243.chain;
const _errs741 = errors;
if(errors === _errs741){
if(Array.isArray(data271)){
if(data271.length > 32){
const err778 = {instancePath:instancePath+"/page/evidence/manifest/chain",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/chain/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err778];
}
else {
vErrors.push(err778);
}
errors++;
}
else {
if(data271.length < 32){
const err779 = {instancePath:instancePath+"/page/evidence/manifest/chain",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/chain/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err779];
}
else {
vErrors.push(err779);
}
errors++;
}
else {
var valid131 = true;
const len26 = data271.length;
for(let i26=0; i26<len26; i26++){
let data272 = data271[i26];
const _errs743 = errors;
if(!(((typeof data272 == "number") && (!(data272 % 1) && !isNaN(data272))) && (isFinite(data272)))){
const err780 = {instancePath:instancePath+"/page/evidence/manifest/chain/" + i26,schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/chain/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err780];
}
else {
vErrors.push(err780);
}
errors++;
}
if(errors === _errs743){
if((typeof data272 == "number") && (isFinite(data272))){
if(data272 > 255 || isNaN(data272)){
const err781 = {instancePath:instancePath+"/page/evidence/manifest/chain/" + i26,schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/chain/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err781];
}
else {
vErrors.push(err781);
}
errors++;
}
else {
if(data272 < 0 || isNaN(data272)){
const err782 = {instancePath:instancePath+"/page/evidence/manifest/chain/" + i26,schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/chain/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err782];
}
else {
vErrors.push(err782);
}
errors++;
}
}
}
}
var valid131 = _errs743 === errors;
if(!valid131){
break;
}
}
}
}
}
else {
const err783 = {instancePath:instancePath+"/page/evidence/manifest/chain",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/chain/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err783];
}
else {
vErrors.push(err783);
}
errors++;
}
}
var valid123 = _errs741 === errors;
}
else {
var valid123 = true;
}
}
}
}
}
}
}
}
}
}
}
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
const err784 = {instancePath:instancePath+"/page/evidence/manifest",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err784];
}
else {
vErrors.push(err784);
}
errors++;
}
}
var valid122 = _errs674 === errors;
}
else {
var valid122 = true;
}
if(valid122){
if(data242.columns !== undefined){
let data273 = data242.columns;
const _errs745 = errors;
if(errors === _errs745){
if(Array.isArray(data273)){
if(data273.length > 8){
const err785 = {instancePath:instancePath+"/page/evidence/columns",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/columns/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err785];
}
else {
vErrors.push(err785);
}
errors++;
}
else {
var valid132 = true;
const len27 = data273.length;
for(let i27=0; i27<len27; i27++){
let data274 = data273[i27];
const _errs747 = errors;
if(errors === _errs747){
if(data274 && typeof data274 == "object" && !Array.isArray(data274)){
let missing86;
if(((data274.name === undefined) && (missing86 = "name")) || ((data274.type === undefined) && (missing86 = "type"))){
const err786 = {instancePath:instancePath+"/page/evidence/columns/" + i27,schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/columns/items/required",keyword:"required",params:{missingProperty: missing86},message:"must have required property '"+missing86+"'"};
if(vErrors === null){
vErrors = [err786];
}
else {
vErrors.push(err786);
}
errors++;
}
else {
const _errs749 = errors;
for(const key86 in data274){
if(!((key86 === "name") || (key86 === "type"))){
const err787 = {instancePath:instancePath+"/page/evidence/columns/" + i27,schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/columns/items/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key86},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err787];
}
else {
vErrors.push(err787);
}
errors++;
break;
}
}
if(_errs749 === errors){
if(data274.name !== undefined){
let data275 = data274.name;
const _errs750 = errors;
if(errors === _errs750){
if(typeof data275 === "string"){
if(func1(data275) > 131072){
const err788 = {instancePath:instancePath+"/page/evidence/columns/" + i27+"/name",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/columns/items/properties/name/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err788];
}
else {
vErrors.push(err788);
}
errors++;
}
}
else {
const err789 = {instancePath:instancePath+"/page/evidence/columns/" + i27+"/name",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/columns/items/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err789];
}
else {
vErrors.push(err789);
}
errors++;
}
}
var valid133 = _errs750 === errors;
}
else {
var valid133 = true;
}
if(valid133){
if(data274.type !== undefined){
let data276 = data274.type;
const _errs752 = errors;
if(typeof data276 !== "string"){
const err790 = {instancePath:instancePath+"/page/evidence/columns/" + i27+"/type",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/columns/items/properties/type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err790];
}
else {
vErrors.push(err790);
}
errors++;
}
if(!((((((data276 === "int64") || (data276 === "uint64")) || (data276 === "float64")) || (data276 === "boolean")) || (data276 === "utf8")) || (data276 === "binary"))){
const err791 = {instancePath:instancePath+"/page/evidence/columns/" + i27+"/type",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/columns/items/properties/type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[9].properties.page.properties.evidence.properties.columns.items.properties.type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err791];
}
else {
vErrors.push(err791);
}
errors++;
}
var valid133 = _errs752 === errors;
}
else {
var valid133 = true;
}
}
}
}
}
else {
const err792 = {instancePath:instancePath+"/page/evidence/columns/" + i27,schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/columns/items/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err792];
}
else {
vErrors.push(err792);
}
errors++;
}
}
var valid132 = _errs747 === errors;
if(!valid132){
break;
}
}
}
}
else {
const err793 = {instancePath:instancePath+"/page/evidence/columns",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/columns/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err793];
}
else {
vErrors.push(err793);
}
errors++;
}
}
var valid122 = _errs745 === errors;
}
else {
var valid122 = true;
}
if(valid122){
if(data242.ordinal !== undefined){
let data277 = data242.ordinal;
const _errs754 = errors;
if(errors === _errs754){
if(typeof data277 === "string"){
if(func1(data277) > 131072){
const err794 = {instancePath:instancePath+"/page/evidence/ordinal",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/ordinal/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err794];
}
else {
vErrors.push(err794);
}
errors++;
}
}
else {
const err795 = {instancePath:instancePath+"/page/evidence/ordinal",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/ordinal/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err795];
}
else {
vErrors.push(err795);
}
errors++;
}
}
var valid122 = _errs754 === errors;
}
else {
var valid122 = true;
}
if(valid122){
if(data242.rows !== undefined){
let data278 = data242.rows;
const _errs756 = errors;
if(!(((typeof data278 == "number") && (!(data278 % 1) && !isNaN(data278))) && (isFinite(data278)))){
const err796 = {instancePath:instancePath+"/page/evidence/rows",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/rows/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err796];
}
else {
vErrors.push(err796);
}
errors++;
}
if(errors === _errs756){
if((typeof data278 == "number") && (isFinite(data278))){
if(data278 > 255 || isNaN(data278)){
const err797 = {instancePath:instancePath+"/page/evidence/rows",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/rows/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err797];
}
else {
vErrors.push(err797);
}
errors++;
}
else {
if(data278 < 0 || isNaN(data278)){
const err798 = {instancePath:instancePath+"/page/evidence/rows",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/rows/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err798];
}
else {
vErrors.push(err798);
}
errors++;
}
}
}
}
var valid122 = _errs756 === errors;
}
else {
var valid122 = true;
}
if(valid122){
if(data242.ipc !== undefined){
let data279 = data242.ipc;
const _errs758 = errors;
if(errors === _errs758){
if(typeof data279 === "string"){
if(func1(data279) > 131072){
const err799 = {instancePath:instancePath+"/page/evidence/ipc",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/ipc/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err799];
}
else {
vErrors.push(err799);
}
errors++;
}
}
else {
const err800 = {instancePath:instancePath+"/page/evidence/ipc",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/ipc/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err800];
}
else {
vErrors.push(err800);
}
errors++;
}
}
var valid122 = _errs758 === errors;
}
else {
var valid122 = true;
}
if(valid122){
if(data242.next !== undefined){
let data280 = data242.next;
const _errs760 = errors;
const _errs761 = errors;
let valid134 = false;
const _errs762 = errors;
if(errors === _errs762){
if(typeof data280 === "string"){
if(func1(data280) > 131072){
const err801 = {instancePath:instancePath+"/page/evidence/next",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/next/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err801];
}
else {
vErrors.push(err801);
}
errors++;
}
}
else {
const err802 = {instancePath:instancePath+"/page/evidence/next",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/next/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err802];
}
else {
vErrors.push(err802);
}
errors++;
}
}
var _valid19 = _errs762 === errors;
valid134 = valid134 || _valid19;
const _errs764 = errors;
if(data280 !== null){
const err803 = {instancePath:instancePath+"/page/evidence/next",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/next/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err803];
}
else {
vErrors.push(err803);
}
errors++;
}
var _valid19 = _errs764 === errors;
valid134 = valid134 || _valid19;
if(!valid134){
const err804 = {instancePath:instancePath+"/page/evidence/next",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/next/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err804];
}
else {
vErrors.push(err804);
}
errors++;
}
else {
errors = _errs761;
if(vErrors !== null){
if(_errs761){
vErrors.length = _errs761;
}
else {
vErrors = null;
}
}
}
var valid122 = _errs760 === errors;
}
else {
var valid122 = true;
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
const err805 = {instancePath:instancePath+"/page/evidence",schemaPath:"#/oneOf/9/properties/page/properties/evidence/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err805];
}
else {
vErrors.push(err805);
}
errors++;
}
}
var valid121 = _errs671 === errors;
}
else {
var valid121 = true;
}
if(valid121){
if(data241.cells !== undefined){
let data281 = data241.cells;
const _errs766 = errors;
if(errors === _errs766){
if(Array.isArray(data281)){
if(data281.length > 8){
const err806 = {instancePath:instancePath+"/page/cells",schemaPath:"#/oneOf/9/properties/page/properties/cells/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err806];
}
else {
vErrors.push(err806);
}
errors++;
}
else {
var valid135 = true;
const len28 = data281.length;
for(let i28=0; i28<len28; i28++){
let data282 = data281[i28];
const _errs768 = errors;
if(errors === _errs768){
if(Array.isArray(data282)){
if(data282.length > 8){
const err807 = {instancePath:instancePath+"/page/cells/" + i28,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err807];
}
else {
vErrors.push(err807);
}
errors++;
}
else {
var valid136 = true;
const len29 = data282.length;
for(let i29=0; i29<len29; i29++){
let data283 = data282[i29];
const _errs770 = errors;
const _errs771 = errors;
let valid137 = false;
let passing8 = null;
const _errs772 = errors;
if(errors === _errs772){
if(data283 && typeof data283 == "object" && !Array.isArray(data283)){
let missing87;
if((data283.missing === undefined) && (missing87 = "missing")){
const err808 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/0/required",keyword:"required",params:{missingProperty: missing87},message:"must have required property '"+missing87+"'"};
if(vErrors === null){
vErrors = [err808];
}
else {
vErrors.push(err808);
}
errors++;
}
else {
const _errs774 = errors;
for(const key87 in data283){
if(!(key87 === "missing")){
const err809 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key87},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err809];
}
else {
vErrors.push(err809);
}
errors++;
break;
}
}
if(_errs774 === errors){
if(data283.missing !== undefined){
let data284 = data283.missing;
const _errs775 = errors;
if(errors === _errs775){
if(data284 && typeof data284 == "object" && !Array.isArray(data284)){
if(Object.keys(data284).length > 0){
const err810 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/missing",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/0/properties/missing/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err810];
}
else {
vErrors.push(err810);
}
errors++;
}
}
else {
const err811 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/missing",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/0/properties/missing/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err812 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err812];
}
else {
vErrors.push(err812);
}
errors++;
}
}
var _valid20 = _errs772 === errors;
if(_valid20){
valid137 = true;
passing8 = 0;
var props11 = true;
}
const _errs777 = errors;
if(errors === _errs777){
if(data283 && typeof data283 == "object" && !Array.isArray(data283)){
let missing88;
if((data283.null === undefined) && (missing88 = "null")){
const err813 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/1/required",keyword:"required",params:{missingProperty: missing88},message:"must have required property '"+missing88+"'"};
if(vErrors === null){
vErrors = [err813];
}
else {
vErrors.push(err813);
}
errors++;
}
else {
const _errs779 = errors;
for(const key88 in data283){
if(!(key88 === "null")){
const err814 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key88},message:"must NOT have additional properties"};
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
if(_errs779 === errors){
if(data283.null !== undefined){
let data285 = data283.null;
const _errs780 = errors;
if(errors === _errs780){
if(data285 && typeof data285 == "object" && !Array.isArray(data285)){
if(Object.keys(data285).length > 0){
const err815 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/null",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/1/properties/null/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err815];
}
else {
vErrors.push(err815);
}
errors++;
}
}
else {
const err816 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/null",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/1/properties/null/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err816];
}
else {
vErrors.push(err816);
}
errors++;
}
}
}
}
}
}
else {
const err817 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err817];
}
else {
vErrors.push(err817);
}
errors++;
}
}
var _valid20 = _errs777 === errors;
if(_valid20 && valid137){
valid137 = false;
passing8 = [passing8, 1];
}
else {
if(_valid20){
valid137 = true;
passing8 = 1;
if(props11 !== true){
props11 = true;
}
}
const _errs782 = errors;
if(errors === _errs782){
if(data283 && typeof data283 == "object" && !Array.isArray(data283)){
let missing89;
if((data283.type_error === undefined) && (missing89 = "type_error")){
const err818 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/2/required",keyword:"required",params:{missingProperty: missing89},message:"must have required property '"+missing89+"'"};
if(vErrors === null){
vErrors = [err818];
}
else {
vErrors.push(err818);
}
errors++;
}
else {
const _errs784 = errors;
for(const key89 in data283){
if(!(key89 === "type_error")){
const err819 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key89},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err819];
}
else {
vErrors.push(err819);
}
errors++;
break;
}
}
if(_errs784 === errors){
if(data283.type_error !== undefined){
let data286 = data283.type_error;
if(typeof data286 !== "string"){
const err820 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/type_error",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/2/properties/type_error/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err820];
}
else {
vErrors.push(err820);
}
errors++;
}
if(!((((((((((((data286 === "unknown") || (data286 === "int64")) || (data286 === "uint64")) || (data286 === "float64")) || (data286 === "boolean")) || (data286 === "utf8")) || (data286 === "binary")) || (data286 === "null_value")) || (data286 === "map")) || (data286 === "list")) || (data286 === "text")) || (data286 === "character"))){
const err821 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/type_error",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/2/properties/type_error/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[9].properties.page.properties.cells.items.items.oneOf[2].properties.type_error.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err821];
}
else {
vErrors.push(err821);
}
errors++;
}
}
}
}
}
else {
const err822 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err822];
}
else {
vErrors.push(err822);
}
errors++;
}
}
var _valid20 = _errs782 === errors;
if(_valid20 && valid137){
valid137 = false;
passing8 = [passing8, 2];
}
else {
if(_valid20){
valid137 = true;
passing8 = 2;
if(props11 !== true){
props11 = true;
}
}
const _errs787 = errors;
if(errors === _errs787){
if(data283 && typeof data283 == "object" && !Array.isArray(data283)){
let missing90;
if((data283.value === undefined) && (missing90 = "value")){
const err823 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/required",keyword:"required",params:{missingProperty: missing90},message:"must have required property '"+missing90+"'"};
if(vErrors === null){
vErrors = [err823];
}
else {
vErrors.push(err823);
}
errors++;
}
else {
const _errs789 = errors;
for(const key90 in data283){
if(!(key90 === "value")){
const err824 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key90},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err824];
}
else {
vErrors.push(err824);
}
errors++;
break;
}
}
if(_errs789 === errors){
if(data283.value !== undefined){
let data287 = data283.value;
const _errs791 = errors;
let valid142 = false;
let passing9 = null;
const _errs792 = errors;
if(errors === _errs792){
if(data287 && typeof data287 == "object" && !Array.isArray(data287)){
let missing91;
if((data287.int64 === undefined) && (missing91 = "int64")){
const err825 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/0/required",keyword:"required",params:{missingProperty: missing91},message:"must have required property '"+missing91+"'"};
if(vErrors === null){
vErrors = [err825];
}
else {
vErrors.push(err825);
}
errors++;
}
else {
const _errs794 = errors;
for(const key91 in data287){
if(!(key91 === "int64")){
const err826 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key91},message:"must NOT have additional properties"};
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
if(_errs794 === errors){
if(data287.int64 !== undefined){
let data288 = data287.int64;
const _errs795 = errors;
if(errors === _errs795){
if(typeof data288 === "string"){
if(func1(data288) > 131072){
const err827 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/value/int64",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/0/properties/int64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err827];
}
else {
vErrors.push(err827);
}
errors++;
}
}
else {
const err828 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/value/int64",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/0/properties/int64/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
}
}
}
else {
const err829 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err829];
}
else {
vErrors.push(err829);
}
errors++;
}
}
var _valid21 = _errs792 === errors;
if(_valid21){
valid142 = true;
passing9 = 0;
var props12 = true;
}
const _errs797 = errors;
if(errors === _errs797){
if(data287 && typeof data287 == "object" && !Array.isArray(data287)){
let missing92;
if((data287.uint64 === undefined) && (missing92 = "uint64")){
const err830 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/1/required",keyword:"required",params:{missingProperty: missing92},message:"must have required property '"+missing92+"'"};
if(vErrors === null){
vErrors = [err830];
}
else {
vErrors.push(err830);
}
errors++;
}
else {
const _errs799 = errors;
for(const key92 in data287){
if(!(key92 === "uint64")){
const err831 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key92},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err831];
}
else {
vErrors.push(err831);
}
errors++;
break;
}
}
if(_errs799 === errors){
if(data287.uint64 !== undefined){
let data289 = data287.uint64;
const _errs800 = errors;
if(errors === _errs800){
if(typeof data289 === "string"){
if(func1(data289) > 131072){
const err832 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/value/uint64",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/1/properties/uint64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err832];
}
else {
vErrors.push(err832);
}
errors++;
}
}
else {
const err833 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/value/uint64",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/1/properties/uint64/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err833];
}
else {
vErrors.push(err833);
}
errors++;
}
}
}
}
}
}
else {
const err834 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err834];
}
else {
vErrors.push(err834);
}
errors++;
}
}
var _valid21 = _errs797 === errors;
if(_valid21 && valid142){
valid142 = false;
passing9 = [passing9, 1];
}
else {
if(_valid21){
valid142 = true;
passing9 = 1;
if(props12 !== true){
props12 = true;
}
}
const _errs802 = errors;
if(errors === _errs802){
if(data287 && typeof data287 == "object" && !Array.isArray(data287)){
let missing93;
if((data287.float_bits === undefined) && (missing93 = "float_bits")){
const err835 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/2/required",keyword:"required",params:{missingProperty: missing93},message:"must have required property '"+missing93+"'"};
if(vErrors === null){
vErrors = [err835];
}
else {
vErrors.push(err835);
}
errors++;
}
else {
const _errs804 = errors;
for(const key93 in data287){
if(!(key93 === "float_bits")){
const err836 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key93},message:"must NOT have additional properties"};
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
if(_errs804 === errors){
if(data287.float_bits !== undefined){
let data290 = data287.float_bits;
const _errs805 = errors;
if(errors === _errs805){
if(typeof data290 === "string"){
if(func1(data290) > 131072){
const err837 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/value/float_bits",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/2/properties/float_bits/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err837];
}
else {
vErrors.push(err837);
}
errors++;
}
}
else {
const err838 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/value/float_bits",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/2/properties/float_bits/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
}
}
}
else {
const err839 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err839];
}
else {
vErrors.push(err839);
}
errors++;
}
}
var _valid21 = _errs802 === errors;
if(_valid21 && valid142){
valid142 = false;
passing9 = [passing9, 2];
}
else {
if(_valid21){
valid142 = true;
passing9 = 2;
if(props12 !== true){
props12 = true;
}
}
const _errs807 = errors;
if(errors === _errs807){
if(data287 && typeof data287 == "object" && !Array.isArray(data287)){
let missing94;
if((data287.boolean === undefined) && (missing94 = "boolean")){
const err840 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/3/required",keyword:"required",params:{missingProperty: missing94},message:"must have required property '"+missing94+"'"};
if(vErrors === null){
vErrors = [err840];
}
else {
vErrors.push(err840);
}
errors++;
}
else {
const _errs809 = errors;
for(const key94 in data287){
if(!(key94 === "boolean")){
const err841 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key94},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err841];
}
else {
vErrors.push(err841);
}
errors++;
break;
}
}
if(_errs809 === errors){
if(data287.boolean !== undefined){
if(typeof data287.boolean !== "boolean"){
const err842 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/value/boolean",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/3/properties/boolean/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err842];
}
else {
vErrors.push(err842);
}
errors++;
}
}
}
}
}
else {
const err843 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err843];
}
else {
vErrors.push(err843);
}
errors++;
}
}
var _valid21 = _errs807 === errors;
if(_valid21 && valid142){
valid142 = false;
passing9 = [passing9, 3];
}
else {
if(_valid21){
valid142 = true;
passing9 = 3;
if(props12 !== true){
props12 = true;
}
}
const _errs812 = errors;
if(errors === _errs812){
if(data287 && typeof data287 == "object" && !Array.isArray(data287)){
let missing95;
if((data287.utf8 === undefined) && (missing95 = "utf8")){
const err844 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/4/required",keyword:"required",params:{missingProperty: missing95},message:"must have required property '"+missing95+"'"};
if(vErrors === null){
vErrors = [err844];
}
else {
vErrors.push(err844);
}
errors++;
}
else {
const _errs814 = errors;
for(const key95 in data287){
if(!(key95 === "utf8")){
const err845 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key95},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err845];
}
else {
vErrors.push(err845);
}
errors++;
break;
}
}
if(_errs814 === errors){
if(data287.utf8 !== undefined){
let data292 = data287.utf8;
const _errs815 = errors;
if(errors === _errs815){
if(typeof data292 === "string"){
if(func1(data292) > 131072){
const err846 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/value/utf8",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/4/properties/utf8/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err846];
}
else {
vErrors.push(err846);
}
errors++;
}
}
else {
const err847 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/value/utf8",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/4/properties/utf8/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err847];
}
else {
vErrors.push(err847);
}
errors++;
}
}
}
}
}
}
else {
const err848 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err848];
}
else {
vErrors.push(err848);
}
errors++;
}
}
var _valid21 = _errs812 === errors;
if(_valid21 && valid142){
valid142 = false;
passing9 = [passing9, 4];
}
else {
if(_valid21){
valid142 = true;
passing9 = 4;
if(props12 !== true){
props12 = true;
}
}
const _errs817 = errors;
if(errors === _errs817){
if(data287 && typeof data287 == "object" && !Array.isArray(data287)){
let missing96;
if((data287.binary === undefined) && (missing96 = "binary")){
const err849 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/5/required",keyword:"required",params:{missingProperty: missing96},message:"must have required property '"+missing96+"'"};
if(vErrors === null){
vErrors = [err849];
}
else {
vErrors.push(err849);
}
errors++;
}
else {
const _errs819 = errors;
for(const key96 in data287){
if(!(key96 === "binary")){
const err850 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key96},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err850];
}
else {
vErrors.push(err850);
}
errors++;
break;
}
}
if(_errs819 === errors){
if(data287.binary !== undefined){
let data293 = data287.binary;
const _errs820 = errors;
if(errors === _errs820){
if(typeof data293 === "string"){
if(func1(data293) > 131072){
const err851 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/value/binary",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/5/properties/binary/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err851];
}
else {
vErrors.push(err851);
}
errors++;
}
}
else {
const err852 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/value/binary",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/5/properties/binary/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err852];
}
else {
vErrors.push(err852);
}
errors++;
}
}
}
}
}
}
else {
const err853 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err853];
}
else {
vErrors.push(err853);
}
errors++;
}
}
var _valid21 = _errs817 === errors;
if(_valid21 && valid142){
valid142 = false;
passing9 = [passing9, 5];
}
else {
if(_valid21){
valid142 = true;
passing9 = 5;
if(props12 !== true){
props12 = true;
}
}
}
}
}
}
}
if(!valid142){
const err854 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf",keyword:"oneOf",params:{passingSchemas: passing9},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err854];
}
else {
vErrors.push(err854);
}
errors++;
}
else {
errors = _errs791;
if(vErrors !== null){
if(_errs791){
vErrors.length = _errs791;
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
const err855 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err855];
}
else {
vErrors.push(err855);
}
errors++;
}
}
var _valid20 = _errs787 === errors;
if(_valid20 && valid137){
valid137 = false;
passing8 = [passing8, 3];
}
else {
if(_valid20){
valid137 = true;
passing8 = 3;
if(props11 !== true){
props11 = true;
}
}
const _errs822 = errors;
if(errors === _errs822){
if(data283 && typeof data283 == "object" && !Array.isArray(data283)){
let missing97;
if((data283.conflict === undefined) && (missing97 = "conflict")){
const err856 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/required",keyword:"required",params:{missingProperty: missing97},message:"must have required property '"+missing97+"'"};
if(vErrors === null){
vErrors = [err856];
}
else {
vErrors.push(err856);
}
errors++;
}
else {
const _errs824 = errors;
for(const key97 in data283){
if(!(key97 === "conflict")){
const err857 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key97},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err857];
}
else {
vErrors.push(err857);
}
errors++;
break;
}
}
if(_errs824 === errors){
if(data283.conflict !== undefined){
let data294 = data283.conflict;
const _errs825 = errors;
if(errors === _errs825){
if(Array.isArray(data294)){
if(data294.length > 8){
const err858 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err858];
}
else {
vErrors.push(err858);
}
errors++;
}
else {
var valid150 = true;
const len30 = data294.length;
for(let i30=0; i30<len30; i30++){
let data295 = data294[i30];
const _errs827 = errors;
if(errors === _errs827){
if(data295 && typeof data295 == "object" && !Array.isArray(data295)){
let missing98;
if((((data295.counter === undefined) && (missing98 = "counter")) || ((data295.replica === undefined) && (missing98 = "replica"))) || ((data295.value === undefined) && (missing98 = "value"))){
const err859 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/required",keyword:"required",params:{missingProperty: missing98},message:"must have required property '"+missing98+"'"};
if(vErrors === null){
vErrors = [err859];
}
else {
vErrors.push(err859);
}
errors++;
}
else {
const _errs829 = errors;
for(const key98 in data295){
if(!(((key98 === "counter") || (key98 === "replica")) || (key98 === "value"))){
const err860 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key98},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err860];
}
else {
vErrors.push(err860);
}
errors++;
break;
}
}
if(_errs829 === errors){
if(data295.counter !== undefined){
let data296 = data295.counter;
const _errs830 = errors;
if(errors === _errs830){
if(typeof data296 === "string"){
if(func1(data296) > 131072){
const err861 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/counter",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/counter/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err861];
}
else {
vErrors.push(err861);
}
errors++;
}
}
else {
const err862 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/counter",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/counter/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err862];
}
else {
vErrors.push(err862);
}
errors++;
}
}
var valid151 = _errs830 === errors;
}
else {
var valid151 = true;
}
if(valid151){
if(data295.replica !== undefined){
let data297 = data295.replica;
const _errs832 = errors;
if(errors === _errs832){
if(typeof data297 === "string"){
if(func1(data297) > 131072){
const err863 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/replica",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/replica/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err863];
}
else {
vErrors.push(err863);
}
errors++;
}
}
else {
const err864 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/replica",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/replica/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err864];
}
else {
vErrors.push(err864);
}
errors++;
}
}
var valid151 = _errs832 === errors;
}
else {
var valid151 = true;
}
if(valid151){
if(data295.value !== undefined){
let data298 = data295.value;
const _errs834 = errors;
const _errs835 = errors;
let valid152 = false;
let passing10 = null;
const _errs836 = errors;
if(errors === _errs836){
if(data298 && typeof data298 == "object" && !Array.isArray(data298)){
let missing99;
if((data298.null === undefined) && (missing99 = "null")){
const err865 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/0/required",keyword:"required",params:{missingProperty: missing99},message:"must have required property '"+missing99+"'"};
if(vErrors === null){
vErrors = [err865];
}
else {
vErrors.push(err865);
}
errors++;
}
else {
const _errs838 = errors;
for(const key99 in data298){
if(!(key99 === "null")){
const err866 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key99},message:"must NOT have additional properties"};
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
if(_errs838 === errors){
if(data298.null !== undefined){
let data299 = data298.null;
const _errs839 = errors;
if(errors === _errs839){
if(data299 && typeof data299 == "object" && !Array.isArray(data299)){
if(Object.keys(data299).length > 0){
const err867 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/null",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/0/properties/null/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err867];
}
else {
vErrors.push(err867);
}
errors++;
}
}
else {
const err868 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/null",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/0/properties/null/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err868];
}
else {
vErrors.push(err868);
}
errors++;
}
}
}
}
}
}
else {
const err869 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err869];
}
else {
vErrors.push(err869);
}
errors++;
}
}
var _valid22 = _errs836 === errors;
if(_valid22){
valid152 = true;
passing10 = 0;
var props13 = true;
}
const _errs841 = errors;
if(errors === _errs841){
if(data298 && typeof data298 == "object" && !Array.isArray(data298)){
let missing100;
if((data298.type_error === undefined) && (missing100 = "type_error")){
const err870 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/1/required",keyword:"required",params:{missingProperty: missing100},message:"must have required property '"+missing100+"'"};
if(vErrors === null){
vErrors = [err870];
}
else {
vErrors.push(err870);
}
errors++;
}
else {
const _errs843 = errors;
for(const key100 in data298){
if(!(key100 === "type_error")){
const err871 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key100},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err871];
}
else {
vErrors.push(err871);
}
errors++;
break;
}
}
if(_errs843 === errors){
if(data298.type_error !== undefined){
let data300 = data298.type_error;
if(typeof data300 !== "string"){
const err872 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/type_error",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/1/properties/type_error/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err872];
}
else {
vErrors.push(err872);
}
errors++;
}
if(!((((((((((((data300 === "unknown") || (data300 === "int64")) || (data300 === "uint64")) || (data300 === "float64")) || (data300 === "boolean")) || (data300 === "utf8")) || (data300 === "binary")) || (data300 === "null_value")) || (data300 === "map")) || (data300 === "list")) || (data300 === "text")) || (data300 === "character"))){
const err873 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/type_error",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/1/properties/type_error/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[9].properties.page.properties.cells.items.items.oneOf[4].properties.conflict.items.properties.value.oneOf[1].properties.type_error.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err873];
}
else {
vErrors.push(err873);
}
errors++;
}
}
}
}
}
else {
const err874 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err874];
}
else {
vErrors.push(err874);
}
errors++;
}
}
var _valid22 = _errs841 === errors;
if(_valid22 && valid152){
valid152 = false;
passing10 = [passing10, 1];
}
else {
if(_valid22){
valid152 = true;
passing10 = 1;
if(props13 !== true){
props13 = true;
}
}
const _errs846 = errors;
if(errors === _errs846){
if(data298 && typeof data298 == "object" && !Array.isArray(data298)){
let missing101;
if((data298.value === undefined) && (missing101 = "value")){
const err875 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/required",keyword:"required",params:{missingProperty: missing101},message:"must have required property '"+missing101+"'"};
if(vErrors === null){
vErrors = [err875];
}
else {
vErrors.push(err875);
}
errors++;
}
else {
const _errs848 = errors;
for(const key101 in data298){
if(!(key101 === "value")){
const err876 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key101},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err876];
}
else {
vErrors.push(err876);
}
errors++;
break;
}
}
if(_errs848 === errors){
if(data298.value !== undefined){
let data301 = data298.value;
const _errs850 = errors;
let valid156 = false;
let passing11 = null;
const _errs851 = errors;
if(errors === _errs851){
if(data301 && typeof data301 == "object" && !Array.isArray(data301)){
let missing102;
if((data301.int64 === undefined) && (missing102 = "int64")){
const err877 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/0/required",keyword:"required",params:{missingProperty: missing102},message:"must have required property '"+missing102+"'"};
if(vErrors === null){
vErrors = [err877];
}
else {
vErrors.push(err877);
}
errors++;
}
else {
const _errs853 = errors;
for(const key102 in data301){
if(!(key102 === "int64")){
const err878 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key102},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err878];
}
else {
vErrors.push(err878);
}
errors++;
break;
}
}
if(_errs853 === errors){
if(data301.int64 !== undefined){
let data302 = data301.int64;
const _errs854 = errors;
if(errors === _errs854){
if(typeof data302 === "string"){
if(func1(data302) > 131072){
const err879 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/value/int64",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/0/properties/int64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err879];
}
else {
vErrors.push(err879);
}
errors++;
}
}
else {
const err880 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/value/int64",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/0/properties/int64/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err880];
}
else {
vErrors.push(err880);
}
errors++;
}
}
}
}
}
}
else {
const err881 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err881];
}
else {
vErrors.push(err881);
}
errors++;
}
}
var _valid23 = _errs851 === errors;
if(_valid23){
valid156 = true;
passing11 = 0;
var props14 = true;
}
const _errs856 = errors;
if(errors === _errs856){
if(data301 && typeof data301 == "object" && !Array.isArray(data301)){
let missing103;
if((data301.uint64 === undefined) && (missing103 = "uint64")){
const err882 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/1/required",keyword:"required",params:{missingProperty: missing103},message:"must have required property '"+missing103+"'"};
if(vErrors === null){
vErrors = [err882];
}
else {
vErrors.push(err882);
}
errors++;
}
else {
const _errs858 = errors;
for(const key103 in data301){
if(!(key103 === "uint64")){
const err883 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key103},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err883];
}
else {
vErrors.push(err883);
}
errors++;
break;
}
}
if(_errs858 === errors){
if(data301.uint64 !== undefined){
let data303 = data301.uint64;
const _errs859 = errors;
if(errors === _errs859){
if(typeof data303 === "string"){
if(func1(data303) > 131072){
const err884 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/value/uint64",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/1/properties/uint64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err884];
}
else {
vErrors.push(err884);
}
errors++;
}
}
else {
const err885 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/value/uint64",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/1/properties/uint64/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err885];
}
else {
vErrors.push(err885);
}
errors++;
}
}
}
}
}
}
else {
const err886 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err886];
}
else {
vErrors.push(err886);
}
errors++;
}
}
var _valid23 = _errs856 === errors;
if(_valid23 && valid156){
valid156 = false;
passing11 = [passing11, 1];
}
else {
if(_valid23){
valid156 = true;
passing11 = 1;
if(props14 !== true){
props14 = true;
}
}
const _errs861 = errors;
if(errors === _errs861){
if(data301 && typeof data301 == "object" && !Array.isArray(data301)){
let missing104;
if((data301.float_bits === undefined) && (missing104 = "float_bits")){
const err887 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/2/required",keyword:"required",params:{missingProperty: missing104},message:"must have required property '"+missing104+"'"};
if(vErrors === null){
vErrors = [err887];
}
else {
vErrors.push(err887);
}
errors++;
}
else {
const _errs863 = errors;
for(const key104 in data301){
if(!(key104 === "float_bits")){
const err888 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key104},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err888];
}
else {
vErrors.push(err888);
}
errors++;
break;
}
}
if(_errs863 === errors){
if(data301.float_bits !== undefined){
let data304 = data301.float_bits;
const _errs864 = errors;
if(errors === _errs864){
if(typeof data304 === "string"){
if(func1(data304) > 131072){
const err889 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/value/float_bits",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/2/properties/float_bits/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err889];
}
else {
vErrors.push(err889);
}
errors++;
}
}
else {
const err890 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/value/float_bits",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/2/properties/float_bits/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err890];
}
else {
vErrors.push(err890);
}
errors++;
}
}
}
}
}
}
else {
const err891 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err891];
}
else {
vErrors.push(err891);
}
errors++;
}
}
var _valid23 = _errs861 === errors;
if(_valid23 && valid156){
valid156 = false;
passing11 = [passing11, 2];
}
else {
if(_valid23){
valid156 = true;
passing11 = 2;
if(props14 !== true){
props14 = true;
}
}
const _errs866 = errors;
if(errors === _errs866){
if(data301 && typeof data301 == "object" && !Array.isArray(data301)){
let missing105;
if((data301.boolean === undefined) && (missing105 = "boolean")){
const err892 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/3/required",keyword:"required",params:{missingProperty: missing105},message:"must have required property '"+missing105+"'"};
if(vErrors === null){
vErrors = [err892];
}
else {
vErrors.push(err892);
}
errors++;
}
else {
const _errs868 = errors;
for(const key105 in data301){
if(!(key105 === "boolean")){
const err893 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key105},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err893];
}
else {
vErrors.push(err893);
}
errors++;
break;
}
}
if(_errs868 === errors){
if(data301.boolean !== undefined){
if(typeof data301.boolean !== "boolean"){
const err894 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/value/boolean",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/3/properties/boolean/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
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
}
}
else {
const err895 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err895];
}
else {
vErrors.push(err895);
}
errors++;
}
}
var _valid23 = _errs866 === errors;
if(_valid23 && valid156){
valid156 = false;
passing11 = [passing11, 3];
}
else {
if(_valid23){
valid156 = true;
passing11 = 3;
if(props14 !== true){
props14 = true;
}
}
const _errs871 = errors;
if(errors === _errs871){
if(data301 && typeof data301 == "object" && !Array.isArray(data301)){
let missing106;
if((data301.utf8 === undefined) && (missing106 = "utf8")){
const err896 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/4/required",keyword:"required",params:{missingProperty: missing106},message:"must have required property '"+missing106+"'"};
if(vErrors === null){
vErrors = [err896];
}
else {
vErrors.push(err896);
}
errors++;
}
else {
const _errs873 = errors;
for(const key106 in data301){
if(!(key106 === "utf8")){
const err897 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key106},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err897];
}
else {
vErrors.push(err897);
}
errors++;
break;
}
}
if(_errs873 === errors){
if(data301.utf8 !== undefined){
let data306 = data301.utf8;
const _errs874 = errors;
if(errors === _errs874){
if(typeof data306 === "string"){
if(func1(data306) > 131072){
const err898 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/value/utf8",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/4/properties/utf8/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err898];
}
else {
vErrors.push(err898);
}
errors++;
}
}
else {
const err899 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/value/utf8",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/4/properties/utf8/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
}
}
}
else {
const err900 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err900];
}
else {
vErrors.push(err900);
}
errors++;
}
}
var _valid23 = _errs871 === errors;
if(_valid23 && valid156){
valid156 = false;
passing11 = [passing11, 4];
}
else {
if(_valid23){
valid156 = true;
passing11 = 4;
if(props14 !== true){
props14 = true;
}
}
const _errs876 = errors;
if(errors === _errs876){
if(data301 && typeof data301 == "object" && !Array.isArray(data301)){
let missing107;
if((data301.binary === undefined) && (missing107 = "binary")){
const err901 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/5/required",keyword:"required",params:{missingProperty: missing107},message:"must have required property '"+missing107+"'"};
if(vErrors === null){
vErrors = [err901];
}
else {
vErrors.push(err901);
}
errors++;
}
else {
const _errs878 = errors;
for(const key107 in data301){
if(!(key107 === "binary")){
const err902 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key107},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err902];
}
else {
vErrors.push(err902);
}
errors++;
break;
}
}
if(_errs878 === errors){
if(data301.binary !== undefined){
let data307 = data301.binary;
const _errs879 = errors;
if(errors === _errs879){
if(typeof data307 === "string"){
if(func1(data307) > 131072){
const err903 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/value/binary",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/5/properties/binary/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err903];
}
else {
vErrors.push(err903);
}
errors++;
}
}
else {
const err904 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/value/binary",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/5/properties/binary/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
}
}
}
else {
const err905 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err905];
}
else {
vErrors.push(err905);
}
errors++;
}
}
var _valid23 = _errs876 === errors;
if(_valid23 && valid156){
valid156 = false;
passing11 = [passing11, 5];
}
else {
if(_valid23){
valid156 = true;
passing11 = 5;
if(props14 !== true){
props14 = true;
}
}
}
}
}
}
}
if(!valid156){
const err906 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf",keyword:"oneOf",params:{passingSchemas: passing11},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err906];
}
else {
vErrors.push(err906);
}
errors++;
}
else {
errors = _errs850;
if(vErrors !== null){
if(_errs850){
vErrors.length = _errs850;
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
const err907 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err907];
}
else {
vErrors.push(err907);
}
errors++;
}
}
var _valid22 = _errs846 === errors;
if(_valid22 && valid152){
valid152 = false;
passing10 = [passing10, 2];
}
else {
if(_valid22){
valid152 = true;
passing10 = 2;
if(props13 !== true){
props13 = true;
}
}
}
}
if(!valid152){
const err908 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf",keyword:"oneOf",params:{passingSchemas: passing10},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err908];
}
else {
vErrors.push(err908);
}
errors++;
}
else {
errors = _errs835;
if(vErrors !== null){
if(_errs835){
vErrors.length = _errs835;
}
else {
vErrors = null;
}
}
}
var valid151 = _errs834 === errors;
}
else {
var valid151 = true;
}
}
}
}
}
}
else {
const err909 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict/" + i30,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err909];
}
else {
vErrors.push(err909);
}
errors++;
}
}
var valid150 = _errs827 === errors;
if(!valid150){
break;
}
}
}
}
else {
const err910 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29+"/conflict",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err910];
}
else {
vErrors.push(err910);
}
errors++;
}
}
}
}
}
}
else {
const err911 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err911];
}
else {
vErrors.push(err911);
}
errors++;
}
}
var _valid20 = _errs822 === errors;
if(_valid20 && valid137){
valid137 = false;
passing8 = [passing8, 4];
}
else {
if(_valid20){
valid137 = true;
passing8 = 4;
if(props11 !== true){
props11 = true;
}
}
}
}
}
}
if(!valid137){
const err912 = {instancePath:instancePath+"/page/cells/" + i28+"/" + i29,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf",keyword:"oneOf",params:{passingSchemas: passing8},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err912];
}
else {
vErrors.push(err912);
}
errors++;
}
else {
errors = _errs771;
if(vErrors !== null){
if(_errs771){
vErrors.length = _errs771;
}
else {
vErrors = null;
}
}
}
var valid136 = _errs770 === errors;
if(!valid136){
break;
}
}
}
}
else {
const err913 = {instancePath:instancePath+"/page/cells/" + i28,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err913];
}
else {
vErrors.push(err913);
}
errors++;
}
}
var valid135 = _errs768 === errors;
if(!valid135){
break;
}
}
}
}
else {
const err914 = {instancePath:instancePath+"/page/cells",schemaPath:"#/oneOf/9/properties/page/properties/cells/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err914];
}
else {
vErrors.push(err914);
}
errors++;
}
}
var valid121 = _errs766 === errors;
}
else {
var valid121 = true;
}
}
}
}
}
else {
const err915 = {instancePath:instancePath+"/page",schemaPath:"#/oneOf/9/properties/page/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err915];
}
else {
vErrors.push(err915);
}
errors++;
}
}
}
}
}
}
else {
const err916 = {instancePath,schemaPath:"#/oneOf/9/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err916];
}
else {
vErrors.push(err916);
}
errors++;
}
}
var _valid0 = _errs665 === errors;
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
const _errs881 = errors;
if(errors === _errs881){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing108;
if((data.draft === undefined) && (missing108 = "draft")){
const err917 = {instancePath,schemaPath:"#/oneOf/10/required",keyword:"required",params:{missingProperty: missing108},message:"must have required property '"+missing108+"'"};
if(vErrors === null){
vErrors = [err917];
}
else {
vErrors.push(err917);
}
errors++;
}
else {
const _errs883 = errors;
for(const key108 in data){
if(!(key108 === "draft")){
const err918 = {instancePath,schemaPath:"#/oneOf/10/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key108},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err918];
}
else {
vErrors.push(err918);
}
errors++;
break;
}
}
if(_errs883 === errors){
if(data.draft !== undefined){
let data308 = data.draft;
const _errs885 = errors;
let valid164 = false;
const _errs886 = errors;
if(errors === _errs886){
if(data308 && typeof data308 == "object" && !Array.isArray(data308)){
let missing109;
if((((((((data308.generation === undefined) && (missing109 = "generation")) || ((data308.limit === undefined) && (missing109 = "limit"))) || ((data308.starts === undefined) && (missing109 = "starts"))) || ((data308.enabled === undefined) && (missing109 = "enabled"))) || ((data308.contract === undefined) && (missing109 = "contract"))) || ((data308.budgets === undefined) && (missing109 = "budgets"))) || ((data308.namespaces === undefined) && (missing109 = "namespaces"))){
const err919 = {instancePath:instancePath+"/draft",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/required",keyword:"required",params:{missingProperty: missing109},message:"must have required property '"+missing109+"'"};
if(vErrors === null){
vErrors = [err919];
}
else {
vErrors.push(err919);
}
errors++;
}
else {
const _errs888 = errors;
for(const key109 in data308){
if(!(((((((key109 === "generation") || (key109 === "limit")) || (key109 === "starts")) || (key109 === "enabled")) || (key109 === "contract")) || (key109 === "budgets")) || (key109 === "namespaces"))){
const err920 = {instancePath:instancePath+"/draft",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key109},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err920];
}
else {
vErrors.push(err920);
}
errors++;
break;
}
}
if(_errs888 === errors){
if(data308.generation !== undefined){
let data309 = data308.generation;
const _errs889 = errors;
if(errors === _errs889){
if(typeof data309 === "string"){
if(func1(data309) > 131072){
const err921 = {instancePath:instancePath+"/draft/generation",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/generation/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err921];
}
else {
vErrors.push(err921);
}
errors++;
}
}
else {
const err922 = {instancePath:instancePath+"/draft/generation",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/generation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err922];
}
else {
vErrors.push(err922);
}
errors++;
}
}
var valid165 = _errs889 === errors;
}
else {
var valid165 = true;
}
if(valid165){
if(data308.limit !== undefined){
let data310 = data308.limit;
const _errs891 = errors;
if(!(((typeof data310 == "number") && (!(data310 % 1) && !isNaN(data310))) && (isFinite(data310)))){
const err923 = {instancePath:instancePath+"/draft/limit",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/limit/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err923];
}
else {
vErrors.push(err923);
}
errors++;
}
if(errors === _errs891){
if((typeof data310 == "number") && (isFinite(data310))){
if(data310 > 255 || isNaN(data310)){
const err924 = {instancePath:instancePath+"/draft/limit",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/limit/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err924];
}
else {
vErrors.push(err924);
}
errors++;
}
else {
if(data310 < 0 || isNaN(data310)){
const err925 = {instancePath:instancePath+"/draft/limit",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/limit/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err925];
}
else {
vErrors.push(err925);
}
errors++;
}
}
}
}
var valid165 = _errs891 === errors;
}
else {
var valid165 = true;
}
if(valid165){
if(data308.starts !== undefined){
let data311 = data308.starts;
const _errs893 = errors;
if(!(((typeof data311 == "number") && (!(data311 % 1) && !isNaN(data311))) && (isFinite(data311)))){
const err926 = {instancePath:instancePath+"/draft/starts",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/starts/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err926];
}
else {
vErrors.push(err926);
}
errors++;
}
if(errors === _errs893){
if((typeof data311 == "number") && (isFinite(data311))){
if(data311 > 255 || isNaN(data311)){
const err927 = {instancePath:instancePath+"/draft/starts",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/starts/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err927];
}
else {
vErrors.push(err927);
}
errors++;
}
else {
if(data311 < 0 || isNaN(data311)){
const err928 = {instancePath:instancePath+"/draft/starts",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/starts/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err928];
}
else {
vErrors.push(err928);
}
errors++;
}
}
}
}
var valid165 = _errs893 === errors;
}
else {
var valid165 = true;
}
if(valid165){
if(data308.enabled !== undefined){
const _errs895 = errors;
if(typeof data308.enabled !== "boolean"){
const err929 = {instancePath:instancePath+"/draft/enabled",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/enabled/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err929];
}
else {
vErrors.push(err929);
}
errors++;
}
var valid165 = _errs895 === errors;
}
else {
var valid165 = true;
}
if(valid165){
if(data308.contract !== undefined){
let data313 = data308.contract;
const _errs897 = errors;
if(errors === _errs897){
if(Array.isArray(data313)){
if(data313.length > 32){
const err930 = {instancePath:instancePath+"/draft/contract",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/contract/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err930];
}
else {
vErrors.push(err930);
}
errors++;
}
else {
if(data313.length < 32){
const err931 = {instancePath:instancePath+"/draft/contract",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/contract/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err931];
}
else {
vErrors.push(err931);
}
errors++;
}
else {
var valid166 = true;
const len31 = data313.length;
for(let i31=0; i31<len31; i31++){
let data314 = data313[i31];
const _errs899 = errors;
if(!(((typeof data314 == "number") && (!(data314 % 1) && !isNaN(data314))) && (isFinite(data314)))){
const err932 = {instancePath:instancePath+"/draft/contract/" + i31,schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/contract/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err932];
}
else {
vErrors.push(err932);
}
errors++;
}
if(errors === _errs899){
if((typeof data314 == "number") && (isFinite(data314))){
if(data314 > 255 || isNaN(data314)){
const err933 = {instancePath:instancePath+"/draft/contract/" + i31,schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/contract/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err933];
}
else {
vErrors.push(err933);
}
errors++;
}
else {
if(data314 < 0 || isNaN(data314)){
const err934 = {instancePath:instancePath+"/draft/contract/" + i31,schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/contract/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err934];
}
else {
vErrors.push(err934);
}
errors++;
}
}
}
}
var valid166 = _errs899 === errors;
if(!valid166){
break;
}
}
}
}
}
else {
const err935 = {instancePath:instancePath+"/draft/contract",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/contract/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err935];
}
else {
vErrors.push(err935);
}
errors++;
}
}
var valid165 = _errs897 === errors;
}
else {
var valid165 = true;
}
if(valid165){
if(data308.budgets !== undefined){
let data315 = data308.budgets;
const _errs901 = errors;
if(errors === _errs901){
if(data315 && typeof data315 == "object" && !Array.isArray(data315)){
let missing110;
if((((data315.pages === undefined) && (missing110 = "pages")) || ((data315.segments === undefined) && (missing110 = "segments"))) || ((data315.result_bytes === undefined) && (missing110 = "result_bytes"))){
const err936 = {instancePath:instancePath+"/draft/budgets",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/budgets/required",keyword:"required",params:{missingProperty: missing110},message:"must have required property '"+missing110+"'"};
if(vErrors === null){
vErrors = [err936];
}
else {
vErrors.push(err936);
}
errors++;
}
else {
const _errs903 = errors;
for(const key110 in data315){
if(!(((key110 === "pages") || (key110 === "segments")) || (key110 === "result_bytes"))){
const err937 = {instancePath:instancePath+"/draft/budgets",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/budgets/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key110},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err937];
}
else {
vErrors.push(err937);
}
errors++;
break;
}
}
if(_errs903 === errors){
if(data315.pages !== undefined){
let data316 = data315.pages;
const _errs904 = errors;
if(errors === _errs904){
if(typeof data316 === "string"){
if(func1(data316) > 131072){
const err938 = {instancePath:instancePath+"/draft/budgets/pages",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/budgets/properties/pages/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err938];
}
else {
vErrors.push(err938);
}
errors++;
}
}
else {
const err939 = {instancePath:instancePath+"/draft/budgets/pages",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/budgets/properties/pages/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err939];
}
else {
vErrors.push(err939);
}
errors++;
}
}
var valid167 = _errs904 === errors;
}
else {
var valid167 = true;
}
if(valid167){
if(data315.segments !== undefined){
let data317 = data315.segments;
const _errs906 = errors;
if(errors === _errs906){
if(typeof data317 === "string"){
if(func1(data317) > 131072){
const err940 = {instancePath:instancePath+"/draft/budgets/segments",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/budgets/properties/segments/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err940];
}
else {
vErrors.push(err940);
}
errors++;
}
}
else {
const err941 = {instancePath:instancePath+"/draft/budgets/segments",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/budgets/properties/segments/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err941];
}
else {
vErrors.push(err941);
}
errors++;
}
}
var valid167 = _errs906 === errors;
}
else {
var valid167 = true;
}
if(valid167){
if(data315.result_bytes !== undefined){
let data318 = data315.result_bytes;
const _errs908 = errors;
if(errors === _errs908){
if(typeof data318 === "string"){
if(func1(data318) > 131072){
const err942 = {instancePath:instancePath+"/draft/budgets/result_bytes",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/budgets/properties/result_bytes/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err942];
}
else {
vErrors.push(err942);
}
errors++;
}
}
else {
const err943 = {instancePath:instancePath+"/draft/budgets/result_bytes",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/budgets/properties/result_bytes/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err943];
}
else {
vErrors.push(err943);
}
errors++;
}
}
var valid167 = _errs908 === errors;
}
else {
var valid167 = true;
}
}
}
}
}
}
else {
const err944 = {instancePath:instancePath+"/draft/budgets",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/budgets/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err944];
}
else {
vErrors.push(err944);
}
errors++;
}
}
var valid165 = _errs901 === errors;
}
else {
var valid165 = true;
}
if(valid165){
if(data308.namespaces !== undefined){
let data319 = data308.namespaces;
const _errs910 = errors;
if(errors === _errs910){
if(Array.isArray(data319)){
if(data319.length > 8){
const err945 = {instancePath:instancePath+"/draft/namespaces",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/namespaces/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err945];
}
else {
vErrors.push(err945);
}
errors++;
}
else {
if(data319.length < 8){
const err946 = {instancePath:instancePath+"/draft/namespaces",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/namespaces/minItems",keyword:"minItems",params:{limit: 8},message:"must NOT have fewer than 8 items"};
if(vErrors === null){
vErrors = [err946];
}
else {
vErrors.push(err946);
}
errors++;
}
else {
var valid168 = true;
const len32 = data319.length;
for(let i32=0; i32<len32; i32++){
let data320 = data319[i32];
const _errs912 = errors;
if(errors === _errs912){
if(typeof data320 === "string"){
if(func1(data320) > 131072){
const err947 = {instancePath:instancePath+"/draft/namespaces/" + i32,schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/namespaces/items/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err947];
}
else {
vErrors.push(err947);
}
errors++;
}
}
else {
const err948 = {instancePath:instancePath+"/draft/namespaces/" + i32,schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/namespaces/items/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err948];
}
else {
vErrors.push(err948);
}
errors++;
}
}
var valid168 = _errs912 === errors;
if(!valid168){
break;
}
}
}
}
}
else {
const err949 = {instancePath:instancePath+"/draft/namespaces",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/namespaces/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err949];
}
else {
vErrors.push(err949);
}
errors++;
}
}
var valid165 = _errs910 === errors;
}
else {
var valid165 = true;
}
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
const err950 = {instancePath:instancePath+"/draft",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err950];
}
else {
vErrors.push(err950);
}
errors++;
}
}
var _valid24 = _errs886 === errors;
valid164 = valid164 || _valid24;
const _errs914 = errors;
if(data308 !== null){
const err951 = {instancePath:instancePath+"/draft",schemaPath:"#/oneOf/10/properties/draft/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err951];
}
else {
vErrors.push(err951);
}
errors++;
}
var _valid24 = _errs914 === errors;
valid164 = valid164 || _valid24;
if(!valid164){
const err952 = {instancePath:instancePath+"/draft",schemaPath:"#/oneOf/10/properties/draft/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err952];
}
else {
vErrors.push(err952);
}
errors++;
}
else {
errors = _errs885;
if(vErrors !== null){
if(_errs885){
vErrors.length = _errs885;
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
const err953 = {instancePath,schemaPath:"#/oneOf/10/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err953];
}
else {
vErrors.push(err953);
}
errors++;
}
}
var _valid0 = _errs881 === errors;
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
}
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
const err954 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err954];
}
else {
vErrors.push(err954);
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
