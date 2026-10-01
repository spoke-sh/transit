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
const schema33 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["description"],"properties":{"description":{"type":"object","additionalProperties":false,"properties":{"connection":{"type":"object","additionalProperties":false,"properties":{"realm":{"type":"integer","minimum":0,"maximum":9007199254740991},"principal":{"type":"integer","minimum":0,"maximum":9007199254740991},"source":{"type":"integer","minimum":0,"maximum":9007199254740991},"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"requester":{"type":"integer","minimum":0,"maximum":9007199254740991},"requests":{"type":"integer","minimum":0,"maximum":9007199254740991}},"required":["realm","principal","source","resource","requester","requests"]},"name":{"type":"string","maxLength":131072},"source":{"type":"object","additionalProperties":false,"properties":{"capabilities":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"source":{"type":"integer","minimum":0,"maximum":255},"plan":{"type":"integer","minimum":0,"maximum":255},"result":{"type":"integer","minimum":0,"maximum":255},"bundle_bytes":{"type":"integer","minimum":0,"maximum":4294967295},"part_bytes":{"type":"integer","minimum":0,"maximum":65535},"segment_bytes":{"type":"integer","minimum":0,"maximum":4294967295},"batch_rows":{"type":"integer","minimum":0,"maximum":255},"columns":{"type":"integer","minimum":0,"maximum":255},"kv":{"type":"boolean"},"table":{"type":"boolean"},"document":{"type":"boolean"}},"required":["version","source","plan","result","bundle_bytes","part_bytes","segment_bytes","batch_rows","columns","kv","table","document"]},"source":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"source":{"oneOf":[{"type":"object","additionalProperties":false,"required":["kv"],"properties":{"kv":{"type":"object","additionalProperties":false,"properties":{"prefix":{"type":"string","maxLength":131072},"key":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["version","type"]},"value":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["version","type"]}},"required":["prefix","key","value"]}}},{"type":"object","additionalProperties":false,"required":["table"],"properties":{"table":{"type":"object","additionalProperties":false,"properties":{"id":{"type":"integer","minimum":0,"maximum":4294967295},"names":{"type":"array","minItems":2,"maxItems":2,"items":{"type":"string","maxLength":131072}},"value_type":{"type":"string","enum":["int64","boolean","utf8","binary"]}},"required":["id","names","value_type"]}}},{"type":"object","additionalProperties":false,"required":["document"],"properties":{"document":{"type":"object","additionalProperties":false,"properties":{"reference":{"type":"object","additionalProperties":false,"properties":{"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"document":{"type":"string","maxLength":131072},"epoch":{"type":"string","maxLength":131072},"type_revision":{"type":"integer","minimum":0,"maximum":4294967295},"revision":{"type":"string","maxLength":131072}},"required":["resource","document","epoch","type_revision","revision"]},"change_format":{"type":"integer","minimum":0,"maximum":4294967295},"expand":{"anyOf":[{"type":"array","maxItems":8,"items":{"type":"string","maxLength":131072}},{"type":"null"}]},"projections":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"column":{"type":"object","additionalProperties":false,"properties":{"name":{"type":"string","maxLength":131072},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["name","type"]},"path":{"type":"array","maxItems":8,"items":{"type":"string","maxLength":131072}},"relative":{"type":"boolean"},"mode":{"type":"string","enum":["scalar","text","element_counter","element_replica"]},"text_bytes":{"type":"integer","minimum":0,"maximum":65535},"text_steps":{"type":"integer","minimum":0,"maximum":65535}},"required":["column","path","relative","mode","text_bytes","text_steps"]}}},"required":["reference","change_format","expand","projections"]}}}]}},"required":["version","resource","source"]},"resource_revision":{"type":"integer","minimum":0,"maximum":9007199254740991},"policy_revision":{"type":"string","maxLength":131072},"limits":{"type":"object","additionalProperties":false,"properties":{"pages":{"type":"string","maxLength":131072},"segments":{"type":"string","maxLength":131072},"result_bytes":{"type":"string","maxLength":131072}},"required":["pages","segments","result_bytes"]},"active":{"anyOf":[{"type":"string","maxLength":131072},{"type":"null"}]}},"required":["capabilities","source","resource_revision","policy_revision","limits","active"]},"sql":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"statement_bytes":{"type":"integer","minimum":0,"maximum":4294967295},"named_columns":{"type":"integer","minimum":0,"maximum":255},"star_columns":{"type":"integer","minimum":0,"maximum":255},"uint64_limits":{"type":"boolean"},"uint64_literals":{"type":"boolean"},"float64_literals":{"type":"boolean"},"null_comparison":{"type":"boolean"},"explicit_null_test":{"type":"boolean"},"writes":{"type":"boolean"},"continuous":{"type":"boolean"}},"required":["version","statement_bytes","named_columns","star_columns","uint64_limits","uint64_literals","float64_literals","null_comparison","explicit_null_test","writes","continuous"]},"budgets":{"type":"object","additionalProperties":false,"properties":{"pages":{"type":"string","maxLength":131072},"segments":{"type":"string","maxLength":131072},"result_bytes":{"type":"string","maxLength":131072}},"required":["pages","segments","result_bytes"]},"columns":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"name":{"type":"string","maxLength":131072},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["name","type"]}}},"required":["connection","name","source","sql","budgets","columns"]}}},{"type":"object","additionalProperties":false,"required":["suggestions"],"properties":{"suggestions":{"type":"object","additionalProperties":false,"properties":{"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"contract":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"items":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"label":{"type":"string","maxLength":131072},"sql":{"type":"string","maxLength":131072}},"required":["label","sql"]}}},"required":["resource","contract","items"]}}},{"type":"object","additionalProperties":false,"required":["assistance"],"properties":{"assistance":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"generation":{"type":"integer","minimum":0,"maximum":4294967295},"profile":{"type":"string","enum":["unified_v1"]},"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"contract":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"resource_revision":{"type":"integer","minimum":0,"maximum":9007199254740991},"policy_revision":{"type":"string","maxLength":131072},"range":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"start":{"type":"integer","minimum":0,"maximum":65535},"end":{"type":"integer","minimum":0,"maximum":65535},"quoted":{"type":"boolean"}},"required":["start","end","quoted"]},{"type":"null"}]},"items":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"text":{"type":"string","maxLength":131072},"kind":{"type":"string","enum":["keyword","source","column","symbol","literal","meta"]},"detail":{"type":"string","maxLength":131072}},"required":["text","kind","detail"]}}},"required":["version","generation","profile","resource","contract","resource_revision","policy_revision","range","items"]}}},{"type":"object","additionalProperties":false,"required":["compiled"],"properties":{"compiled":{"type":"object","additionalProperties":false,"properties":{"bundle":{"type":"string","maxLength":131072},"source":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"source":{"oneOf":[{"type":"object","additionalProperties":false,"required":["kv"],"properties":{"kv":{"type":"object","additionalProperties":false,"properties":{"prefix":{"type":"string","maxLength":131072},"key":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["version","type"]},"value":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["version","type"]}},"required":["prefix","key","value"]}}},{"type":"object","additionalProperties":false,"required":["table"],"properties":{"table":{"type":"object","additionalProperties":false,"properties":{"id":{"type":"integer","minimum":0,"maximum":4294967295},"names":{"type":"array","minItems":2,"maxItems":2,"items":{"type":"string","maxLength":131072}},"value_type":{"type":"string","enum":["int64","boolean","utf8","binary"]}},"required":["id","names","value_type"]}}},{"type":"object","additionalProperties":false,"required":["document"],"properties":{"document":{"type":"object","additionalProperties":false,"properties":{"reference":{"type":"object","additionalProperties":false,"properties":{"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"document":{"type":"string","maxLength":131072},"epoch":{"type":"string","maxLength":131072},"type_revision":{"type":"integer","minimum":0,"maximum":4294967295},"revision":{"type":"string","maxLength":131072}},"required":["resource","document","epoch","type_revision","revision"]},"change_format":{"type":"integer","minimum":0,"maximum":4294967295},"expand":{"anyOf":[{"type":"array","maxItems":8,"items":{"type":"string","maxLength":131072}},{"type":"null"}]},"projections":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"column":{"type":"object","additionalProperties":false,"properties":{"name":{"type":"string","maxLength":131072},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["name","type"]},"path":{"type":"array","maxItems":8,"items":{"type":"string","maxLength":131072}},"relative":{"type":"boolean"},"mode":{"type":"string","enum":["scalar","text","element_counter","element_replica"]},"text_bytes":{"type":"integer","minimum":0,"maximum":65535},"text_steps":{"type":"integer","minimum":0,"maximum":65535}},"required":["column","path","relative","mode","text_bytes","text_steps"]}}},"required":["reference","change_format","expand","projections"]}}}]}},"required":["version","resource","source"]},"plan":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"projection":{"type":"array","maxItems":8,"items":{"type":"integer","minimum":0,"maximum":4294967295}},"output_names":{"anyOf":[{"type":"array","maxItems":8,"items":{"anyOf":[{"type":"string","maxLength":131072},{"type":"null"}]}},{"type":"null"}]},"limit":{"anyOf":[{"type":"string","maxLength":131072},{"type":"null"}]},"aggregate":{"type":"string","enum":["rows","count","sum","count_values"]},"predicate":{"oneOf":[{"type":"object","additionalProperties":false,"required":["all"],"properties":{"all":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["state"],"properties":{"state":{"type":"object","additionalProperties":false,"properties":{"column":{"type":"integer","minimum":0,"maximum":255},"value":{"type":"string","enum":["missing","null","type_error","value","conflict"]}},"required":["column","value"]}}},{"type":"object","additionalProperties":false,"required":["compare"],"properties":{"compare":{"type":"object","additionalProperties":false,"properties":{"column":{"type":"integer","minimum":0,"maximum":255},"op":{"type":"string","enum":["eq","ne","lt","le","gt","ge"]},"value":{"oneOf":[{"type":"object","additionalProperties":false,"required":["int64"],"properties":{"int64":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["uint64"],"properties":{"uint64":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"type":"boolean"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"type":"string","maxLength":131072}}}]}},"required":["column","op","value"]}}},{"type":"object","additionalProperties":false,"required":["program"],"properties":{"program":{"type":"array","maxItems":64,"items":{"oneOf":[{"type":"object","additionalProperties":false,"required":["atom"],"properties":{"atom":{"oneOf":[{"type":"object","additionalProperties":false,"required":["all"],"properties":{"all":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["state"],"properties":{"state":{"type":"object","additionalProperties":false,"properties":{"column":{"type":"integer","minimum":0,"maximum":255},"value":{"type":"string","enum":["missing","null","type_error","value","conflict"]}},"required":["column","value"]}}},{"type":"object","additionalProperties":false,"required":["compare"],"properties":{"compare":{"type":"object","additionalProperties":false,"properties":{"column":{"type":"integer","minimum":0,"maximum":255},"op":{"type":"string","enum":["eq","ne","lt","le","gt","ge"]},"value":{"oneOf":[{"type":"object","additionalProperties":false,"required":["int64"],"properties":{"int64":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["uint64"],"properties":{"uint64":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"type":"boolean"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"type":"string","maxLength":131072}}}]}},"required":["column","op","value"]}}}]}}},{"type":"object","additionalProperties":false,"required":["negate"],"properties":{"negate":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["conjunction"],"properties":{"conjunction":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["disjunction"],"properties":{"disjunction":{"type":"object","maxProperties":0}}}]}}}}]}},"required":["version","projection","output_names","limit","aggregate","predicate"]},"limits":{"type":"object","additionalProperties":false,"properties":{"pages":{"type":"string","maxLength":131072},"segments":{"type":"string","maxLength":131072},"result_bytes":{"type":"string","maxLength":131072}},"required":["pages","segments","result_bytes"]},"contract":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"schema":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}}},"required":["bundle","source","plan","limits","contract","schema"]}}},{"type":"object","additionalProperties":false,"required":["inspection"],"properties":{"inspection":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"scope":{"type":"string","enum":["configured_source"]},"name":{"type":"string","maxLength":131072},"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"source_kind":{"type":"string","enum":["kv","table","document"]},"contract":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"schema":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"resource_revision":{"type":"integer","minimum":0,"maximum":9007199254740991},"policy_revision":{"type":"string","maxLength":131072},"details":{"oneOf":[{"type":"object","additionalProperties":false,"required":["description"],"properties":{"description":{"type":"object","additionalProperties":false,"properties":{"columns":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"name":{"type":"string","maxLength":131072},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["name","type"]}}},"required":["columns"]}}},{"type":"object","additionalProperties":false,"required":["tables"],"properties":{"tables":{"type":"array","maxItems":8,"items":{"type":"string","maxLength":131072}}}},{"type":"object","additionalProperties":false,"required":["explanation"],"properties":{"explanation":{"type":"object","additionalProperties":false,"properties":{"operators":{"type":"array","maxItems":8,"items":{"type":"string","enum":["scan","filter","limit","project","count","sum","count_values"]}},"predicate":{"oneOf":[{"type":"object","additionalProperties":false,"required":["all"],"properties":{"all":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["state"],"properties":{"state":{"type":"object","additionalProperties":false,"properties":{"column":{"type":"string","maxLength":131072},"value":{"type":"string","enum":["missing","null","type_error","value","conflict"]}},"required":["column","value"]}}},{"type":"object","additionalProperties":false,"required":["compare"],"properties":{"compare":{"type":"object","additionalProperties":false,"properties":{"column":{"type":"string","maxLength":131072},"op":{"type":"string","enum":["eq","ne","lt","le","gt","ge"]},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["column","op","type"]}}},{"type":"object","additionalProperties":false,"required":["program"],"properties":{"program":{"type":"array","maxItems":64,"items":{"oneOf":[{"type":"object","additionalProperties":false,"required":["atom"],"properties":{"atom":{"oneOf":[{"type":"object","additionalProperties":false,"required":["all"],"properties":{"all":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["state"],"properties":{"state":{"type":"object","additionalProperties":false,"properties":{"column":{"type":"string","maxLength":131072},"value":{"type":"string","enum":["missing","null","type_error","value","conflict"]}},"required":["column","value"]}}},{"type":"object","additionalProperties":false,"required":["compare"],"properties":{"compare":{"type":"object","additionalProperties":false,"properties":{"column":{"type":"string","maxLength":131072},"op":{"type":"string","enum":["eq","ne","lt","le","gt","ge"]},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["column","op","type"]}}}]}}},{"type":"object","additionalProperties":false,"required":["negate"],"properties":{"negate":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["conjunction"],"properties":{"conjunction":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["disjunction"],"properties":{"disjunction":{"type":"object","maxProperties":0}}}]}}}}]},"projection":{"type":"array","maxItems":8,"items":{"type":"string","maxLength":131072}},"limit":{"anyOf":[{"type":"string","maxLength":131072},{"type":"null"}]},"aggregate":{"type":"string","enum":["rows","count","sum","count_values"]},"columns":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"name":{"type":"string","maxLength":131072},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["name","type"]}},"budgets":{"type":"object","additionalProperties":false,"properties":{"pages":{"type":"string","maxLength":131072},"segments":{"type":"string","maxLength":131072},"result_bytes":{"type":"string","maxLength":131072}},"required":["pages","segments","result_bytes"]}},"required":["operators","predicate","projection","limit","aggregate","columns","budgets"]}}}]}},"required":["version","scope","name","resource","source_kind","contract","schema","resource_revision","policy_revision","details"]}}},{"type":"object","additionalProperties":false,"required":["prepared"],"properties":{"prepared":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"token":{"type":"string","maxLength":131072}},"required":["token"]},{"type":"null"}]}}},{"type":"object","additionalProperties":false,"required":["receipt"],"properties":{"receipt":{"type":"object","additionalProperties":false,"properties":{"position":{"type":"integer","minimum":0,"maximum":9007199254740991}},"required":["position"]}}},{"type":"object","additionalProperties":false,"required":["observation"],"properties":{"observation":{"oneOf":[{"type":"object","additionalProperties":false,"required":["pending"],"properties":{"pending":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["committed"],"properties":{"committed":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["rejected"],"properties":{"rejected":{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512}}}]}}},{"type":"object","additionalProperties":false,"required":["status"],"properties":{"status":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"reference":{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512},"phase":{"type":"string","enum":["uploading","sealed","admitted","complete","cancelled","denied","rejected","retired"]},"correlation":{"type":"string","maxLength":131072},"manifest":{"anyOf":[{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512},{"type":"null"}]},"collected":{"type":"boolean"}},"required":["reference","phase","correlation","manifest","collected"]},{"type":"null"}]}}},{"type":"object","additionalProperties":false,"required":["page"],"properties":{"page":{"type":"object","additionalProperties":false,"properties":{"evidence":{"type":"object","additionalProperties":false,"properties":{"manifest":{"type":"object","additionalProperties":false,"properties":{"job":{"type":"integer","minimum":0,"maximum":9007199254740991},"source":{"type":"object","additionalProperties":false,"properties":{"pid":{"type":"integer","minimum":0,"maximum":9007199254740991},"input":{"type":"integer","minimum":0,"maximum":9007199254740991},"index":{"type":"integer","minimum":0,"maximum":255}},"required":["pid","input","index"]},"requester":{"type":"integer","minimum":0,"maximum":9007199254740991},"correlation":{"type":"string","maxLength":131072},"policy_revision":{"type":"string","maxLength":131072},"request":{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512},"basis":{"type":"object","additionalProperties":false,"properties":{"kind":{"type":"string","enum":["kv","table","document"]},"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"revision":{"type":"integer","minimum":0,"maximum":9007199254740991},"contract":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"schema":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}}},"required":["kind","resource","revision","contract","schema"]},"plan":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"pages":{"type":"string","maxLength":131072},"scanned":{"type":"string","maxLength":131072},"selected":{"type":"string","maxLength":131072},"value_count":{"type":"string","maxLength":131072},"segments":{"type":"string","maxLength":131072},"rows":{"type":"string","maxLength":131072},"bytes":{"type":"string","maxLength":131072},"sum":{"anyOf":[{"type":"string","maxLength":131072},{"type":"null"}]},"finished":{"anyOf":[{"type":"string","enum":["source_end","limit"]},{"type":"null"}]},"chain":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}}},"required":["job","source","requester","correlation","policy_revision","request","basis","plan","pages","scanned","selected","value_count","segments","rows","bytes","sum","finished","chain"]},"columns":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"name":{"type":"string","maxLength":131072},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["name","type"]}},"ordinal":{"type":"string","maxLength":131072},"rows":{"type":"integer","minimum":0,"maximum":255},"ipc":{"type":"string","maxLength":131072},"next":{"anyOf":[{"type":"string","maxLength":131072},{"type":"null"}]}},"required":["manifest","columns","ordinal","rows","ipc","next"]},"cells":{"type":"array","maxItems":8,"items":{"type":"array","maxItems":8,"items":{"oneOf":[{"type":"object","additionalProperties":false,"required":["missing"],"properties":{"missing":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["null"],"properties":{"null":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["type_error"],"properties":{"type_error":{"type":"string","enum":["unknown","int64","uint64","float64","boolean","utf8","binary","null_value","map","list","text","character"]}}},{"type":"object","additionalProperties":false,"required":["value"],"properties":{"value":{"oneOf":[{"type":"object","additionalProperties":false,"required":["int64"],"properties":{"int64":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["uint64"],"properties":{"uint64":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"type":"boolean"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"type":"string","maxLength":131072}}}]}}},{"type":"object","additionalProperties":false,"required":["conflict"],"properties":{"conflict":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"counter":{"type":"string","maxLength":131072},"replica":{"type":"string","maxLength":131072},"value":{"oneOf":[{"type":"object","additionalProperties":false,"required":["null"],"properties":{"null":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["type_error"],"properties":{"type_error":{"type":"string","enum":["unknown","int64","uint64","float64","boolean","utf8","binary","null_value","map","list","text","character"]}}},{"type":"object","additionalProperties":false,"required":["value"],"properties":{"value":{"oneOf":[{"type":"object","additionalProperties":false,"required":["int64"],"properties":{"int64":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["uint64"],"properties":{"uint64":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"type":"boolean"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"type":"string","maxLength":131072}}}]}}}]}},"required":["counter","replica","value"]}}}}]}}}},"required":["evidence","cells"]}}},{"type":"object","additionalProperties":false,"required":["draft"],"properties":{"draft":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"generation":{"type":"string","maxLength":131072},"limit":{"type":"integer","minimum":0,"maximum":255},"starts":{"type":"integer","minimum":0,"maximum":255},"enabled":{"type":"boolean"},"contract":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"budgets":{"type":"object","additionalProperties":false,"properties":{"pages":{"type":"string","maxLength":131072},"segments":{"type":"string","maxLength":131072},"result_bytes":{"type":"string","maxLength":131072}},"required":["pages","segments","result_bytes"]},"namespaces":{"type":"array","minItems":8,"maxItems":8,"items":{"type":"string","maxLength":131072}}},"required":["generation","limit","starts","enabled","contract","budgets","namespaces"]},{"type":"null"}]}}}]};
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
if(((((((data154.version === undefined) && (missing42 = "version")) || ((data154.projection === undefined) && (missing42 = "projection"))) || ((data154.output_names === undefined) && (missing42 = "output_names"))) || ((data154.limit === undefined) && (missing42 = "limit"))) || ((data154.aggregate === undefined) && (missing42 = "aggregate"))) || ((data154.predicate === undefined) && (missing42 = "predicate"))){
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
if(!((((((key42 === "version") || (key42 === "projection")) || (key42 === "output_names")) || (key42 === "limit")) || (key42 === "aggregate")) || (key42 === "predicate"))){
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
if(data154.output_names !== undefined){
let data158 = data154.output_names;
const _errs396 = errors;
const _errs397 = errors;
let valid64 = false;
const _errs398 = errors;
if(errors === _errs398){
if(Array.isArray(data158)){
if(data158.length > 8){
const err424 = {instancePath:instancePath+"/compiled/plan/output_names",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/output_names/anyOf/0/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err424];
}
else {
vErrors.push(err424);
}
errors++;
}
else {
var valid65 = true;
const len14 = data158.length;
for(let i14=0; i14<len14; i14++){
let data159 = data158[i14];
const _errs400 = errors;
const _errs401 = errors;
let valid66 = false;
const _errs402 = errors;
if(errors === _errs402){
if(typeof data159 === "string"){
if(func1(data159) > 131072){
const err425 = {instancePath:instancePath+"/compiled/plan/output_names/" + i14,schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/output_names/anyOf/0/items/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err425];
}
else {
vErrors.push(err425);
}
errors++;
}
}
else {
const err426 = {instancePath:instancePath+"/compiled/plan/output_names/" + i14,schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/output_names/anyOf/0/items/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err426];
}
else {
vErrors.push(err426);
}
errors++;
}
}
var _valid8 = _errs402 === errors;
valid66 = valid66 || _valid8;
const _errs404 = errors;
if(data159 !== null){
const err427 = {instancePath:instancePath+"/compiled/plan/output_names/" + i14,schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/output_names/anyOf/0/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err427];
}
else {
vErrors.push(err427);
}
errors++;
}
var _valid8 = _errs404 === errors;
valid66 = valid66 || _valid8;
if(!valid66){
const err428 = {instancePath:instancePath+"/compiled/plan/output_names/" + i14,schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/output_names/anyOf/0/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err428];
}
else {
vErrors.push(err428);
}
errors++;
}
else {
errors = _errs401;
if(vErrors !== null){
if(_errs401){
vErrors.length = _errs401;
}
else {
vErrors = null;
}
}
}
var valid65 = _errs400 === errors;
if(!valid65){
break;
}
}
}
}
else {
const err429 = {instancePath:instancePath+"/compiled/plan/output_names",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/output_names/anyOf/0/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err429];
}
else {
vErrors.push(err429);
}
errors++;
}
}
var _valid7 = _errs398 === errors;
valid64 = valid64 || _valid7;
const _errs406 = errors;
if(data158 !== null){
const err430 = {instancePath:instancePath+"/compiled/plan/output_names",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/output_names/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err430];
}
else {
vErrors.push(err430);
}
errors++;
}
var _valid7 = _errs406 === errors;
valid64 = valid64 || _valid7;
if(!valid64){
const err431 = {instancePath:instancePath+"/compiled/plan/output_names",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/output_names/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err431];
}
else {
vErrors.push(err431);
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
if(data154.limit !== undefined){
let data160 = data154.limit;
const _errs408 = errors;
const _errs409 = errors;
let valid67 = false;
const _errs410 = errors;
if(errors === _errs410){
if(typeof data160 === "string"){
if(func1(data160) > 131072){
const err432 = {instancePath:instancePath+"/compiled/plan/limit",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/limit/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err433 = {instancePath:instancePath+"/compiled/plan/limit",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/limit/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err433];
}
else {
vErrors.push(err433);
}
errors++;
}
}
var _valid9 = _errs410 === errors;
valid67 = valid67 || _valid9;
const _errs412 = errors;
if(data160 !== null){
const err434 = {instancePath:instancePath+"/compiled/plan/limit",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/limit/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err434];
}
else {
vErrors.push(err434);
}
errors++;
}
var _valid9 = _errs412 === errors;
valid67 = valid67 || _valid9;
if(!valid67){
const err435 = {instancePath:instancePath+"/compiled/plan/limit",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/limit/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err435];
}
else {
vErrors.push(err435);
}
errors++;
}
else {
errors = _errs409;
if(vErrors !== null){
if(_errs409){
vErrors.length = _errs409;
}
else {
vErrors = null;
}
}
}
var valid62 = _errs408 === errors;
}
else {
var valid62 = true;
}
if(valid62){
if(data154.aggregate !== undefined){
let data161 = data154.aggregate;
const _errs414 = errors;
if(typeof data161 !== "string"){
const err436 = {instancePath:instancePath+"/compiled/plan/aggregate",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/aggregate/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err436];
}
else {
vErrors.push(err436);
}
errors++;
}
if(!((((data161 === "rows") || (data161 === "count")) || (data161 === "sum")) || (data161 === "count_values"))){
const err437 = {instancePath:instancePath+"/compiled/plan/aggregate",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/aggregate/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[3].properties.compiled.properties.plan.properties.aggregate.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err437];
}
else {
vErrors.push(err437);
}
errors++;
}
var valid62 = _errs414 === errors;
}
else {
var valid62 = true;
}
if(valid62){
if(data154.predicate !== undefined){
let data162 = data154.predicate;
const _errs416 = errors;
const _errs417 = errors;
let valid68 = false;
let passing3 = null;
const _errs418 = errors;
if(errors === _errs418){
if(data162 && typeof data162 == "object" && !Array.isArray(data162)){
let missing43;
if((data162.all === undefined) && (missing43 = "all")){
const err438 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/0/required",keyword:"required",params:{missingProperty: missing43},message:"must have required property '"+missing43+"'"};
if(vErrors === null){
vErrors = [err438];
}
else {
vErrors.push(err438);
}
errors++;
}
else {
const _errs420 = errors;
for(const key43 in data162){
if(!(key43 === "all")){
const err439 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key43},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err439];
}
else {
vErrors.push(err439);
}
errors++;
break;
}
}
if(_errs420 === errors){
if(data162.all !== undefined){
let data163 = data162.all;
const _errs421 = errors;
if(errors === _errs421){
if(data163 && typeof data163 == "object" && !Array.isArray(data163)){
if(Object.keys(data163).length > 0){
const err440 = {instancePath:instancePath+"/compiled/plan/predicate/all",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/0/properties/all/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err440];
}
else {
vErrors.push(err440);
}
errors++;
}
}
else {
const err441 = {instancePath:instancePath+"/compiled/plan/predicate/all",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/0/properties/all/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err442 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err442];
}
else {
vErrors.push(err442);
}
errors++;
}
}
var _valid10 = _errs418 === errors;
if(_valid10){
valid68 = true;
passing3 = 0;
var props4 = true;
}
const _errs423 = errors;
if(errors === _errs423){
if(data162 && typeof data162 == "object" && !Array.isArray(data162)){
let missing44;
if((data162.state === undefined) && (missing44 = "state")){
const err443 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/1/required",keyword:"required",params:{missingProperty: missing44},message:"must have required property '"+missing44+"'"};
if(vErrors === null){
vErrors = [err443];
}
else {
vErrors.push(err443);
}
errors++;
}
else {
const _errs425 = errors;
for(const key44 in data162){
if(!(key44 === "state")){
const err444 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key44},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err444];
}
else {
vErrors.push(err444);
}
errors++;
break;
}
}
if(_errs425 === errors){
if(data162.state !== undefined){
let data164 = data162.state;
const _errs426 = errors;
if(errors === _errs426){
if(data164 && typeof data164 == "object" && !Array.isArray(data164)){
let missing45;
if(((data164.column === undefined) && (missing45 = "column")) || ((data164.value === undefined) && (missing45 = "value"))){
const err445 = {instancePath:instancePath+"/compiled/plan/predicate/state",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/required",keyword:"required",params:{missingProperty: missing45},message:"must have required property '"+missing45+"'"};
if(vErrors === null){
vErrors = [err445];
}
else {
vErrors.push(err445);
}
errors++;
}
else {
const _errs428 = errors;
for(const key45 in data164){
if(!((key45 === "column") || (key45 === "value"))){
const err446 = {instancePath:instancePath+"/compiled/plan/predicate/state",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key45},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err446];
}
else {
vErrors.push(err446);
}
errors++;
break;
}
}
if(_errs428 === errors){
if(data164.column !== undefined){
let data165 = data164.column;
const _errs429 = errors;
if(!(((typeof data165 == "number") && (!(data165 % 1) && !isNaN(data165))) && (isFinite(data165)))){
const err447 = {instancePath:instancePath+"/compiled/plan/predicate/state/column",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/properties/column/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err447];
}
else {
vErrors.push(err447);
}
errors++;
}
if(errors === _errs429){
if((typeof data165 == "number") && (isFinite(data165))){
if(data165 > 255 || isNaN(data165)){
const err448 = {instancePath:instancePath+"/compiled/plan/predicate/state/column",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/properties/column/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err448];
}
else {
vErrors.push(err448);
}
errors++;
}
else {
if(data165 < 0 || isNaN(data165)){
const err449 = {instancePath:instancePath+"/compiled/plan/predicate/state/column",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/properties/column/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err449];
}
else {
vErrors.push(err449);
}
errors++;
}
}
}
}
var valid71 = _errs429 === errors;
}
else {
var valid71 = true;
}
if(valid71){
if(data164.value !== undefined){
let data166 = data164.value;
const _errs431 = errors;
if(typeof data166 !== "string"){
const err450 = {instancePath:instancePath+"/compiled/plan/predicate/state/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/properties/value/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err450];
}
else {
vErrors.push(err450);
}
errors++;
}
if(!(((((data166 === "missing") || (data166 === "null")) || (data166 === "type_error")) || (data166 === "value")) || (data166 === "conflict"))){
const err451 = {instancePath:instancePath+"/compiled/plan/predicate/state/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/properties/value/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[3].properties.compiled.properties.plan.properties.predicate.oneOf[1].properties.state.properties.value.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err451];
}
else {
vErrors.push(err451);
}
errors++;
}
var valid71 = _errs431 === errors;
}
else {
var valid71 = true;
}
}
}
}
}
else {
const err452 = {instancePath:instancePath+"/compiled/plan/predicate/state",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err453 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err453];
}
else {
vErrors.push(err453);
}
errors++;
}
}
var _valid10 = _errs423 === errors;
if(_valid10 && valid68){
valid68 = false;
passing3 = [passing3, 1];
}
else {
if(_valid10){
valid68 = true;
passing3 = 1;
if(props4 !== true){
props4 = true;
}
}
const _errs433 = errors;
if(errors === _errs433){
if(data162 && typeof data162 == "object" && !Array.isArray(data162)){
let missing46;
if((data162.compare === undefined) && (missing46 = "compare")){
const err454 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/required",keyword:"required",params:{missingProperty: missing46},message:"must have required property '"+missing46+"'"};
if(vErrors === null){
vErrors = [err454];
}
else {
vErrors.push(err454);
}
errors++;
}
else {
const _errs435 = errors;
for(const key46 in data162){
if(!(key46 === "compare")){
const err455 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key46},message:"must NOT have additional properties"};
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
if(_errs435 === errors){
if(data162.compare !== undefined){
let data167 = data162.compare;
const _errs436 = errors;
if(errors === _errs436){
if(data167 && typeof data167 == "object" && !Array.isArray(data167)){
let missing47;
if((((data167.column === undefined) && (missing47 = "column")) || ((data167.op === undefined) && (missing47 = "op"))) || ((data167.value === undefined) && (missing47 = "value"))){
const err456 = {instancePath:instancePath+"/compiled/plan/predicate/compare",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/required",keyword:"required",params:{missingProperty: missing47},message:"must have required property '"+missing47+"'"};
if(vErrors === null){
vErrors = [err456];
}
else {
vErrors.push(err456);
}
errors++;
}
else {
const _errs438 = errors;
for(const key47 in data167){
if(!(((key47 === "column") || (key47 === "op")) || (key47 === "value"))){
const err457 = {instancePath:instancePath+"/compiled/plan/predicate/compare",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key47},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err457];
}
else {
vErrors.push(err457);
}
errors++;
break;
}
}
if(_errs438 === errors){
if(data167.column !== undefined){
let data168 = data167.column;
const _errs439 = errors;
if(!(((typeof data168 == "number") && (!(data168 % 1) && !isNaN(data168))) && (isFinite(data168)))){
const err458 = {instancePath:instancePath+"/compiled/plan/predicate/compare/column",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/column/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err458];
}
else {
vErrors.push(err458);
}
errors++;
}
if(errors === _errs439){
if((typeof data168 == "number") && (isFinite(data168))){
if(data168 > 255 || isNaN(data168)){
const err459 = {instancePath:instancePath+"/compiled/plan/predicate/compare/column",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/column/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err459];
}
else {
vErrors.push(err459);
}
errors++;
}
else {
if(data168 < 0 || isNaN(data168)){
const err460 = {instancePath:instancePath+"/compiled/plan/predicate/compare/column",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/column/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err460];
}
else {
vErrors.push(err460);
}
errors++;
}
}
}
}
var valid73 = _errs439 === errors;
}
else {
var valid73 = true;
}
if(valid73){
if(data167.op !== undefined){
let data169 = data167.op;
const _errs441 = errors;
if(typeof data169 !== "string"){
const err461 = {instancePath:instancePath+"/compiled/plan/predicate/compare/op",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/op/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err461];
}
else {
vErrors.push(err461);
}
errors++;
}
if(!((((((data169 === "eq") || (data169 === "ne")) || (data169 === "lt")) || (data169 === "le")) || (data169 === "gt")) || (data169 === "ge"))){
const err462 = {instancePath:instancePath+"/compiled/plan/predicate/compare/op",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/op/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[3].properties.compiled.properties.plan.properties.predicate.oneOf[2].properties.compare.properties.op.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err462];
}
else {
vErrors.push(err462);
}
errors++;
}
var valid73 = _errs441 === errors;
}
else {
var valid73 = true;
}
if(valid73){
if(data167.value !== undefined){
let data170 = data167.value;
const _errs443 = errors;
const _errs444 = errors;
let valid74 = false;
let passing4 = null;
const _errs445 = errors;
if(errors === _errs445){
if(data170 && typeof data170 == "object" && !Array.isArray(data170)){
let missing48;
if((data170.int64 === undefined) && (missing48 = "int64")){
const err463 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/0/required",keyword:"required",params:{missingProperty: missing48},message:"must have required property '"+missing48+"'"};
if(vErrors === null){
vErrors = [err463];
}
else {
vErrors.push(err463);
}
errors++;
}
else {
const _errs447 = errors;
for(const key48 in data170){
if(!(key48 === "int64")){
const err464 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key48},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err464];
}
else {
vErrors.push(err464);
}
errors++;
break;
}
}
if(_errs447 === errors){
if(data170.int64 !== undefined){
let data171 = data170.int64;
const _errs448 = errors;
if(errors === _errs448){
if(typeof data171 === "string"){
if(func1(data171) > 131072){
const err465 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/int64",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/0/properties/int64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err465];
}
else {
vErrors.push(err465);
}
errors++;
}
}
else {
const err466 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/int64",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/0/properties/int64/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err466];
}
else {
vErrors.push(err466);
}
errors++;
}
}
}
}
}
}
else {
const err467 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err467];
}
else {
vErrors.push(err467);
}
errors++;
}
}
var _valid11 = _errs445 === errors;
if(_valid11){
valid74 = true;
passing4 = 0;
var props5 = true;
}
const _errs450 = errors;
if(errors === _errs450){
if(data170 && typeof data170 == "object" && !Array.isArray(data170)){
let missing49;
if((data170.uint64 === undefined) && (missing49 = "uint64")){
const err468 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/1/required",keyword:"required",params:{missingProperty: missing49},message:"must have required property '"+missing49+"'"};
if(vErrors === null){
vErrors = [err468];
}
else {
vErrors.push(err468);
}
errors++;
}
else {
const _errs452 = errors;
for(const key49 in data170){
if(!(key49 === "uint64")){
const err469 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key49},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err469];
}
else {
vErrors.push(err469);
}
errors++;
break;
}
}
if(_errs452 === errors){
if(data170.uint64 !== undefined){
let data172 = data170.uint64;
const _errs453 = errors;
if(errors === _errs453){
if(typeof data172 === "string"){
if(func1(data172) > 131072){
const err470 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/uint64",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/1/properties/uint64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err470];
}
else {
vErrors.push(err470);
}
errors++;
}
}
else {
const err471 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/uint64",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/1/properties/uint64/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err471];
}
else {
vErrors.push(err471);
}
errors++;
}
}
}
}
}
}
else {
const err472 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err472];
}
else {
vErrors.push(err472);
}
errors++;
}
}
var _valid11 = _errs450 === errors;
if(_valid11 && valid74){
valid74 = false;
passing4 = [passing4, 1];
}
else {
if(_valid11){
valid74 = true;
passing4 = 1;
if(props5 !== true){
props5 = true;
}
}
const _errs455 = errors;
if(errors === _errs455){
if(data170 && typeof data170 == "object" && !Array.isArray(data170)){
let missing50;
if((data170.float_bits === undefined) && (missing50 = "float_bits")){
const err473 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/2/required",keyword:"required",params:{missingProperty: missing50},message:"must have required property '"+missing50+"'"};
if(vErrors === null){
vErrors = [err473];
}
else {
vErrors.push(err473);
}
errors++;
}
else {
const _errs457 = errors;
for(const key50 in data170){
if(!(key50 === "float_bits")){
const err474 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key50},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err474];
}
else {
vErrors.push(err474);
}
errors++;
break;
}
}
if(_errs457 === errors){
if(data170.float_bits !== undefined){
let data173 = data170.float_bits;
const _errs458 = errors;
if(errors === _errs458){
if(typeof data173 === "string"){
if(func1(data173) > 131072){
const err475 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/float_bits",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/2/properties/float_bits/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err475];
}
else {
vErrors.push(err475);
}
errors++;
}
}
else {
const err476 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/float_bits",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/2/properties/float_bits/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
}
}
else {
const err477 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err477];
}
else {
vErrors.push(err477);
}
errors++;
}
}
var _valid11 = _errs455 === errors;
if(_valid11 && valid74){
valid74 = false;
passing4 = [passing4, 2];
}
else {
if(_valid11){
valid74 = true;
passing4 = 2;
if(props5 !== true){
props5 = true;
}
}
const _errs460 = errors;
if(errors === _errs460){
if(data170 && typeof data170 == "object" && !Array.isArray(data170)){
let missing51;
if((data170.boolean === undefined) && (missing51 = "boolean")){
const err478 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/3/required",keyword:"required",params:{missingProperty: missing51},message:"must have required property '"+missing51+"'"};
if(vErrors === null){
vErrors = [err478];
}
else {
vErrors.push(err478);
}
errors++;
}
else {
const _errs462 = errors;
for(const key51 in data170){
if(!(key51 === "boolean")){
const err479 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key51},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err479];
}
else {
vErrors.push(err479);
}
errors++;
break;
}
}
if(_errs462 === errors){
if(data170.boolean !== undefined){
if(typeof data170.boolean !== "boolean"){
const err480 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/boolean",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/3/properties/boolean/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err480];
}
else {
vErrors.push(err480);
}
errors++;
}
}
}
}
}
else {
const err481 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err481];
}
else {
vErrors.push(err481);
}
errors++;
}
}
var _valid11 = _errs460 === errors;
if(_valid11 && valid74){
valid74 = false;
passing4 = [passing4, 3];
}
else {
if(_valid11){
valid74 = true;
passing4 = 3;
if(props5 !== true){
props5 = true;
}
}
const _errs465 = errors;
if(errors === _errs465){
if(data170 && typeof data170 == "object" && !Array.isArray(data170)){
let missing52;
if((data170.utf8 === undefined) && (missing52 = "utf8")){
const err482 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/4/required",keyword:"required",params:{missingProperty: missing52},message:"must have required property '"+missing52+"'"};
if(vErrors === null){
vErrors = [err482];
}
else {
vErrors.push(err482);
}
errors++;
}
else {
const _errs467 = errors;
for(const key52 in data170){
if(!(key52 === "utf8")){
const err483 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key52},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err483];
}
else {
vErrors.push(err483);
}
errors++;
break;
}
}
if(_errs467 === errors){
if(data170.utf8 !== undefined){
let data175 = data170.utf8;
const _errs468 = errors;
if(errors === _errs468){
if(typeof data175 === "string"){
if(func1(data175) > 131072){
const err484 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/utf8",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/4/properties/utf8/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err484];
}
else {
vErrors.push(err484);
}
errors++;
}
}
else {
const err485 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/utf8",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/4/properties/utf8/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
const err486 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err486];
}
else {
vErrors.push(err486);
}
errors++;
}
}
var _valid11 = _errs465 === errors;
if(_valid11 && valid74){
valid74 = false;
passing4 = [passing4, 4];
}
else {
if(_valid11){
valid74 = true;
passing4 = 4;
if(props5 !== true){
props5 = true;
}
}
const _errs470 = errors;
if(errors === _errs470){
if(data170 && typeof data170 == "object" && !Array.isArray(data170)){
let missing53;
if((data170.binary === undefined) && (missing53 = "binary")){
const err487 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/5/required",keyword:"required",params:{missingProperty: missing53},message:"must have required property '"+missing53+"'"};
if(vErrors === null){
vErrors = [err487];
}
else {
vErrors.push(err487);
}
errors++;
}
else {
const _errs472 = errors;
for(const key53 in data170){
if(!(key53 === "binary")){
const err488 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key53},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err488];
}
else {
vErrors.push(err488);
}
errors++;
break;
}
}
if(_errs472 === errors){
if(data170.binary !== undefined){
let data176 = data170.binary;
const _errs473 = errors;
if(errors === _errs473){
if(typeof data176 === "string"){
if(func1(data176) > 131072){
const err489 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/binary",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/5/properties/binary/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err489];
}
else {
vErrors.push(err489);
}
errors++;
}
}
else {
const err490 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/binary",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/5/properties/binary/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err490];
}
else {
vErrors.push(err490);
}
errors++;
}
}
}
}
}
}
else {
const err491 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err491];
}
else {
vErrors.push(err491);
}
errors++;
}
}
var _valid11 = _errs470 === errors;
if(_valid11 && valid74){
valid74 = false;
passing4 = [passing4, 5];
}
else {
if(_valid11){
valid74 = true;
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
if(!valid74){
const err492 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf",keyword:"oneOf",params:{passingSchemas: passing4},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err492];
}
else {
vErrors.push(err492);
}
errors++;
}
else {
errors = _errs444;
if(vErrors !== null){
if(_errs444){
vErrors.length = _errs444;
}
else {
vErrors = null;
}
}
}
var valid73 = _errs443 === errors;
}
else {
var valid73 = true;
}
}
}
}
}
}
else {
const err493 = {instancePath:instancePath+"/compiled/plan/predicate/compare",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err493];
}
else {
vErrors.push(err493);
}
errors++;
}
}
}
}
}
}
else {
const err494 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err494];
}
else {
vErrors.push(err494);
}
errors++;
}
}
var _valid10 = _errs433 === errors;
if(_valid10 && valid68){
valid68 = false;
passing3 = [passing3, 2];
}
else {
if(_valid10){
valid68 = true;
passing3 = 2;
if(props4 !== true){
props4 = true;
}
}
const _errs475 = errors;
if(errors === _errs475){
if(data162 && typeof data162 == "object" && !Array.isArray(data162)){
let missing54;
if((data162.program === undefined) && (missing54 = "program")){
const err495 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/required",keyword:"required",params:{missingProperty: missing54},message:"must have required property '"+missing54+"'"};
if(vErrors === null){
vErrors = [err495];
}
else {
vErrors.push(err495);
}
errors++;
}
else {
const _errs477 = errors;
for(const key54 in data162){
if(!(key54 === "program")){
const err496 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key54},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err496];
}
else {
vErrors.push(err496);
}
errors++;
break;
}
}
if(_errs477 === errors){
if(data162.program !== undefined){
let data177 = data162.program;
const _errs478 = errors;
if(errors === _errs478){
if(Array.isArray(data177)){
if(data177.length > 64){
const err497 = {instancePath:instancePath+"/compiled/plan/predicate/program",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/maxItems",keyword:"maxItems",params:{limit: 64},message:"must NOT have more than 64 items"};
if(vErrors === null){
vErrors = [err497];
}
else {
vErrors.push(err497);
}
errors++;
}
else {
var valid82 = true;
const len15 = data177.length;
for(let i15=0; i15<len15; i15++){
let data178 = data177[i15];
const _errs480 = errors;
const _errs481 = errors;
let valid83 = false;
let passing5 = null;
const _errs482 = errors;
if(errors === _errs482){
if(data178 && typeof data178 == "object" && !Array.isArray(data178)){
let missing55;
if((data178.atom === undefined) && (missing55 = "atom")){
const err498 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15,schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/required",keyword:"required",params:{missingProperty: missing55},message:"must have required property '"+missing55+"'"};
if(vErrors === null){
vErrors = [err498];
}
else {
vErrors.push(err498);
}
errors++;
}
else {
const _errs484 = errors;
for(const key55 in data178){
if(!(key55 === "atom")){
const err499 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15,schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key55},message:"must NOT have additional properties"};
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
if(_errs484 === errors){
if(data178.atom !== undefined){
let data179 = data178.atom;
const _errs486 = errors;
let valid85 = false;
let passing6 = null;
const _errs487 = errors;
if(errors === _errs487){
if(data179 && typeof data179 == "object" && !Array.isArray(data179)){
let missing56;
if((data179.all === undefined) && (missing56 = "all")){
const err500 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/0/required",keyword:"required",params:{missingProperty: missing56},message:"must have required property '"+missing56+"'"};
if(vErrors === null){
vErrors = [err500];
}
else {
vErrors.push(err500);
}
errors++;
}
else {
const _errs489 = errors;
for(const key56 in data179){
if(!(key56 === "all")){
const err501 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key56},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err501];
}
else {
vErrors.push(err501);
}
errors++;
break;
}
}
if(_errs489 === errors){
if(data179.all !== undefined){
let data180 = data179.all;
const _errs490 = errors;
if(errors === _errs490){
if(data180 && typeof data180 == "object" && !Array.isArray(data180)){
if(Object.keys(data180).length > 0){
const err502 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/all",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/0/properties/all/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err502];
}
else {
vErrors.push(err502);
}
errors++;
}
}
else {
const err503 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/all",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/0/properties/all/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err503];
}
else {
vErrors.push(err503);
}
errors++;
}
}
}
}
}
}
else {
const err504 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err504];
}
else {
vErrors.push(err504);
}
errors++;
}
}
var _valid13 = _errs487 === errors;
if(_valid13){
valid85 = true;
passing6 = 0;
var props6 = true;
}
const _errs492 = errors;
if(errors === _errs492){
if(data179 && typeof data179 == "object" && !Array.isArray(data179)){
let missing57;
if((data179.state === undefined) && (missing57 = "state")){
const err505 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/required",keyword:"required",params:{missingProperty: missing57},message:"must have required property '"+missing57+"'"};
if(vErrors === null){
vErrors = [err505];
}
else {
vErrors.push(err505);
}
errors++;
}
else {
const _errs494 = errors;
for(const key57 in data179){
if(!(key57 === "state")){
const err506 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key57},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err506];
}
else {
vErrors.push(err506);
}
errors++;
break;
}
}
if(_errs494 === errors){
if(data179.state !== undefined){
let data181 = data179.state;
const _errs495 = errors;
if(errors === _errs495){
if(data181 && typeof data181 == "object" && !Array.isArray(data181)){
let missing58;
if(((data181.column === undefined) && (missing58 = "column")) || ((data181.value === undefined) && (missing58 = "value"))){
const err507 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/state",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/properties/state/required",keyword:"required",params:{missingProperty: missing58},message:"must have required property '"+missing58+"'"};
if(vErrors === null){
vErrors = [err507];
}
else {
vErrors.push(err507);
}
errors++;
}
else {
const _errs497 = errors;
for(const key58 in data181){
if(!((key58 === "column") || (key58 === "value"))){
const err508 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/state",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/properties/state/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key58},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err508];
}
else {
vErrors.push(err508);
}
errors++;
break;
}
}
if(_errs497 === errors){
if(data181.column !== undefined){
let data182 = data181.column;
const _errs498 = errors;
if(!(((typeof data182 == "number") && (!(data182 % 1) && !isNaN(data182))) && (isFinite(data182)))){
const err509 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/state/column",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/properties/state/properties/column/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err509];
}
else {
vErrors.push(err509);
}
errors++;
}
if(errors === _errs498){
if((typeof data182 == "number") && (isFinite(data182))){
if(data182 > 255 || isNaN(data182)){
const err510 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/state/column",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/properties/state/properties/column/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err510];
}
else {
vErrors.push(err510);
}
errors++;
}
else {
if(data182 < 0 || isNaN(data182)){
const err511 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/state/column",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/properties/state/properties/column/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err511];
}
else {
vErrors.push(err511);
}
errors++;
}
}
}
}
var valid88 = _errs498 === errors;
}
else {
var valid88 = true;
}
if(valid88){
if(data181.value !== undefined){
let data183 = data181.value;
const _errs500 = errors;
if(typeof data183 !== "string"){
const err512 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/state/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/properties/state/properties/value/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err512];
}
else {
vErrors.push(err512);
}
errors++;
}
if(!(((((data183 === "missing") || (data183 === "null")) || (data183 === "type_error")) || (data183 === "value")) || (data183 === "conflict"))){
const err513 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/state/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/properties/state/properties/value/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[3].properties.compiled.properties.plan.properties.predicate.oneOf[3].properties.program.items.oneOf[0].properties.atom.oneOf[1].properties.state.properties.value.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err513];
}
else {
vErrors.push(err513);
}
errors++;
}
var valid88 = _errs500 === errors;
}
else {
var valid88 = true;
}
}
}
}
}
else {
const err514 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/state",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/properties/state/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err514];
}
else {
vErrors.push(err514);
}
errors++;
}
}
}
}
}
}
else {
const err515 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err515];
}
else {
vErrors.push(err515);
}
errors++;
}
}
var _valid13 = _errs492 === errors;
if(_valid13 && valid85){
valid85 = false;
passing6 = [passing6, 1];
}
else {
if(_valid13){
valid85 = true;
passing6 = 1;
if(props6 !== true){
props6 = true;
}
}
const _errs502 = errors;
if(errors === _errs502){
if(data179 && typeof data179 == "object" && !Array.isArray(data179)){
let missing59;
if((data179.compare === undefined) && (missing59 = "compare")){
const err516 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/required",keyword:"required",params:{missingProperty: missing59},message:"must have required property '"+missing59+"'"};
if(vErrors === null){
vErrors = [err516];
}
else {
vErrors.push(err516);
}
errors++;
}
else {
const _errs504 = errors;
for(const key59 in data179){
if(!(key59 === "compare")){
const err517 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key59},message:"must NOT have additional properties"};
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
if(_errs504 === errors){
if(data179.compare !== undefined){
let data184 = data179.compare;
const _errs505 = errors;
if(errors === _errs505){
if(data184 && typeof data184 == "object" && !Array.isArray(data184)){
let missing60;
if((((data184.column === undefined) && (missing60 = "column")) || ((data184.op === undefined) && (missing60 = "op"))) || ((data184.value === undefined) && (missing60 = "value"))){
const err518 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/required",keyword:"required",params:{missingProperty: missing60},message:"must have required property '"+missing60+"'"};
if(vErrors === null){
vErrors = [err518];
}
else {
vErrors.push(err518);
}
errors++;
}
else {
const _errs507 = errors;
for(const key60 in data184){
if(!(((key60 === "column") || (key60 === "op")) || (key60 === "value"))){
const err519 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key60},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err519];
}
else {
vErrors.push(err519);
}
errors++;
break;
}
}
if(_errs507 === errors){
if(data184.column !== undefined){
let data185 = data184.column;
const _errs508 = errors;
if(!(((typeof data185 == "number") && (!(data185 % 1) && !isNaN(data185))) && (isFinite(data185)))){
const err520 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/column",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/column/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err520];
}
else {
vErrors.push(err520);
}
errors++;
}
if(errors === _errs508){
if((typeof data185 == "number") && (isFinite(data185))){
if(data185 > 255 || isNaN(data185)){
const err521 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/column",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/column/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err521];
}
else {
vErrors.push(err521);
}
errors++;
}
else {
if(data185 < 0 || isNaN(data185)){
const err522 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/column",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/column/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err522];
}
else {
vErrors.push(err522);
}
errors++;
}
}
}
}
var valid90 = _errs508 === errors;
}
else {
var valid90 = true;
}
if(valid90){
if(data184.op !== undefined){
let data186 = data184.op;
const _errs510 = errors;
if(typeof data186 !== "string"){
const err523 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/op",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/op/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err523];
}
else {
vErrors.push(err523);
}
errors++;
}
if(!((((((data186 === "eq") || (data186 === "ne")) || (data186 === "lt")) || (data186 === "le")) || (data186 === "gt")) || (data186 === "ge"))){
const err524 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/op",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/op/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[3].properties.compiled.properties.plan.properties.predicate.oneOf[3].properties.program.items.oneOf[0].properties.atom.oneOf[2].properties.compare.properties.op.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err524];
}
else {
vErrors.push(err524);
}
errors++;
}
var valid90 = _errs510 === errors;
}
else {
var valid90 = true;
}
if(valid90){
if(data184.value !== undefined){
let data187 = data184.value;
const _errs512 = errors;
const _errs513 = errors;
let valid91 = false;
let passing7 = null;
const _errs514 = errors;
if(errors === _errs514){
if(data187 && typeof data187 == "object" && !Array.isArray(data187)){
let missing61;
if((data187.int64 === undefined) && (missing61 = "int64")){
const err525 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/0/required",keyword:"required",params:{missingProperty: missing61},message:"must have required property '"+missing61+"'"};
if(vErrors === null){
vErrors = [err525];
}
else {
vErrors.push(err525);
}
errors++;
}
else {
const _errs516 = errors;
for(const key61 in data187){
if(!(key61 === "int64")){
const err526 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key61},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err526];
}
else {
vErrors.push(err526);
}
errors++;
break;
}
}
if(_errs516 === errors){
if(data187.int64 !== undefined){
let data188 = data187.int64;
const _errs517 = errors;
if(errors === _errs517){
if(typeof data188 === "string"){
if(func1(data188) > 131072){
const err527 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value/int64",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/0/properties/int64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err527];
}
else {
vErrors.push(err527);
}
errors++;
}
}
else {
const err528 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value/int64",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/0/properties/int64/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err528];
}
else {
vErrors.push(err528);
}
errors++;
}
}
}
}
}
}
else {
const err529 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err529];
}
else {
vErrors.push(err529);
}
errors++;
}
}
var _valid14 = _errs514 === errors;
if(_valid14){
valid91 = true;
passing7 = 0;
var props7 = true;
}
const _errs519 = errors;
if(errors === _errs519){
if(data187 && typeof data187 == "object" && !Array.isArray(data187)){
let missing62;
if((data187.uint64 === undefined) && (missing62 = "uint64")){
const err530 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/1/required",keyword:"required",params:{missingProperty: missing62},message:"must have required property '"+missing62+"'"};
if(vErrors === null){
vErrors = [err530];
}
else {
vErrors.push(err530);
}
errors++;
}
else {
const _errs521 = errors;
for(const key62 in data187){
if(!(key62 === "uint64")){
const err531 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key62},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err531];
}
else {
vErrors.push(err531);
}
errors++;
break;
}
}
if(_errs521 === errors){
if(data187.uint64 !== undefined){
let data189 = data187.uint64;
const _errs522 = errors;
if(errors === _errs522){
if(typeof data189 === "string"){
if(func1(data189) > 131072){
const err532 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value/uint64",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/1/properties/uint64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err532];
}
else {
vErrors.push(err532);
}
errors++;
}
}
else {
const err533 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value/uint64",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/1/properties/uint64/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err533];
}
else {
vErrors.push(err533);
}
errors++;
}
}
}
}
}
}
else {
const err534 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err534];
}
else {
vErrors.push(err534);
}
errors++;
}
}
var _valid14 = _errs519 === errors;
if(_valid14 && valid91){
valid91 = false;
passing7 = [passing7, 1];
}
else {
if(_valid14){
valid91 = true;
passing7 = 1;
if(props7 !== true){
props7 = true;
}
}
const _errs524 = errors;
if(errors === _errs524){
if(data187 && typeof data187 == "object" && !Array.isArray(data187)){
let missing63;
if((data187.float_bits === undefined) && (missing63 = "float_bits")){
const err535 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/2/required",keyword:"required",params:{missingProperty: missing63},message:"must have required property '"+missing63+"'"};
if(vErrors === null){
vErrors = [err535];
}
else {
vErrors.push(err535);
}
errors++;
}
else {
const _errs526 = errors;
for(const key63 in data187){
if(!(key63 === "float_bits")){
const err536 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key63},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err536];
}
else {
vErrors.push(err536);
}
errors++;
break;
}
}
if(_errs526 === errors){
if(data187.float_bits !== undefined){
let data190 = data187.float_bits;
const _errs527 = errors;
if(errors === _errs527){
if(typeof data190 === "string"){
if(func1(data190) > 131072){
const err537 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value/float_bits",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/2/properties/float_bits/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err537];
}
else {
vErrors.push(err537);
}
errors++;
}
}
else {
const err538 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value/float_bits",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/2/properties/float_bits/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
}
}
else {
const err539 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err539];
}
else {
vErrors.push(err539);
}
errors++;
}
}
var _valid14 = _errs524 === errors;
if(_valid14 && valid91){
valid91 = false;
passing7 = [passing7, 2];
}
else {
if(_valid14){
valid91 = true;
passing7 = 2;
if(props7 !== true){
props7 = true;
}
}
const _errs529 = errors;
if(errors === _errs529){
if(data187 && typeof data187 == "object" && !Array.isArray(data187)){
let missing64;
if((data187.boolean === undefined) && (missing64 = "boolean")){
const err540 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/3/required",keyword:"required",params:{missingProperty: missing64},message:"must have required property '"+missing64+"'"};
if(vErrors === null){
vErrors = [err540];
}
else {
vErrors.push(err540);
}
errors++;
}
else {
const _errs531 = errors;
for(const key64 in data187){
if(!(key64 === "boolean")){
const err541 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key64},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err541];
}
else {
vErrors.push(err541);
}
errors++;
break;
}
}
if(_errs531 === errors){
if(data187.boolean !== undefined){
if(typeof data187.boolean !== "boolean"){
const err542 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value/boolean",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/3/properties/boolean/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
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
}
else {
const err543 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err543];
}
else {
vErrors.push(err543);
}
errors++;
}
}
var _valid14 = _errs529 === errors;
if(_valid14 && valid91){
valid91 = false;
passing7 = [passing7, 3];
}
else {
if(_valid14){
valid91 = true;
passing7 = 3;
if(props7 !== true){
props7 = true;
}
}
const _errs534 = errors;
if(errors === _errs534){
if(data187 && typeof data187 == "object" && !Array.isArray(data187)){
let missing65;
if((data187.utf8 === undefined) && (missing65 = "utf8")){
const err544 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/4/required",keyword:"required",params:{missingProperty: missing65},message:"must have required property '"+missing65+"'"};
if(vErrors === null){
vErrors = [err544];
}
else {
vErrors.push(err544);
}
errors++;
}
else {
const _errs536 = errors;
for(const key65 in data187){
if(!(key65 === "utf8")){
const err545 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key65},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err545];
}
else {
vErrors.push(err545);
}
errors++;
break;
}
}
if(_errs536 === errors){
if(data187.utf8 !== undefined){
let data192 = data187.utf8;
const _errs537 = errors;
if(errors === _errs537){
if(typeof data192 === "string"){
if(func1(data192) > 131072){
const err546 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value/utf8",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/4/properties/utf8/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err546];
}
else {
vErrors.push(err546);
}
errors++;
}
}
else {
const err547 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value/utf8",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/4/properties/utf8/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err547];
}
else {
vErrors.push(err547);
}
errors++;
}
}
}
}
}
}
else {
const err548 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err548];
}
else {
vErrors.push(err548);
}
errors++;
}
}
var _valid14 = _errs534 === errors;
if(_valid14 && valid91){
valid91 = false;
passing7 = [passing7, 4];
}
else {
if(_valid14){
valid91 = true;
passing7 = 4;
if(props7 !== true){
props7 = true;
}
}
const _errs539 = errors;
if(errors === _errs539){
if(data187 && typeof data187 == "object" && !Array.isArray(data187)){
let missing66;
if((data187.binary === undefined) && (missing66 = "binary")){
const err549 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/5/required",keyword:"required",params:{missingProperty: missing66},message:"must have required property '"+missing66+"'"};
if(vErrors === null){
vErrors = [err549];
}
else {
vErrors.push(err549);
}
errors++;
}
else {
const _errs541 = errors;
for(const key66 in data187){
if(!(key66 === "binary")){
const err550 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key66},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err550];
}
else {
vErrors.push(err550);
}
errors++;
break;
}
}
if(_errs541 === errors){
if(data187.binary !== undefined){
let data193 = data187.binary;
const _errs542 = errors;
if(errors === _errs542){
if(typeof data193 === "string"){
if(func1(data193) > 131072){
const err551 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value/binary",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/5/properties/binary/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err551];
}
else {
vErrors.push(err551);
}
errors++;
}
}
else {
const err552 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value/binary",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/5/properties/binary/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err552];
}
else {
vErrors.push(err552);
}
errors++;
}
}
}
}
}
}
else {
const err553 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err553];
}
else {
vErrors.push(err553);
}
errors++;
}
}
var _valid14 = _errs539 === errors;
if(_valid14 && valid91){
valid91 = false;
passing7 = [passing7, 5];
}
else {
if(_valid14){
valid91 = true;
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
if(!valid91){
const err554 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf",keyword:"oneOf",params:{passingSchemas: passing7},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err554];
}
else {
vErrors.push(err554);
}
errors++;
}
else {
errors = _errs513;
if(vErrors !== null){
if(_errs513){
vErrors.length = _errs513;
}
else {
vErrors = null;
}
}
}
var valid90 = _errs512 === errors;
}
else {
var valid90 = true;
}
}
}
}
}
}
else {
const err555 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err555];
}
else {
vErrors.push(err555);
}
errors++;
}
}
}
}
}
}
else {
const err556 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err556];
}
else {
vErrors.push(err556);
}
errors++;
}
}
var _valid13 = _errs502 === errors;
if(_valid13 && valid85){
valid85 = false;
passing6 = [passing6, 2];
}
else {
if(_valid13){
valid85 = true;
passing6 = 2;
if(props6 !== true){
props6 = true;
}
}
}
}
if(!valid85){
const err557 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf",keyword:"oneOf",params:{passingSchemas: passing6},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err557];
}
else {
vErrors.push(err557);
}
errors++;
}
else {
errors = _errs486;
if(vErrors !== null){
if(_errs486){
vErrors.length = _errs486;
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
const err558 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15,schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err558];
}
else {
vErrors.push(err558);
}
errors++;
}
}
var _valid12 = _errs482 === errors;
if(_valid12){
valid83 = true;
passing5 = 0;
var props8 = true;
}
const _errs544 = errors;
if(errors === _errs544){
if(data178 && typeof data178 == "object" && !Array.isArray(data178)){
let missing67;
if((data178.negate === undefined) && (missing67 = "negate")){
const err559 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15,schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/1/required",keyword:"required",params:{missingProperty: missing67},message:"must have required property '"+missing67+"'"};
if(vErrors === null){
vErrors = [err559];
}
else {
vErrors.push(err559);
}
errors++;
}
else {
const _errs546 = errors;
for(const key67 in data178){
if(!(key67 === "negate")){
const err560 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15,schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key67},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err560];
}
else {
vErrors.push(err560);
}
errors++;
break;
}
}
if(_errs546 === errors){
if(data178.negate !== undefined){
let data194 = data178.negate;
const _errs547 = errors;
if(errors === _errs547){
if(data194 && typeof data194 == "object" && !Array.isArray(data194)){
if(Object.keys(data194).length > 0){
const err561 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/negate",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/1/properties/negate/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err561];
}
else {
vErrors.push(err561);
}
errors++;
}
}
else {
const err562 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/negate",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/1/properties/negate/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err562];
}
else {
vErrors.push(err562);
}
errors++;
}
}
}
}
}
}
else {
const err563 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15,schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err563];
}
else {
vErrors.push(err563);
}
errors++;
}
}
var _valid12 = _errs544 === errors;
if(_valid12 && valid83){
valid83 = false;
passing5 = [passing5, 1];
}
else {
if(_valid12){
valid83 = true;
passing5 = 1;
if(props8 !== true){
props8 = true;
}
}
const _errs549 = errors;
if(errors === _errs549){
if(data178 && typeof data178 == "object" && !Array.isArray(data178)){
let missing68;
if((data178.conjunction === undefined) && (missing68 = "conjunction")){
const err564 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15,schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/2/required",keyword:"required",params:{missingProperty: missing68},message:"must have required property '"+missing68+"'"};
if(vErrors === null){
vErrors = [err564];
}
else {
vErrors.push(err564);
}
errors++;
}
else {
const _errs551 = errors;
for(const key68 in data178){
if(!(key68 === "conjunction")){
const err565 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15,schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key68},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err565];
}
else {
vErrors.push(err565);
}
errors++;
break;
}
}
if(_errs551 === errors){
if(data178.conjunction !== undefined){
let data195 = data178.conjunction;
const _errs552 = errors;
if(errors === _errs552){
if(data195 && typeof data195 == "object" && !Array.isArray(data195)){
if(Object.keys(data195).length > 0){
const err566 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/conjunction",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/2/properties/conjunction/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err566];
}
else {
vErrors.push(err566);
}
errors++;
}
}
else {
const err567 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/conjunction",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/2/properties/conjunction/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err567];
}
else {
vErrors.push(err567);
}
errors++;
}
}
}
}
}
}
else {
const err568 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15,schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err568];
}
else {
vErrors.push(err568);
}
errors++;
}
}
var _valid12 = _errs549 === errors;
if(_valid12 && valid83){
valid83 = false;
passing5 = [passing5, 2];
}
else {
if(_valid12){
valid83 = true;
passing5 = 2;
if(props8 !== true){
props8 = true;
}
}
const _errs554 = errors;
if(errors === _errs554){
if(data178 && typeof data178 == "object" && !Array.isArray(data178)){
let missing69;
if((data178.disjunction === undefined) && (missing69 = "disjunction")){
const err569 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15,schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/3/required",keyword:"required",params:{missingProperty: missing69},message:"must have required property '"+missing69+"'"};
if(vErrors === null){
vErrors = [err569];
}
else {
vErrors.push(err569);
}
errors++;
}
else {
const _errs556 = errors;
for(const key69 in data178){
if(!(key69 === "disjunction")){
const err570 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15,schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key69},message:"must NOT have additional properties"};
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
if(_errs556 === errors){
if(data178.disjunction !== undefined){
let data196 = data178.disjunction;
const _errs557 = errors;
if(errors === _errs557){
if(data196 && typeof data196 == "object" && !Array.isArray(data196)){
if(Object.keys(data196).length > 0){
const err571 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/disjunction",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/3/properties/disjunction/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err571];
}
else {
vErrors.push(err571);
}
errors++;
}
}
else {
const err572 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/disjunction",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/3/properties/disjunction/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err572];
}
else {
vErrors.push(err572);
}
errors++;
}
}
}
}
}
}
else {
const err573 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15,schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err573];
}
else {
vErrors.push(err573);
}
errors++;
}
}
var _valid12 = _errs554 === errors;
if(_valid12 && valid83){
valid83 = false;
passing5 = [passing5, 3];
}
else {
if(_valid12){
valid83 = true;
passing5 = 3;
if(props8 !== true){
props8 = true;
}
}
}
}
}
if(!valid83){
const err574 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15,schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf",keyword:"oneOf",params:{passingSchemas: passing5},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err574];
}
else {
vErrors.push(err574);
}
errors++;
}
else {
errors = _errs481;
if(vErrors !== null){
if(_errs481){
vErrors.length = _errs481;
}
else {
vErrors = null;
}
}
}
var valid82 = _errs480 === errors;
if(!valid82){
break;
}
}
}
}
else {
const err575 = {instancePath:instancePath+"/compiled/plan/predicate/program",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err575];
}
else {
vErrors.push(err575);
}
errors++;
}
}
}
}
}
}
else {
const err576 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err576];
}
else {
vErrors.push(err576);
}
errors++;
}
}
var _valid10 = _errs475 === errors;
if(_valid10 && valid68){
valid68 = false;
passing3 = [passing3, 3];
}
else {
if(_valid10){
valid68 = true;
passing3 = 3;
if(props4 !== true){
props4 = true;
}
}
}
}
}
if(!valid68){
const err577 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/properties/predicate/oneOf",keyword:"oneOf",params:{passingSchemas: passing3},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err577];
}
else {
vErrors.push(err577);
}
errors++;
}
else {
errors = _errs417;
if(vErrors !== null){
if(_errs417){
vErrors.length = _errs417;
}
else {
vErrors = null;
}
}
}
var valid62 = _errs416 === errors;
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
}
else {
const err578 = {instancePath:instancePath+"/compiled/plan",schemaPath:"#/oneOf/3/properties/compiled/properties/plan/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err578];
}
else {
vErrors.push(err578);
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
let data197 = data114.limits;
const _errs559 = errors;
if(errors === _errs559){
if(data197 && typeof data197 == "object" && !Array.isArray(data197)){
let missing70;
if((((data197.pages === undefined) && (missing70 = "pages")) || ((data197.segments === undefined) && (missing70 = "segments"))) || ((data197.result_bytes === undefined) && (missing70 = "result_bytes"))){
const err579 = {instancePath:instancePath+"/compiled/limits",schemaPath:"#/oneOf/3/properties/compiled/properties/limits/required",keyword:"required",params:{missingProperty: missing70},message:"must have required property '"+missing70+"'"};
if(vErrors === null){
vErrors = [err579];
}
else {
vErrors.push(err579);
}
errors++;
}
else {
const _errs561 = errors;
for(const key70 in data197){
if(!(((key70 === "pages") || (key70 === "segments")) || (key70 === "result_bytes"))){
const err580 = {instancePath:instancePath+"/compiled/limits",schemaPath:"#/oneOf/3/properties/compiled/properties/limits/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key70},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err580];
}
else {
vErrors.push(err580);
}
errors++;
break;
}
}
if(_errs561 === errors){
if(data197.pages !== undefined){
let data198 = data197.pages;
const _errs562 = errors;
if(errors === _errs562){
if(typeof data198 === "string"){
if(func1(data198) > 131072){
const err581 = {instancePath:instancePath+"/compiled/limits/pages",schemaPath:"#/oneOf/3/properties/compiled/properties/limits/properties/pages/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err581];
}
else {
vErrors.push(err581);
}
errors++;
}
}
else {
const err582 = {instancePath:instancePath+"/compiled/limits/pages",schemaPath:"#/oneOf/3/properties/compiled/properties/limits/properties/pages/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err582];
}
else {
vErrors.push(err582);
}
errors++;
}
}
var valid101 = _errs562 === errors;
}
else {
var valid101 = true;
}
if(valid101){
if(data197.segments !== undefined){
let data199 = data197.segments;
const _errs564 = errors;
if(errors === _errs564){
if(typeof data199 === "string"){
if(func1(data199) > 131072){
const err583 = {instancePath:instancePath+"/compiled/limits/segments",schemaPath:"#/oneOf/3/properties/compiled/properties/limits/properties/segments/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err583];
}
else {
vErrors.push(err583);
}
errors++;
}
}
else {
const err584 = {instancePath:instancePath+"/compiled/limits/segments",schemaPath:"#/oneOf/3/properties/compiled/properties/limits/properties/segments/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err584];
}
else {
vErrors.push(err584);
}
errors++;
}
}
var valid101 = _errs564 === errors;
}
else {
var valid101 = true;
}
if(valid101){
if(data197.result_bytes !== undefined){
let data200 = data197.result_bytes;
const _errs566 = errors;
if(errors === _errs566){
if(typeof data200 === "string"){
if(func1(data200) > 131072){
const err585 = {instancePath:instancePath+"/compiled/limits/result_bytes",schemaPath:"#/oneOf/3/properties/compiled/properties/limits/properties/result_bytes/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err585];
}
else {
vErrors.push(err585);
}
errors++;
}
}
else {
const err586 = {instancePath:instancePath+"/compiled/limits/result_bytes",schemaPath:"#/oneOf/3/properties/compiled/properties/limits/properties/result_bytes/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err586];
}
else {
vErrors.push(err586);
}
errors++;
}
}
var valid101 = _errs566 === errors;
}
else {
var valid101 = true;
}
}
}
}
}
}
else {
const err587 = {instancePath:instancePath+"/compiled/limits",schemaPath:"#/oneOf/3/properties/compiled/properties/limits/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err587];
}
else {
vErrors.push(err587);
}
errors++;
}
}
var valid43 = _errs559 === errors;
}
else {
var valid43 = true;
}
if(valid43){
if(data114.contract !== undefined){
let data201 = data114.contract;
const _errs568 = errors;
if(errors === _errs568){
if(Array.isArray(data201)){
if(data201.length > 32){
const err588 = {instancePath:instancePath+"/compiled/contract",schemaPath:"#/oneOf/3/properties/compiled/properties/contract/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err588];
}
else {
vErrors.push(err588);
}
errors++;
}
else {
if(data201.length < 32){
const err589 = {instancePath:instancePath+"/compiled/contract",schemaPath:"#/oneOf/3/properties/compiled/properties/contract/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err589];
}
else {
vErrors.push(err589);
}
errors++;
}
else {
var valid102 = true;
const len16 = data201.length;
for(let i16=0; i16<len16; i16++){
let data202 = data201[i16];
const _errs570 = errors;
if(!(((typeof data202 == "number") && (!(data202 % 1) && !isNaN(data202))) && (isFinite(data202)))){
const err590 = {instancePath:instancePath+"/compiled/contract/" + i16,schemaPath:"#/oneOf/3/properties/compiled/properties/contract/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err590];
}
else {
vErrors.push(err590);
}
errors++;
}
if(errors === _errs570){
if((typeof data202 == "number") && (isFinite(data202))){
if(data202 > 255 || isNaN(data202)){
const err591 = {instancePath:instancePath+"/compiled/contract/" + i16,schemaPath:"#/oneOf/3/properties/compiled/properties/contract/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err591];
}
else {
vErrors.push(err591);
}
errors++;
}
else {
if(data202 < 0 || isNaN(data202)){
const err592 = {instancePath:instancePath+"/compiled/contract/" + i16,schemaPath:"#/oneOf/3/properties/compiled/properties/contract/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err592];
}
else {
vErrors.push(err592);
}
errors++;
}
}
}
}
var valid102 = _errs570 === errors;
if(!valid102){
break;
}
}
}
}
}
else {
const err593 = {instancePath:instancePath+"/compiled/contract",schemaPath:"#/oneOf/3/properties/compiled/properties/contract/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err593];
}
else {
vErrors.push(err593);
}
errors++;
}
}
var valid43 = _errs568 === errors;
}
else {
var valid43 = true;
}
if(valid43){
if(data114.schema !== undefined){
let data203 = data114.schema;
const _errs572 = errors;
if(errors === _errs572){
if(Array.isArray(data203)){
if(data203.length > 32){
const err594 = {instancePath:instancePath+"/compiled/schema",schemaPath:"#/oneOf/3/properties/compiled/properties/schema/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err594];
}
else {
vErrors.push(err594);
}
errors++;
}
else {
if(data203.length < 32){
const err595 = {instancePath:instancePath+"/compiled/schema",schemaPath:"#/oneOf/3/properties/compiled/properties/schema/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err595];
}
else {
vErrors.push(err595);
}
errors++;
}
else {
var valid103 = true;
const len17 = data203.length;
for(let i17=0; i17<len17; i17++){
let data204 = data203[i17];
const _errs574 = errors;
if(!(((typeof data204 == "number") && (!(data204 % 1) && !isNaN(data204))) && (isFinite(data204)))){
const err596 = {instancePath:instancePath+"/compiled/schema/" + i17,schemaPath:"#/oneOf/3/properties/compiled/properties/schema/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err596];
}
else {
vErrors.push(err596);
}
errors++;
}
if(errors === _errs574){
if((typeof data204 == "number") && (isFinite(data204))){
if(data204 > 255 || isNaN(data204)){
const err597 = {instancePath:instancePath+"/compiled/schema/" + i17,schemaPath:"#/oneOf/3/properties/compiled/properties/schema/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err597];
}
else {
vErrors.push(err597);
}
errors++;
}
else {
if(data204 < 0 || isNaN(data204)){
const err598 = {instancePath:instancePath+"/compiled/schema/" + i17,schemaPath:"#/oneOf/3/properties/compiled/properties/schema/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err598];
}
else {
vErrors.push(err598);
}
errors++;
}
}
}
}
var valid103 = _errs574 === errors;
if(!valid103){
break;
}
}
}
}
}
else {
const err599 = {instancePath:instancePath+"/compiled/schema",schemaPath:"#/oneOf/3/properties/compiled/properties/schema/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err599];
}
else {
vErrors.push(err599);
}
errors++;
}
}
var valid43 = _errs572 === errors;
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
const err600 = {instancePath:instancePath+"/compiled",schemaPath:"#/oneOf/3/properties/compiled/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err601 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err601];
}
else {
vErrors.push(err601);
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
const _errs576 = errors;
if(errors === _errs576){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing71;
if((data.inspection === undefined) && (missing71 = "inspection")){
const err602 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing71},message:"must have required property '"+missing71+"'"};
if(vErrors === null){
vErrors = [err602];
}
else {
vErrors.push(err602);
}
errors++;
}
else {
const _errs578 = errors;
for(const key71 in data){
if(!(key71 === "inspection")){
const err603 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key71},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err603];
}
else {
vErrors.push(err603);
}
errors++;
break;
}
}
if(_errs578 === errors){
if(data.inspection !== undefined){
let data205 = data.inspection;
const _errs579 = errors;
if(errors === _errs579){
if(data205 && typeof data205 == "object" && !Array.isArray(data205)){
let missing72;
if(((((((((((data205.version === undefined) && (missing72 = "version")) || ((data205.scope === undefined) && (missing72 = "scope"))) || ((data205.name === undefined) && (missing72 = "name"))) || ((data205.resource === undefined) && (missing72 = "resource"))) || ((data205.source_kind === undefined) && (missing72 = "source_kind"))) || ((data205.contract === undefined) && (missing72 = "contract"))) || ((data205.schema === undefined) && (missing72 = "schema"))) || ((data205.resource_revision === undefined) && (missing72 = "resource_revision"))) || ((data205.policy_revision === undefined) && (missing72 = "policy_revision"))) || ((data205.details === undefined) && (missing72 = "details"))){
const err604 = {instancePath:instancePath+"/inspection",schemaPath:"#/oneOf/4/properties/inspection/required",keyword:"required",params:{missingProperty: missing72},message:"must have required property '"+missing72+"'"};
if(vErrors === null){
vErrors = [err604];
}
else {
vErrors.push(err604);
}
errors++;
}
else {
const _errs581 = errors;
for(const key72 in data205){
if(!(func19.call(schema33.oneOf[4].properties.inspection.properties, key72))){
const err605 = {instancePath:instancePath+"/inspection",schemaPath:"#/oneOf/4/properties/inspection/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key72},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err605];
}
else {
vErrors.push(err605);
}
errors++;
break;
}
}
if(_errs581 === errors){
if(data205.version !== undefined){
let data206 = data205.version;
const _errs582 = errors;
if(!(((typeof data206 == "number") && (!(data206 % 1) && !isNaN(data206))) && (isFinite(data206)))){
const err606 = {instancePath:instancePath+"/inspection/version",schemaPath:"#/oneOf/4/properties/inspection/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err606];
}
else {
vErrors.push(err606);
}
errors++;
}
if(errors === _errs582){
if((typeof data206 == "number") && (isFinite(data206))){
if(data206 > 255 || isNaN(data206)){
const err607 = {instancePath:instancePath+"/inspection/version",schemaPath:"#/oneOf/4/properties/inspection/properties/version/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err607];
}
else {
vErrors.push(err607);
}
errors++;
}
else {
if(data206 < 0 || isNaN(data206)){
const err608 = {instancePath:instancePath+"/inspection/version",schemaPath:"#/oneOf/4/properties/inspection/properties/version/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid105 = _errs582 === errors;
}
else {
var valid105 = true;
}
if(valid105){
if(data205.scope !== undefined){
let data207 = data205.scope;
const _errs584 = errors;
if(typeof data207 !== "string"){
const err609 = {instancePath:instancePath+"/inspection/scope",schemaPath:"#/oneOf/4/properties/inspection/properties/scope/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err609];
}
else {
vErrors.push(err609);
}
errors++;
}
if(!(data207 === "configured_source")){
const err610 = {instancePath:instancePath+"/inspection/scope",schemaPath:"#/oneOf/4/properties/inspection/properties/scope/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.inspection.properties.scope.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err610];
}
else {
vErrors.push(err610);
}
errors++;
}
var valid105 = _errs584 === errors;
}
else {
var valid105 = true;
}
if(valid105){
if(data205.name !== undefined){
let data208 = data205.name;
const _errs586 = errors;
if(errors === _errs586){
if(typeof data208 === "string"){
if(func1(data208) > 131072){
const err611 = {instancePath:instancePath+"/inspection/name",schemaPath:"#/oneOf/4/properties/inspection/properties/name/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err611];
}
else {
vErrors.push(err611);
}
errors++;
}
}
else {
const err612 = {instancePath:instancePath+"/inspection/name",schemaPath:"#/oneOf/4/properties/inspection/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err612];
}
else {
vErrors.push(err612);
}
errors++;
}
}
var valid105 = _errs586 === errors;
}
else {
var valid105 = true;
}
if(valid105){
if(data205.resource !== undefined){
let data209 = data205.resource;
const _errs588 = errors;
if(!(((typeof data209 == "number") && (!(data209 % 1) && !isNaN(data209))) && (isFinite(data209)))){
const err613 = {instancePath:instancePath+"/inspection/resource",schemaPath:"#/oneOf/4/properties/inspection/properties/resource/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err613];
}
else {
vErrors.push(err613);
}
errors++;
}
if(errors === _errs588){
if((typeof data209 == "number") && (isFinite(data209))){
if(data209 > 9007199254740991 || isNaN(data209)){
const err614 = {instancePath:instancePath+"/inspection/resource",schemaPath:"#/oneOf/4/properties/inspection/properties/resource/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err614];
}
else {
vErrors.push(err614);
}
errors++;
}
else {
if(data209 < 0 || isNaN(data209)){
const err615 = {instancePath:instancePath+"/inspection/resource",schemaPath:"#/oneOf/4/properties/inspection/properties/resource/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err615];
}
else {
vErrors.push(err615);
}
errors++;
}
}
}
}
var valid105 = _errs588 === errors;
}
else {
var valid105 = true;
}
if(valid105){
if(data205.source_kind !== undefined){
let data210 = data205.source_kind;
const _errs590 = errors;
if(typeof data210 !== "string"){
const err616 = {instancePath:instancePath+"/inspection/source_kind",schemaPath:"#/oneOf/4/properties/inspection/properties/source_kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err616];
}
else {
vErrors.push(err616);
}
errors++;
}
if(!(((data210 === "kv") || (data210 === "table")) || (data210 === "document"))){
const err617 = {instancePath:instancePath+"/inspection/source_kind",schemaPath:"#/oneOf/4/properties/inspection/properties/source_kind/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.inspection.properties.source_kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err617];
}
else {
vErrors.push(err617);
}
errors++;
}
var valid105 = _errs590 === errors;
}
else {
var valid105 = true;
}
if(valid105){
if(data205.contract !== undefined){
let data211 = data205.contract;
const _errs592 = errors;
if(errors === _errs592){
if(Array.isArray(data211)){
if(data211.length > 32){
const err618 = {instancePath:instancePath+"/inspection/contract",schemaPath:"#/oneOf/4/properties/inspection/properties/contract/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err618];
}
else {
vErrors.push(err618);
}
errors++;
}
else {
if(data211.length < 32){
const err619 = {instancePath:instancePath+"/inspection/contract",schemaPath:"#/oneOf/4/properties/inspection/properties/contract/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err619];
}
else {
vErrors.push(err619);
}
errors++;
}
else {
var valid106 = true;
const len18 = data211.length;
for(let i18=0; i18<len18; i18++){
let data212 = data211[i18];
const _errs594 = errors;
if(!(((typeof data212 == "number") && (!(data212 % 1) && !isNaN(data212))) && (isFinite(data212)))){
const err620 = {instancePath:instancePath+"/inspection/contract/" + i18,schemaPath:"#/oneOf/4/properties/inspection/properties/contract/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err620];
}
else {
vErrors.push(err620);
}
errors++;
}
if(errors === _errs594){
if((typeof data212 == "number") && (isFinite(data212))){
if(data212 > 255 || isNaN(data212)){
const err621 = {instancePath:instancePath+"/inspection/contract/" + i18,schemaPath:"#/oneOf/4/properties/inspection/properties/contract/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err621];
}
else {
vErrors.push(err621);
}
errors++;
}
else {
if(data212 < 0 || isNaN(data212)){
const err622 = {instancePath:instancePath+"/inspection/contract/" + i18,schemaPath:"#/oneOf/4/properties/inspection/properties/contract/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err622];
}
else {
vErrors.push(err622);
}
errors++;
}
}
}
}
var valid106 = _errs594 === errors;
if(!valid106){
break;
}
}
}
}
}
else {
const err623 = {instancePath:instancePath+"/inspection/contract",schemaPath:"#/oneOf/4/properties/inspection/properties/contract/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err623];
}
else {
vErrors.push(err623);
}
errors++;
}
}
var valid105 = _errs592 === errors;
}
else {
var valid105 = true;
}
if(valid105){
if(data205.schema !== undefined){
let data213 = data205.schema;
const _errs596 = errors;
if(errors === _errs596){
if(Array.isArray(data213)){
if(data213.length > 32){
const err624 = {instancePath:instancePath+"/inspection/schema",schemaPath:"#/oneOf/4/properties/inspection/properties/schema/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err624];
}
else {
vErrors.push(err624);
}
errors++;
}
else {
if(data213.length < 32){
const err625 = {instancePath:instancePath+"/inspection/schema",schemaPath:"#/oneOf/4/properties/inspection/properties/schema/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err625];
}
else {
vErrors.push(err625);
}
errors++;
}
else {
var valid107 = true;
const len19 = data213.length;
for(let i19=0; i19<len19; i19++){
let data214 = data213[i19];
const _errs598 = errors;
if(!(((typeof data214 == "number") && (!(data214 % 1) && !isNaN(data214))) && (isFinite(data214)))){
const err626 = {instancePath:instancePath+"/inspection/schema/" + i19,schemaPath:"#/oneOf/4/properties/inspection/properties/schema/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err626];
}
else {
vErrors.push(err626);
}
errors++;
}
if(errors === _errs598){
if((typeof data214 == "number") && (isFinite(data214))){
if(data214 > 255 || isNaN(data214)){
const err627 = {instancePath:instancePath+"/inspection/schema/" + i19,schemaPath:"#/oneOf/4/properties/inspection/properties/schema/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err627];
}
else {
vErrors.push(err627);
}
errors++;
}
else {
if(data214 < 0 || isNaN(data214)){
const err628 = {instancePath:instancePath+"/inspection/schema/" + i19,schemaPath:"#/oneOf/4/properties/inspection/properties/schema/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err628];
}
else {
vErrors.push(err628);
}
errors++;
}
}
}
}
var valid107 = _errs598 === errors;
if(!valid107){
break;
}
}
}
}
}
else {
const err629 = {instancePath:instancePath+"/inspection/schema",schemaPath:"#/oneOf/4/properties/inspection/properties/schema/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err629];
}
else {
vErrors.push(err629);
}
errors++;
}
}
var valid105 = _errs596 === errors;
}
else {
var valid105 = true;
}
if(valid105){
if(data205.resource_revision !== undefined){
let data215 = data205.resource_revision;
const _errs600 = errors;
if(!(((typeof data215 == "number") && (!(data215 % 1) && !isNaN(data215))) && (isFinite(data215)))){
const err630 = {instancePath:instancePath+"/inspection/resource_revision",schemaPath:"#/oneOf/4/properties/inspection/properties/resource_revision/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err630];
}
else {
vErrors.push(err630);
}
errors++;
}
if(errors === _errs600){
if((typeof data215 == "number") && (isFinite(data215))){
if(data215 > 9007199254740991 || isNaN(data215)){
const err631 = {instancePath:instancePath+"/inspection/resource_revision",schemaPath:"#/oneOf/4/properties/inspection/properties/resource_revision/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err631];
}
else {
vErrors.push(err631);
}
errors++;
}
else {
if(data215 < 0 || isNaN(data215)){
const err632 = {instancePath:instancePath+"/inspection/resource_revision",schemaPath:"#/oneOf/4/properties/inspection/properties/resource_revision/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err632];
}
else {
vErrors.push(err632);
}
errors++;
}
}
}
}
var valid105 = _errs600 === errors;
}
else {
var valid105 = true;
}
if(valid105){
if(data205.policy_revision !== undefined){
let data216 = data205.policy_revision;
const _errs602 = errors;
if(errors === _errs602){
if(typeof data216 === "string"){
if(func1(data216) > 131072){
const err633 = {instancePath:instancePath+"/inspection/policy_revision",schemaPath:"#/oneOf/4/properties/inspection/properties/policy_revision/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err633];
}
else {
vErrors.push(err633);
}
errors++;
}
}
else {
const err634 = {instancePath:instancePath+"/inspection/policy_revision",schemaPath:"#/oneOf/4/properties/inspection/properties/policy_revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err634];
}
else {
vErrors.push(err634);
}
errors++;
}
}
var valid105 = _errs602 === errors;
}
else {
var valid105 = true;
}
if(valid105){
if(data205.details !== undefined){
let data217 = data205.details;
const _errs604 = errors;
const _errs605 = errors;
let valid108 = false;
let passing8 = null;
const _errs606 = errors;
if(errors === _errs606){
if(data217 && typeof data217 == "object" && !Array.isArray(data217)){
let missing73;
if((data217.description === undefined) && (missing73 = "description")){
const err635 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/0/required",keyword:"required",params:{missingProperty: missing73},message:"must have required property '"+missing73+"'"};
if(vErrors === null){
vErrors = [err635];
}
else {
vErrors.push(err635);
}
errors++;
}
else {
const _errs608 = errors;
for(const key73 in data217){
if(!(key73 === "description")){
const err636 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key73},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err636];
}
else {
vErrors.push(err636);
}
errors++;
break;
}
}
if(_errs608 === errors){
if(data217.description !== undefined){
let data218 = data217.description;
const _errs609 = errors;
if(errors === _errs609){
if(data218 && typeof data218 == "object" && !Array.isArray(data218)){
let missing74;
if((data218.columns === undefined) && (missing74 = "columns")){
const err637 = {instancePath:instancePath+"/inspection/details/description",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/0/properties/description/required",keyword:"required",params:{missingProperty: missing74},message:"must have required property '"+missing74+"'"};
if(vErrors === null){
vErrors = [err637];
}
else {
vErrors.push(err637);
}
errors++;
}
else {
const _errs611 = errors;
for(const key74 in data218){
if(!(key74 === "columns")){
const err638 = {instancePath:instancePath+"/inspection/details/description",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/0/properties/description/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key74},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err638];
}
else {
vErrors.push(err638);
}
errors++;
break;
}
}
if(_errs611 === errors){
if(data218.columns !== undefined){
let data219 = data218.columns;
const _errs612 = errors;
if(errors === _errs612){
if(Array.isArray(data219)){
if(data219.length > 8){
const err639 = {instancePath:instancePath+"/inspection/details/description/columns",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/0/properties/description/properties/columns/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err639];
}
else {
vErrors.push(err639);
}
errors++;
}
else {
var valid111 = true;
const len20 = data219.length;
for(let i20=0; i20<len20; i20++){
let data220 = data219[i20];
const _errs614 = errors;
if(errors === _errs614){
if(data220 && typeof data220 == "object" && !Array.isArray(data220)){
let missing75;
if(((data220.name === undefined) && (missing75 = "name")) || ((data220.type === undefined) && (missing75 = "type"))){
const err640 = {instancePath:instancePath+"/inspection/details/description/columns/" + i20,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/0/properties/description/properties/columns/items/required",keyword:"required",params:{missingProperty: missing75},message:"must have required property '"+missing75+"'"};
if(vErrors === null){
vErrors = [err640];
}
else {
vErrors.push(err640);
}
errors++;
}
else {
const _errs616 = errors;
for(const key75 in data220){
if(!((key75 === "name") || (key75 === "type"))){
const err641 = {instancePath:instancePath+"/inspection/details/description/columns/" + i20,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/0/properties/description/properties/columns/items/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key75},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err641];
}
else {
vErrors.push(err641);
}
errors++;
break;
}
}
if(_errs616 === errors){
if(data220.name !== undefined){
let data221 = data220.name;
const _errs617 = errors;
if(errors === _errs617){
if(typeof data221 === "string"){
if(func1(data221) > 131072){
const err642 = {instancePath:instancePath+"/inspection/details/description/columns/" + i20+"/name",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/0/properties/description/properties/columns/items/properties/name/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err642];
}
else {
vErrors.push(err642);
}
errors++;
}
}
else {
const err643 = {instancePath:instancePath+"/inspection/details/description/columns/" + i20+"/name",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/0/properties/description/properties/columns/items/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err643];
}
else {
vErrors.push(err643);
}
errors++;
}
}
var valid112 = _errs617 === errors;
}
else {
var valid112 = true;
}
if(valid112){
if(data220.type !== undefined){
let data222 = data220.type;
const _errs619 = errors;
if(typeof data222 !== "string"){
const err644 = {instancePath:instancePath+"/inspection/details/description/columns/" + i20+"/type",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/0/properties/description/properties/columns/items/properties/type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err644];
}
else {
vErrors.push(err644);
}
errors++;
}
if(!((((((data222 === "int64") || (data222 === "uint64")) || (data222 === "float64")) || (data222 === "boolean")) || (data222 === "utf8")) || (data222 === "binary"))){
const err645 = {instancePath:instancePath+"/inspection/details/description/columns/" + i20+"/type",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/0/properties/description/properties/columns/items/properties/type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.inspection.properties.details.oneOf[0].properties.description.properties.columns.items.properties.type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err645];
}
else {
vErrors.push(err645);
}
errors++;
}
var valid112 = _errs619 === errors;
}
else {
var valid112 = true;
}
}
}
}
}
else {
const err646 = {instancePath:instancePath+"/inspection/details/description/columns/" + i20,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/0/properties/description/properties/columns/items/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err646];
}
else {
vErrors.push(err646);
}
errors++;
}
}
var valid111 = _errs614 === errors;
if(!valid111){
break;
}
}
}
}
else {
const err647 = {instancePath:instancePath+"/inspection/details/description/columns",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/0/properties/description/properties/columns/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err647];
}
else {
vErrors.push(err647);
}
errors++;
}
}
}
}
}
}
else {
const err648 = {instancePath:instancePath+"/inspection/details/description",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/0/properties/description/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err649 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err649];
}
else {
vErrors.push(err649);
}
errors++;
}
}
var _valid15 = _errs606 === errors;
if(_valid15){
valid108 = true;
passing8 = 0;
var props9 = true;
}
const _errs621 = errors;
if(errors === _errs621){
if(data217 && typeof data217 == "object" && !Array.isArray(data217)){
let missing76;
if((data217.tables === undefined) && (missing76 = "tables")){
const err650 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/1/required",keyword:"required",params:{missingProperty: missing76},message:"must have required property '"+missing76+"'"};
if(vErrors === null){
vErrors = [err650];
}
else {
vErrors.push(err650);
}
errors++;
}
else {
const _errs623 = errors;
for(const key76 in data217){
if(!(key76 === "tables")){
const err651 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key76},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err651];
}
else {
vErrors.push(err651);
}
errors++;
break;
}
}
if(_errs623 === errors){
if(data217.tables !== undefined){
let data223 = data217.tables;
const _errs624 = errors;
if(errors === _errs624){
if(Array.isArray(data223)){
if(data223.length > 8){
const err652 = {instancePath:instancePath+"/inspection/details/tables",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/1/properties/tables/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err652];
}
else {
vErrors.push(err652);
}
errors++;
}
else {
var valid114 = true;
const len21 = data223.length;
for(let i21=0; i21<len21; i21++){
let data224 = data223[i21];
const _errs626 = errors;
if(errors === _errs626){
if(typeof data224 === "string"){
if(func1(data224) > 131072){
const err653 = {instancePath:instancePath+"/inspection/details/tables/" + i21,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/1/properties/tables/items/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err653];
}
else {
vErrors.push(err653);
}
errors++;
}
}
else {
const err654 = {instancePath:instancePath+"/inspection/details/tables/" + i21,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/1/properties/tables/items/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err654];
}
else {
vErrors.push(err654);
}
errors++;
}
}
var valid114 = _errs626 === errors;
if(!valid114){
break;
}
}
}
}
else {
const err655 = {instancePath:instancePath+"/inspection/details/tables",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/1/properties/tables/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err655];
}
else {
vErrors.push(err655);
}
errors++;
}
}
}
}
}
}
else {
const err656 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err656];
}
else {
vErrors.push(err656);
}
errors++;
}
}
var _valid15 = _errs621 === errors;
if(_valid15 && valid108){
valid108 = false;
passing8 = [passing8, 1];
}
else {
if(_valid15){
valid108 = true;
passing8 = 1;
if(props9 !== true){
props9 = true;
}
}
const _errs628 = errors;
if(errors === _errs628){
if(data217 && typeof data217 == "object" && !Array.isArray(data217)){
let missing77;
if((data217.explanation === undefined) && (missing77 = "explanation")){
const err657 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/required",keyword:"required",params:{missingProperty: missing77},message:"must have required property '"+missing77+"'"};
if(vErrors === null){
vErrors = [err657];
}
else {
vErrors.push(err657);
}
errors++;
}
else {
const _errs630 = errors;
for(const key77 in data217){
if(!(key77 === "explanation")){
const err658 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key77},message:"must NOT have additional properties"};
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
if(_errs630 === errors){
if(data217.explanation !== undefined){
let data225 = data217.explanation;
const _errs631 = errors;
if(errors === _errs631){
if(data225 && typeof data225 == "object" && !Array.isArray(data225)){
let missing78;
if((((((((data225.operators === undefined) && (missing78 = "operators")) || ((data225.predicate === undefined) && (missing78 = "predicate"))) || ((data225.projection === undefined) && (missing78 = "projection"))) || ((data225.limit === undefined) && (missing78 = "limit"))) || ((data225.aggregate === undefined) && (missing78 = "aggregate"))) || ((data225.columns === undefined) && (missing78 = "columns"))) || ((data225.budgets === undefined) && (missing78 = "budgets"))){
const err659 = {instancePath:instancePath+"/inspection/details/explanation",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/required",keyword:"required",params:{missingProperty: missing78},message:"must have required property '"+missing78+"'"};
if(vErrors === null){
vErrors = [err659];
}
else {
vErrors.push(err659);
}
errors++;
}
else {
const _errs633 = errors;
for(const key78 in data225){
if(!(((((((key78 === "operators") || (key78 === "predicate")) || (key78 === "projection")) || (key78 === "limit")) || (key78 === "aggregate")) || (key78 === "columns")) || (key78 === "budgets"))){
const err660 = {instancePath:instancePath+"/inspection/details/explanation",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key78},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err660];
}
else {
vErrors.push(err660);
}
errors++;
break;
}
}
if(_errs633 === errors){
if(data225.operators !== undefined){
let data226 = data225.operators;
const _errs634 = errors;
if(errors === _errs634){
if(Array.isArray(data226)){
if(data226.length > 8){
const err661 = {instancePath:instancePath+"/inspection/details/explanation/operators",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/operators/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err661];
}
else {
vErrors.push(err661);
}
errors++;
}
else {
var valid117 = true;
const len22 = data226.length;
for(let i22=0; i22<len22; i22++){
let data227 = data226[i22];
const _errs636 = errors;
if(typeof data227 !== "string"){
const err662 = {instancePath:instancePath+"/inspection/details/explanation/operators/" + i22,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/operators/items/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err662];
}
else {
vErrors.push(err662);
}
errors++;
}
if(!(((((((data227 === "scan") || (data227 === "filter")) || (data227 === "limit")) || (data227 === "project")) || (data227 === "count")) || (data227 === "sum")) || (data227 === "count_values"))){
const err663 = {instancePath:instancePath+"/inspection/details/explanation/operators/" + i22,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/operators/items/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.inspection.properties.details.oneOf[2].properties.explanation.properties.operators.items.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err663];
}
else {
vErrors.push(err663);
}
errors++;
}
var valid117 = _errs636 === errors;
if(!valid117){
break;
}
}
}
}
else {
const err664 = {instancePath:instancePath+"/inspection/details/explanation/operators",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/operators/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err664];
}
else {
vErrors.push(err664);
}
errors++;
}
}
var valid116 = _errs634 === errors;
}
else {
var valid116 = true;
}
if(valid116){
if(data225.predicate !== undefined){
let data228 = data225.predicate;
const _errs638 = errors;
const _errs639 = errors;
let valid118 = false;
let passing9 = null;
const _errs640 = errors;
if(errors === _errs640){
if(data228 && typeof data228 == "object" && !Array.isArray(data228)){
let missing79;
if((data228.all === undefined) && (missing79 = "all")){
const err665 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/0/required",keyword:"required",params:{missingProperty: missing79},message:"must have required property '"+missing79+"'"};
if(vErrors === null){
vErrors = [err665];
}
else {
vErrors.push(err665);
}
errors++;
}
else {
const _errs642 = errors;
for(const key79 in data228){
if(!(key79 === "all")){
const err666 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key79},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err666];
}
else {
vErrors.push(err666);
}
errors++;
break;
}
}
if(_errs642 === errors){
if(data228.all !== undefined){
let data229 = data228.all;
const _errs643 = errors;
if(errors === _errs643){
if(data229 && typeof data229 == "object" && !Array.isArray(data229)){
if(Object.keys(data229).length > 0){
const err667 = {instancePath:instancePath+"/inspection/details/explanation/predicate/all",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/0/properties/all/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err667];
}
else {
vErrors.push(err667);
}
errors++;
}
}
else {
const err668 = {instancePath:instancePath+"/inspection/details/explanation/predicate/all",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/0/properties/all/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err668];
}
else {
vErrors.push(err668);
}
errors++;
}
}
}
}
}
}
else {
const err669 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err669];
}
else {
vErrors.push(err669);
}
errors++;
}
}
var _valid16 = _errs640 === errors;
if(_valid16){
valid118 = true;
passing9 = 0;
var props10 = true;
}
const _errs645 = errors;
if(errors === _errs645){
if(data228 && typeof data228 == "object" && !Array.isArray(data228)){
let missing80;
if((data228.state === undefined) && (missing80 = "state")){
const err670 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/1/required",keyword:"required",params:{missingProperty: missing80},message:"must have required property '"+missing80+"'"};
if(vErrors === null){
vErrors = [err670];
}
else {
vErrors.push(err670);
}
errors++;
}
else {
const _errs647 = errors;
for(const key80 in data228){
if(!(key80 === "state")){
const err671 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key80},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err671];
}
else {
vErrors.push(err671);
}
errors++;
break;
}
}
if(_errs647 === errors){
if(data228.state !== undefined){
let data230 = data228.state;
const _errs648 = errors;
if(errors === _errs648){
if(data230 && typeof data230 == "object" && !Array.isArray(data230)){
let missing81;
if(((data230.column === undefined) && (missing81 = "column")) || ((data230.value === undefined) && (missing81 = "value"))){
const err672 = {instancePath:instancePath+"/inspection/details/explanation/predicate/state",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/1/properties/state/required",keyword:"required",params:{missingProperty: missing81},message:"must have required property '"+missing81+"'"};
if(vErrors === null){
vErrors = [err672];
}
else {
vErrors.push(err672);
}
errors++;
}
else {
const _errs650 = errors;
for(const key81 in data230){
if(!((key81 === "column") || (key81 === "value"))){
const err673 = {instancePath:instancePath+"/inspection/details/explanation/predicate/state",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/1/properties/state/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key81},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err673];
}
else {
vErrors.push(err673);
}
errors++;
break;
}
}
if(_errs650 === errors){
if(data230.column !== undefined){
let data231 = data230.column;
const _errs651 = errors;
if(errors === _errs651){
if(typeof data231 === "string"){
if(func1(data231) > 131072){
const err674 = {instancePath:instancePath+"/inspection/details/explanation/predicate/state/column",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/1/properties/state/properties/column/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err674];
}
else {
vErrors.push(err674);
}
errors++;
}
}
else {
const err675 = {instancePath:instancePath+"/inspection/details/explanation/predicate/state/column",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/1/properties/state/properties/column/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err675];
}
else {
vErrors.push(err675);
}
errors++;
}
}
var valid121 = _errs651 === errors;
}
else {
var valid121 = true;
}
if(valid121){
if(data230.value !== undefined){
let data232 = data230.value;
const _errs653 = errors;
if(typeof data232 !== "string"){
const err676 = {instancePath:instancePath+"/inspection/details/explanation/predicate/state/value",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/1/properties/state/properties/value/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err676];
}
else {
vErrors.push(err676);
}
errors++;
}
if(!(((((data232 === "missing") || (data232 === "null")) || (data232 === "type_error")) || (data232 === "value")) || (data232 === "conflict"))){
const err677 = {instancePath:instancePath+"/inspection/details/explanation/predicate/state/value",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/1/properties/state/properties/value/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.inspection.properties.details.oneOf[2].properties.explanation.properties.predicate.oneOf[1].properties.state.properties.value.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err677];
}
else {
vErrors.push(err677);
}
errors++;
}
var valid121 = _errs653 === errors;
}
else {
var valid121 = true;
}
}
}
}
}
else {
const err678 = {instancePath:instancePath+"/inspection/details/explanation/predicate/state",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/1/properties/state/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err678];
}
else {
vErrors.push(err678);
}
errors++;
}
}
}
}
}
}
else {
const err679 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err679];
}
else {
vErrors.push(err679);
}
errors++;
}
}
var _valid16 = _errs645 === errors;
if(_valid16 && valid118){
valid118 = false;
passing9 = [passing9, 1];
}
else {
if(_valid16){
valid118 = true;
passing9 = 1;
if(props10 !== true){
props10 = true;
}
}
const _errs655 = errors;
if(errors === _errs655){
if(data228 && typeof data228 == "object" && !Array.isArray(data228)){
let missing82;
if((data228.compare === undefined) && (missing82 = "compare")){
const err680 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/required",keyword:"required",params:{missingProperty: missing82},message:"must have required property '"+missing82+"'"};
if(vErrors === null){
vErrors = [err680];
}
else {
vErrors.push(err680);
}
errors++;
}
else {
const _errs657 = errors;
for(const key82 in data228){
if(!(key82 === "compare")){
const err681 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key82},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err681];
}
else {
vErrors.push(err681);
}
errors++;
break;
}
}
if(_errs657 === errors){
if(data228.compare !== undefined){
let data233 = data228.compare;
const _errs658 = errors;
if(errors === _errs658){
if(data233 && typeof data233 == "object" && !Array.isArray(data233)){
let missing83;
if((((data233.column === undefined) && (missing83 = "column")) || ((data233.op === undefined) && (missing83 = "op"))) || ((data233.type === undefined) && (missing83 = "type"))){
const err682 = {instancePath:instancePath+"/inspection/details/explanation/predicate/compare",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/properties/compare/required",keyword:"required",params:{missingProperty: missing83},message:"must have required property '"+missing83+"'"};
if(vErrors === null){
vErrors = [err682];
}
else {
vErrors.push(err682);
}
errors++;
}
else {
const _errs660 = errors;
for(const key83 in data233){
if(!(((key83 === "column") || (key83 === "op")) || (key83 === "type"))){
const err683 = {instancePath:instancePath+"/inspection/details/explanation/predicate/compare",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/properties/compare/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key83},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err683];
}
else {
vErrors.push(err683);
}
errors++;
break;
}
}
if(_errs660 === errors){
if(data233.column !== undefined){
let data234 = data233.column;
const _errs661 = errors;
if(errors === _errs661){
if(typeof data234 === "string"){
if(func1(data234) > 131072){
const err684 = {instancePath:instancePath+"/inspection/details/explanation/predicate/compare/column",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/properties/compare/properties/column/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err685 = {instancePath:instancePath+"/inspection/details/explanation/predicate/compare/column",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/properties/compare/properties/column/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err685];
}
else {
vErrors.push(err685);
}
errors++;
}
}
var valid123 = _errs661 === errors;
}
else {
var valid123 = true;
}
if(valid123){
if(data233.op !== undefined){
let data235 = data233.op;
const _errs663 = errors;
if(typeof data235 !== "string"){
const err686 = {instancePath:instancePath+"/inspection/details/explanation/predicate/compare/op",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/properties/compare/properties/op/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err686];
}
else {
vErrors.push(err686);
}
errors++;
}
if(!((((((data235 === "eq") || (data235 === "ne")) || (data235 === "lt")) || (data235 === "le")) || (data235 === "gt")) || (data235 === "ge"))){
const err687 = {instancePath:instancePath+"/inspection/details/explanation/predicate/compare/op",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/properties/compare/properties/op/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.inspection.properties.details.oneOf[2].properties.explanation.properties.predicate.oneOf[2].properties.compare.properties.op.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err687];
}
else {
vErrors.push(err687);
}
errors++;
}
var valid123 = _errs663 === errors;
}
else {
var valid123 = true;
}
if(valid123){
if(data233.type !== undefined){
let data236 = data233.type;
const _errs665 = errors;
if(typeof data236 !== "string"){
const err688 = {instancePath:instancePath+"/inspection/details/explanation/predicate/compare/type",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/properties/compare/properties/type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err688];
}
else {
vErrors.push(err688);
}
errors++;
}
if(!((((((data236 === "int64") || (data236 === "uint64")) || (data236 === "float64")) || (data236 === "boolean")) || (data236 === "utf8")) || (data236 === "binary"))){
const err689 = {instancePath:instancePath+"/inspection/details/explanation/predicate/compare/type",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/properties/compare/properties/type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.inspection.properties.details.oneOf[2].properties.explanation.properties.predicate.oneOf[2].properties.compare.properties.type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err689];
}
else {
vErrors.push(err689);
}
errors++;
}
var valid123 = _errs665 === errors;
}
else {
var valid123 = true;
}
}
}
}
}
}
else {
const err690 = {instancePath:instancePath+"/inspection/details/explanation/predicate/compare",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/properties/compare/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err690];
}
else {
vErrors.push(err690);
}
errors++;
}
}
}
}
}
}
else {
const err691 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err691];
}
else {
vErrors.push(err691);
}
errors++;
}
}
var _valid16 = _errs655 === errors;
if(_valid16 && valid118){
valid118 = false;
passing9 = [passing9, 2];
}
else {
if(_valid16){
valid118 = true;
passing9 = 2;
if(props10 !== true){
props10 = true;
}
}
const _errs667 = errors;
if(errors === _errs667){
if(data228 && typeof data228 == "object" && !Array.isArray(data228)){
let missing84;
if((data228.program === undefined) && (missing84 = "program")){
const err692 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/required",keyword:"required",params:{missingProperty: missing84},message:"must have required property '"+missing84+"'"};
if(vErrors === null){
vErrors = [err692];
}
else {
vErrors.push(err692);
}
errors++;
}
else {
const _errs669 = errors;
for(const key84 in data228){
if(!(key84 === "program")){
const err693 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key84},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err693];
}
else {
vErrors.push(err693);
}
errors++;
break;
}
}
if(_errs669 === errors){
if(data228.program !== undefined){
let data237 = data228.program;
const _errs670 = errors;
if(errors === _errs670){
if(Array.isArray(data237)){
if(data237.length > 64){
const err694 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/maxItems",keyword:"maxItems",params:{limit: 64},message:"must NOT have more than 64 items"};
if(vErrors === null){
vErrors = [err694];
}
else {
vErrors.push(err694);
}
errors++;
}
else {
var valid125 = true;
const len23 = data237.length;
for(let i23=0; i23<len23; i23++){
let data238 = data237[i23];
const _errs672 = errors;
const _errs673 = errors;
let valid126 = false;
let passing10 = null;
const _errs674 = errors;
if(errors === _errs674){
if(data238 && typeof data238 == "object" && !Array.isArray(data238)){
let missing85;
if((data238.atom === undefined) && (missing85 = "atom")){
const err695 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/required",keyword:"required",params:{missingProperty: missing85},message:"must have required property '"+missing85+"'"};
if(vErrors === null){
vErrors = [err695];
}
else {
vErrors.push(err695);
}
errors++;
}
else {
const _errs676 = errors;
for(const key85 in data238){
if(!(key85 === "atom")){
const err696 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key85},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err696];
}
else {
vErrors.push(err696);
}
errors++;
break;
}
}
if(_errs676 === errors){
if(data238.atom !== undefined){
let data239 = data238.atom;
const _errs678 = errors;
let valid128 = false;
let passing11 = null;
const _errs679 = errors;
if(errors === _errs679){
if(data239 && typeof data239 == "object" && !Array.isArray(data239)){
let missing86;
if((data239.all === undefined) && (missing86 = "all")){
const err697 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/0/required",keyword:"required",params:{missingProperty: missing86},message:"must have required property '"+missing86+"'"};
if(vErrors === null){
vErrors = [err697];
}
else {
vErrors.push(err697);
}
errors++;
}
else {
const _errs681 = errors;
for(const key86 in data239){
if(!(key86 === "all")){
const err698 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key86},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err698];
}
else {
vErrors.push(err698);
}
errors++;
break;
}
}
if(_errs681 === errors){
if(data239.all !== undefined){
let data240 = data239.all;
const _errs682 = errors;
if(errors === _errs682){
if(data240 && typeof data240 == "object" && !Array.isArray(data240)){
if(Object.keys(data240).length > 0){
const err699 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/all",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/0/properties/all/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err699];
}
else {
vErrors.push(err699);
}
errors++;
}
}
else {
const err700 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/all",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/0/properties/all/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err700];
}
else {
vErrors.push(err700);
}
errors++;
}
}
}
}
}
}
else {
const err701 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err701];
}
else {
vErrors.push(err701);
}
errors++;
}
}
var _valid18 = _errs679 === errors;
if(_valid18){
valid128 = true;
passing11 = 0;
var props11 = true;
}
const _errs684 = errors;
if(errors === _errs684){
if(data239 && typeof data239 == "object" && !Array.isArray(data239)){
let missing87;
if((data239.state === undefined) && (missing87 = "state")){
const err702 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/required",keyword:"required",params:{missingProperty: missing87},message:"must have required property '"+missing87+"'"};
if(vErrors === null){
vErrors = [err702];
}
else {
vErrors.push(err702);
}
errors++;
}
else {
const _errs686 = errors;
for(const key87 in data239){
if(!(key87 === "state")){
const err703 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key87},message:"must NOT have additional properties"};
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
if(_errs686 === errors){
if(data239.state !== undefined){
let data241 = data239.state;
const _errs687 = errors;
if(errors === _errs687){
if(data241 && typeof data241 == "object" && !Array.isArray(data241)){
let missing88;
if(((data241.column === undefined) && (missing88 = "column")) || ((data241.value === undefined) && (missing88 = "value"))){
const err704 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/state",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/properties/state/required",keyword:"required",params:{missingProperty: missing88},message:"must have required property '"+missing88+"'"};
if(vErrors === null){
vErrors = [err704];
}
else {
vErrors.push(err704);
}
errors++;
}
else {
const _errs689 = errors;
for(const key88 in data241){
if(!((key88 === "column") || (key88 === "value"))){
const err705 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/state",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/properties/state/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key88},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err705];
}
else {
vErrors.push(err705);
}
errors++;
break;
}
}
if(_errs689 === errors){
if(data241.column !== undefined){
let data242 = data241.column;
const _errs690 = errors;
if(errors === _errs690){
if(typeof data242 === "string"){
if(func1(data242) > 131072){
const err706 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/state/column",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/properties/state/properties/column/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err706];
}
else {
vErrors.push(err706);
}
errors++;
}
}
else {
const err707 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/state/column",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/properties/state/properties/column/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err707];
}
else {
vErrors.push(err707);
}
errors++;
}
}
var valid131 = _errs690 === errors;
}
else {
var valid131 = true;
}
if(valid131){
if(data241.value !== undefined){
let data243 = data241.value;
const _errs692 = errors;
if(typeof data243 !== "string"){
const err708 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/state/value",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/properties/state/properties/value/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err708];
}
else {
vErrors.push(err708);
}
errors++;
}
if(!(((((data243 === "missing") || (data243 === "null")) || (data243 === "type_error")) || (data243 === "value")) || (data243 === "conflict"))){
const err709 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/state/value",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/properties/state/properties/value/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.inspection.properties.details.oneOf[2].properties.explanation.properties.predicate.oneOf[3].properties.program.items.oneOf[0].properties.atom.oneOf[1].properties.state.properties.value.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err709];
}
else {
vErrors.push(err709);
}
errors++;
}
var valid131 = _errs692 === errors;
}
else {
var valid131 = true;
}
}
}
}
}
else {
const err710 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/state",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/properties/state/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err710];
}
else {
vErrors.push(err710);
}
errors++;
}
}
}
}
}
}
else {
const err711 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err711];
}
else {
vErrors.push(err711);
}
errors++;
}
}
var _valid18 = _errs684 === errors;
if(_valid18 && valid128){
valid128 = false;
passing11 = [passing11, 1];
}
else {
if(_valid18){
valid128 = true;
passing11 = 1;
if(props11 !== true){
props11 = true;
}
}
const _errs694 = errors;
if(errors === _errs694){
if(data239 && typeof data239 == "object" && !Array.isArray(data239)){
let missing89;
if((data239.compare === undefined) && (missing89 = "compare")){
const err712 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/required",keyword:"required",params:{missingProperty: missing89},message:"must have required property '"+missing89+"'"};
if(vErrors === null){
vErrors = [err712];
}
else {
vErrors.push(err712);
}
errors++;
}
else {
const _errs696 = errors;
for(const key89 in data239){
if(!(key89 === "compare")){
const err713 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key89},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err713];
}
else {
vErrors.push(err713);
}
errors++;
break;
}
}
if(_errs696 === errors){
if(data239.compare !== undefined){
let data244 = data239.compare;
const _errs697 = errors;
if(errors === _errs697){
if(data244 && typeof data244 == "object" && !Array.isArray(data244)){
let missing90;
if((((data244.column === undefined) && (missing90 = "column")) || ((data244.op === undefined) && (missing90 = "op"))) || ((data244.type === undefined) && (missing90 = "type"))){
const err714 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/compare",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/required",keyword:"required",params:{missingProperty: missing90},message:"must have required property '"+missing90+"'"};
if(vErrors === null){
vErrors = [err714];
}
else {
vErrors.push(err714);
}
errors++;
}
else {
const _errs699 = errors;
for(const key90 in data244){
if(!(((key90 === "column") || (key90 === "op")) || (key90 === "type"))){
const err715 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/compare",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key90},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err715];
}
else {
vErrors.push(err715);
}
errors++;
break;
}
}
if(_errs699 === errors){
if(data244.column !== undefined){
let data245 = data244.column;
const _errs700 = errors;
if(errors === _errs700){
if(typeof data245 === "string"){
if(func1(data245) > 131072){
const err716 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/compare/column",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/column/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err716];
}
else {
vErrors.push(err716);
}
errors++;
}
}
else {
const err717 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/compare/column",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/column/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err717];
}
else {
vErrors.push(err717);
}
errors++;
}
}
var valid133 = _errs700 === errors;
}
else {
var valid133 = true;
}
if(valid133){
if(data244.op !== undefined){
let data246 = data244.op;
const _errs702 = errors;
if(typeof data246 !== "string"){
const err718 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/compare/op",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/op/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err718];
}
else {
vErrors.push(err718);
}
errors++;
}
if(!((((((data246 === "eq") || (data246 === "ne")) || (data246 === "lt")) || (data246 === "le")) || (data246 === "gt")) || (data246 === "ge"))){
const err719 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/compare/op",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/op/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.inspection.properties.details.oneOf[2].properties.explanation.properties.predicate.oneOf[3].properties.program.items.oneOf[0].properties.atom.oneOf[2].properties.compare.properties.op.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err719];
}
else {
vErrors.push(err719);
}
errors++;
}
var valid133 = _errs702 === errors;
}
else {
var valid133 = true;
}
if(valid133){
if(data244.type !== undefined){
let data247 = data244.type;
const _errs704 = errors;
if(typeof data247 !== "string"){
const err720 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/compare/type",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err720];
}
else {
vErrors.push(err720);
}
errors++;
}
if(!((((((data247 === "int64") || (data247 === "uint64")) || (data247 === "float64")) || (data247 === "boolean")) || (data247 === "utf8")) || (data247 === "binary"))){
const err721 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/compare/type",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.inspection.properties.details.oneOf[2].properties.explanation.properties.predicate.oneOf[3].properties.program.items.oneOf[0].properties.atom.oneOf[2].properties.compare.properties.type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err721];
}
else {
vErrors.push(err721);
}
errors++;
}
var valid133 = _errs704 === errors;
}
else {
var valid133 = true;
}
}
}
}
}
}
else {
const err722 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/compare",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err722];
}
else {
vErrors.push(err722);
}
errors++;
}
}
}
}
}
}
else {
const err723 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err723];
}
else {
vErrors.push(err723);
}
errors++;
}
}
var _valid18 = _errs694 === errors;
if(_valid18 && valid128){
valid128 = false;
passing11 = [passing11, 2];
}
else {
if(_valid18){
valid128 = true;
passing11 = 2;
if(props11 !== true){
props11 = true;
}
}
}
}
if(!valid128){
const err724 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf",keyword:"oneOf",params:{passingSchemas: passing11},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err724];
}
else {
vErrors.push(err724);
}
errors++;
}
else {
errors = _errs678;
if(vErrors !== null){
if(_errs678){
vErrors.length = _errs678;
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
const err725 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err725];
}
else {
vErrors.push(err725);
}
errors++;
}
}
var _valid17 = _errs674 === errors;
if(_valid17){
valid126 = true;
passing10 = 0;
var props12 = true;
}
const _errs706 = errors;
if(errors === _errs706){
if(data238 && typeof data238 == "object" && !Array.isArray(data238)){
let missing91;
if((data238.negate === undefined) && (missing91 = "negate")){
const err726 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/1/required",keyword:"required",params:{missingProperty: missing91},message:"must have required property '"+missing91+"'"};
if(vErrors === null){
vErrors = [err726];
}
else {
vErrors.push(err726);
}
errors++;
}
else {
const _errs708 = errors;
for(const key91 in data238){
if(!(key91 === "negate")){
const err727 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key91},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err727];
}
else {
vErrors.push(err727);
}
errors++;
break;
}
}
if(_errs708 === errors){
if(data238.negate !== undefined){
let data248 = data238.negate;
const _errs709 = errors;
if(errors === _errs709){
if(data248 && typeof data248 == "object" && !Array.isArray(data248)){
if(Object.keys(data248).length > 0){
const err728 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/negate",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/1/properties/negate/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err728];
}
else {
vErrors.push(err728);
}
errors++;
}
}
else {
const err729 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/negate",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/1/properties/negate/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err729];
}
else {
vErrors.push(err729);
}
errors++;
}
}
}
}
}
}
else {
const err730 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err730];
}
else {
vErrors.push(err730);
}
errors++;
}
}
var _valid17 = _errs706 === errors;
if(_valid17 && valid126){
valid126 = false;
passing10 = [passing10, 1];
}
else {
if(_valid17){
valid126 = true;
passing10 = 1;
if(props12 !== true){
props12 = true;
}
}
const _errs711 = errors;
if(errors === _errs711){
if(data238 && typeof data238 == "object" && !Array.isArray(data238)){
let missing92;
if((data238.conjunction === undefined) && (missing92 = "conjunction")){
const err731 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/2/required",keyword:"required",params:{missingProperty: missing92},message:"must have required property '"+missing92+"'"};
if(vErrors === null){
vErrors = [err731];
}
else {
vErrors.push(err731);
}
errors++;
}
else {
const _errs713 = errors;
for(const key92 in data238){
if(!(key92 === "conjunction")){
const err732 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key92},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err732];
}
else {
vErrors.push(err732);
}
errors++;
break;
}
}
if(_errs713 === errors){
if(data238.conjunction !== undefined){
let data249 = data238.conjunction;
const _errs714 = errors;
if(errors === _errs714){
if(data249 && typeof data249 == "object" && !Array.isArray(data249)){
if(Object.keys(data249).length > 0){
const err733 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/conjunction",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/2/properties/conjunction/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err733];
}
else {
vErrors.push(err733);
}
errors++;
}
}
else {
const err734 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/conjunction",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/2/properties/conjunction/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err734];
}
else {
vErrors.push(err734);
}
errors++;
}
}
}
}
}
}
else {
const err735 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err735];
}
else {
vErrors.push(err735);
}
errors++;
}
}
var _valid17 = _errs711 === errors;
if(_valid17 && valid126){
valid126 = false;
passing10 = [passing10, 2];
}
else {
if(_valid17){
valid126 = true;
passing10 = 2;
if(props12 !== true){
props12 = true;
}
}
const _errs716 = errors;
if(errors === _errs716){
if(data238 && typeof data238 == "object" && !Array.isArray(data238)){
let missing93;
if((data238.disjunction === undefined) && (missing93 = "disjunction")){
const err736 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/3/required",keyword:"required",params:{missingProperty: missing93},message:"must have required property '"+missing93+"'"};
if(vErrors === null){
vErrors = [err736];
}
else {
vErrors.push(err736);
}
errors++;
}
else {
const _errs718 = errors;
for(const key93 in data238){
if(!(key93 === "disjunction")){
const err737 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key93},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err737];
}
else {
vErrors.push(err737);
}
errors++;
break;
}
}
if(_errs718 === errors){
if(data238.disjunction !== undefined){
let data250 = data238.disjunction;
const _errs719 = errors;
if(errors === _errs719){
if(data250 && typeof data250 == "object" && !Array.isArray(data250)){
if(Object.keys(data250).length > 0){
const err738 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/disjunction",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/3/properties/disjunction/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err738];
}
else {
vErrors.push(err738);
}
errors++;
}
}
else {
const err739 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/disjunction",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/3/properties/disjunction/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err739];
}
else {
vErrors.push(err739);
}
errors++;
}
}
}
}
}
}
else {
const err740 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err740];
}
else {
vErrors.push(err740);
}
errors++;
}
}
var _valid17 = _errs716 === errors;
if(_valid17 && valid126){
valid126 = false;
passing10 = [passing10, 3];
}
else {
if(_valid17){
valid126 = true;
passing10 = 3;
if(props12 !== true){
props12 = true;
}
}
}
}
}
if(!valid126){
const err741 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf",keyword:"oneOf",params:{passingSchemas: passing10},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err741];
}
else {
vErrors.push(err741);
}
errors++;
}
else {
errors = _errs673;
if(vErrors !== null){
if(_errs673){
vErrors.length = _errs673;
}
else {
vErrors = null;
}
}
}
var valid125 = _errs672 === errors;
if(!valid125){
break;
}
}
}
}
else {
const err742 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err742];
}
else {
vErrors.push(err742);
}
errors++;
}
}
}
}
}
}
else {
const err743 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err743];
}
else {
vErrors.push(err743);
}
errors++;
}
}
var _valid16 = _errs667 === errors;
if(_valid16 && valid118){
valid118 = false;
passing9 = [passing9, 3];
}
else {
if(_valid16){
valid118 = true;
passing9 = 3;
if(props10 !== true){
props10 = true;
}
}
}
}
}
if(!valid118){
const err744 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf",keyword:"oneOf",params:{passingSchemas: passing9},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err744];
}
else {
vErrors.push(err744);
}
errors++;
}
else {
errors = _errs639;
if(vErrors !== null){
if(_errs639){
vErrors.length = _errs639;
}
else {
vErrors = null;
}
}
}
var valid116 = _errs638 === errors;
}
else {
var valid116 = true;
}
if(valid116){
if(data225.projection !== undefined){
let data251 = data225.projection;
const _errs721 = errors;
if(errors === _errs721){
if(Array.isArray(data251)){
if(data251.length > 8){
const err745 = {instancePath:instancePath+"/inspection/details/explanation/projection",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/projection/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err745];
}
else {
vErrors.push(err745);
}
errors++;
}
else {
var valid137 = true;
const len24 = data251.length;
for(let i24=0; i24<len24; i24++){
let data252 = data251[i24];
const _errs723 = errors;
if(errors === _errs723){
if(typeof data252 === "string"){
if(func1(data252) > 131072){
const err746 = {instancePath:instancePath+"/inspection/details/explanation/projection/" + i24,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/projection/items/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err746];
}
else {
vErrors.push(err746);
}
errors++;
}
}
else {
const err747 = {instancePath:instancePath+"/inspection/details/explanation/projection/" + i24,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/projection/items/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err747];
}
else {
vErrors.push(err747);
}
errors++;
}
}
var valid137 = _errs723 === errors;
if(!valid137){
break;
}
}
}
}
else {
const err748 = {instancePath:instancePath+"/inspection/details/explanation/projection",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/projection/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err748];
}
else {
vErrors.push(err748);
}
errors++;
}
}
var valid116 = _errs721 === errors;
}
else {
var valid116 = true;
}
if(valid116){
if(data225.limit !== undefined){
let data253 = data225.limit;
const _errs725 = errors;
const _errs726 = errors;
let valid138 = false;
const _errs727 = errors;
if(errors === _errs727){
if(typeof data253 === "string"){
if(func1(data253) > 131072){
const err749 = {instancePath:instancePath+"/inspection/details/explanation/limit",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/limit/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err750 = {instancePath:instancePath+"/inspection/details/explanation/limit",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/limit/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err750];
}
else {
vErrors.push(err750);
}
errors++;
}
}
var _valid19 = _errs727 === errors;
valid138 = valid138 || _valid19;
const _errs729 = errors;
if(data253 !== null){
const err751 = {instancePath:instancePath+"/inspection/details/explanation/limit",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/limit/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err751];
}
else {
vErrors.push(err751);
}
errors++;
}
var _valid19 = _errs729 === errors;
valid138 = valid138 || _valid19;
if(!valid138){
const err752 = {instancePath:instancePath+"/inspection/details/explanation/limit",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/limit/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err752];
}
else {
vErrors.push(err752);
}
errors++;
}
else {
errors = _errs726;
if(vErrors !== null){
if(_errs726){
vErrors.length = _errs726;
}
else {
vErrors = null;
}
}
}
var valid116 = _errs725 === errors;
}
else {
var valid116 = true;
}
if(valid116){
if(data225.aggregate !== undefined){
let data254 = data225.aggregate;
const _errs731 = errors;
if(typeof data254 !== "string"){
const err753 = {instancePath:instancePath+"/inspection/details/explanation/aggregate",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/aggregate/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err753];
}
else {
vErrors.push(err753);
}
errors++;
}
if(!((((data254 === "rows") || (data254 === "count")) || (data254 === "sum")) || (data254 === "count_values"))){
const err754 = {instancePath:instancePath+"/inspection/details/explanation/aggregate",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/aggregate/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.inspection.properties.details.oneOf[2].properties.explanation.properties.aggregate.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err754];
}
else {
vErrors.push(err754);
}
errors++;
}
var valid116 = _errs731 === errors;
}
else {
var valid116 = true;
}
if(valid116){
if(data225.columns !== undefined){
let data255 = data225.columns;
const _errs733 = errors;
if(errors === _errs733){
if(Array.isArray(data255)){
if(data255.length > 8){
const err755 = {instancePath:instancePath+"/inspection/details/explanation/columns",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/columns/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err755];
}
else {
vErrors.push(err755);
}
errors++;
}
else {
var valid139 = true;
const len25 = data255.length;
for(let i25=0; i25<len25; i25++){
let data256 = data255[i25];
const _errs735 = errors;
if(errors === _errs735){
if(data256 && typeof data256 == "object" && !Array.isArray(data256)){
let missing94;
if(((data256.name === undefined) && (missing94 = "name")) || ((data256.type === undefined) && (missing94 = "type"))){
const err756 = {instancePath:instancePath+"/inspection/details/explanation/columns/" + i25,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/columns/items/required",keyword:"required",params:{missingProperty: missing94},message:"must have required property '"+missing94+"'"};
if(vErrors === null){
vErrors = [err756];
}
else {
vErrors.push(err756);
}
errors++;
}
else {
const _errs737 = errors;
for(const key94 in data256){
if(!((key94 === "name") || (key94 === "type"))){
const err757 = {instancePath:instancePath+"/inspection/details/explanation/columns/" + i25,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/columns/items/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key94},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err757];
}
else {
vErrors.push(err757);
}
errors++;
break;
}
}
if(_errs737 === errors){
if(data256.name !== undefined){
let data257 = data256.name;
const _errs738 = errors;
if(errors === _errs738){
if(typeof data257 === "string"){
if(func1(data257) > 131072){
const err758 = {instancePath:instancePath+"/inspection/details/explanation/columns/" + i25+"/name",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/columns/items/properties/name/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err759 = {instancePath:instancePath+"/inspection/details/explanation/columns/" + i25+"/name",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/columns/items/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err759];
}
else {
vErrors.push(err759);
}
errors++;
}
}
var valid140 = _errs738 === errors;
}
else {
var valid140 = true;
}
if(valid140){
if(data256.type !== undefined){
let data258 = data256.type;
const _errs740 = errors;
if(typeof data258 !== "string"){
const err760 = {instancePath:instancePath+"/inspection/details/explanation/columns/" + i25+"/type",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/columns/items/properties/type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err760];
}
else {
vErrors.push(err760);
}
errors++;
}
if(!((((((data258 === "int64") || (data258 === "uint64")) || (data258 === "float64")) || (data258 === "boolean")) || (data258 === "utf8")) || (data258 === "binary"))){
const err761 = {instancePath:instancePath+"/inspection/details/explanation/columns/" + i25+"/type",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/columns/items/properties/type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.inspection.properties.details.oneOf[2].properties.explanation.properties.columns.items.properties.type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err761];
}
else {
vErrors.push(err761);
}
errors++;
}
var valid140 = _errs740 === errors;
}
else {
var valid140 = true;
}
}
}
}
}
else {
const err762 = {instancePath:instancePath+"/inspection/details/explanation/columns/" + i25,schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/columns/items/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err762];
}
else {
vErrors.push(err762);
}
errors++;
}
}
var valid139 = _errs735 === errors;
if(!valid139){
break;
}
}
}
}
else {
const err763 = {instancePath:instancePath+"/inspection/details/explanation/columns",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/columns/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err763];
}
else {
vErrors.push(err763);
}
errors++;
}
}
var valid116 = _errs733 === errors;
}
else {
var valid116 = true;
}
if(valid116){
if(data225.budgets !== undefined){
let data259 = data225.budgets;
const _errs742 = errors;
if(errors === _errs742){
if(data259 && typeof data259 == "object" && !Array.isArray(data259)){
let missing95;
if((((data259.pages === undefined) && (missing95 = "pages")) || ((data259.segments === undefined) && (missing95 = "segments"))) || ((data259.result_bytes === undefined) && (missing95 = "result_bytes"))){
const err764 = {instancePath:instancePath+"/inspection/details/explanation/budgets",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/budgets/required",keyword:"required",params:{missingProperty: missing95},message:"must have required property '"+missing95+"'"};
if(vErrors === null){
vErrors = [err764];
}
else {
vErrors.push(err764);
}
errors++;
}
else {
const _errs744 = errors;
for(const key95 in data259){
if(!(((key95 === "pages") || (key95 === "segments")) || (key95 === "result_bytes"))){
const err765 = {instancePath:instancePath+"/inspection/details/explanation/budgets",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/budgets/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key95},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err765];
}
else {
vErrors.push(err765);
}
errors++;
break;
}
}
if(_errs744 === errors){
if(data259.pages !== undefined){
let data260 = data259.pages;
const _errs745 = errors;
if(errors === _errs745){
if(typeof data260 === "string"){
if(func1(data260) > 131072){
const err766 = {instancePath:instancePath+"/inspection/details/explanation/budgets/pages",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/budgets/properties/pages/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err767 = {instancePath:instancePath+"/inspection/details/explanation/budgets/pages",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/budgets/properties/pages/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err767];
}
else {
vErrors.push(err767);
}
errors++;
}
}
var valid141 = _errs745 === errors;
}
else {
var valid141 = true;
}
if(valid141){
if(data259.segments !== undefined){
let data261 = data259.segments;
const _errs747 = errors;
if(errors === _errs747){
if(typeof data261 === "string"){
if(func1(data261) > 131072){
const err768 = {instancePath:instancePath+"/inspection/details/explanation/budgets/segments",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/budgets/properties/segments/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err769 = {instancePath:instancePath+"/inspection/details/explanation/budgets/segments",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/budgets/properties/segments/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err769];
}
else {
vErrors.push(err769);
}
errors++;
}
}
var valid141 = _errs747 === errors;
}
else {
var valid141 = true;
}
if(valid141){
if(data259.result_bytes !== undefined){
let data262 = data259.result_bytes;
const _errs749 = errors;
if(errors === _errs749){
if(typeof data262 === "string"){
if(func1(data262) > 131072){
const err770 = {instancePath:instancePath+"/inspection/details/explanation/budgets/result_bytes",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/budgets/properties/result_bytes/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err771 = {instancePath:instancePath+"/inspection/details/explanation/budgets/result_bytes",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/budgets/properties/result_bytes/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err771];
}
else {
vErrors.push(err771);
}
errors++;
}
}
var valid141 = _errs749 === errors;
}
else {
var valid141 = true;
}
}
}
}
}
}
else {
const err772 = {instancePath:instancePath+"/inspection/details/explanation/budgets",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/budgets/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err772];
}
else {
vErrors.push(err772);
}
errors++;
}
}
var valid116 = _errs742 === errors;
}
else {
var valid116 = true;
}
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
const err773 = {instancePath:instancePath+"/inspection/details/explanation",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/properties/explanation/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err773];
}
else {
vErrors.push(err773);
}
errors++;
}
}
}
}
}
}
else {
const err774 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err774];
}
else {
vErrors.push(err774);
}
errors++;
}
}
var _valid15 = _errs628 === errors;
if(_valid15 && valid108){
valid108 = false;
passing8 = [passing8, 2];
}
else {
if(_valid15){
valid108 = true;
passing8 = 2;
if(props9 !== true){
props9 = true;
}
}
}
}
if(!valid108){
const err775 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/4/properties/inspection/properties/details/oneOf",keyword:"oneOf",params:{passingSchemas: passing8},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err775];
}
else {
vErrors.push(err775);
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
var valid105 = _errs604 === errors;
}
else {
var valid105 = true;
}
}
}
}
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
const err776 = {instancePath:instancePath+"/inspection",schemaPath:"#/oneOf/4/properties/inspection/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err776];
}
else {
vErrors.push(err776);
}
errors++;
}
}
}
}
}
}
else {
const err777 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err777];
}
else {
vErrors.push(err777);
}
errors++;
}
}
var _valid0 = _errs576 === errors;
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
const _errs751 = errors;
if(errors === _errs751){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing96;
if((data.prepared === undefined) && (missing96 = "prepared")){
const err778 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing96},message:"must have required property '"+missing96+"'"};
if(vErrors === null){
vErrors = [err778];
}
else {
vErrors.push(err778);
}
errors++;
}
else {
const _errs753 = errors;
for(const key96 in data){
if(!(key96 === "prepared")){
const err779 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key96},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err779];
}
else {
vErrors.push(err779);
}
errors++;
break;
}
}
if(_errs753 === errors){
if(data.prepared !== undefined){
let data263 = data.prepared;
const _errs755 = errors;
let valid143 = false;
const _errs756 = errors;
if(errors === _errs756){
if(data263 && typeof data263 == "object" && !Array.isArray(data263)){
let missing97;
if((data263.token === undefined) && (missing97 = "token")){
const err780 = {instancePath:instancePath+"/prepared",schemaPath:"#/oneOf/5/properties/prepared/anyOf/0/required",keyword:"required",params:{missingProperty: missing97},message:"must have required property '"+missing97+"'"};
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
for(const key97 in data263){
if(!(key97 === "token")){
const err781 = {instancePath:instancePath+"/prepared",schemaPath:"#/oneOf/5/properties/prepared/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key97},message:"must NOT have additional properties"};
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
if(data263.token !== undefined){
let data264 = data263.token;
const _errs759 = errors;
if(errors === _errs759){
if(typeof data264 === "string"){
if(func1(data264) > 131072){
const err782 = {instancePath:instancePath+"/prepared/token",schemaPath:"#/oneOf/5/properties/prepared/anyOf/0/properties/token/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err783 = {instancePath:instancePath+"/prepared/token",schemaPath:"#/oneOf/5/properties/prepared/anyOf/0/properties/token/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err783];
}
else {
vErrors.push(err783);
}
errors++;
}
}
}
}
}
}
else {
const err784 = {instancePath:instancePath+"/prepared",schemaPath:"#/oneOf/5/properties/prepared/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err784];
}
else {
vErrors.push(err784);
}
errors++;
}
}
var _valid20 = _errs756 === errors;
valid143 = valid143 || _valid20;
const _errs761 = errors;
if(data263 !== null){
const err785 = {instancePath:instancePath+"/prepared",schemaPath:"#/oneOf/5/properties/prepared/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err785];
}
else {
vErrors.push(err785);
}
errors++;
}
var _valid20 = _errs761 === errors;
valid143 = valid143 || _valid20;
if(!valid143){
const err786 = {instancePath:instancePath+"/prepared",schemaPath:"#/oneOf/5/properties/prepared/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err786];
}
else {
vErrors.push(err786);
}
errors++;
}
else {
errors = _errs755;
if(vErrors !== null){
if(_errs755){
vErrors.length = _errs755;
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
const err787 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err787];
}
else {
vErrors.push(err787);
}
errors++;
}
}
var _valid0 = _errs751 === errors;
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
const _errs763 = errors;
if(errors === _errs763){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing98;
if((data.receipt === undefined) && (missing98 = "receipt")){
const err788 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing98},message:"must have required property '"+missing98+"'"};
if(vErrors === null){
vErrors = [err788];
}
else {
vErrors.push(err788);
}
errors++;
}
else {
const _errs765 = errors;
for(const key98 in data){
if(!(key98 === "receipt")){
const err789 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key98},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err789];
}
else {
vErrors.push(err789);
}
errors++;
break;
}
}
if(_errs765 === errors){
if(data.receipt !== undefined){
let data265 = data.receipt;
const _errs766 = errors;
if(errors === _errs766){
if(data265 && typeof data265 == "object" && !Array.isArray(data265)){
let missing99;
if((data265.position === undefined) && (missing99 = "position")){
const err790 = {instancePath:instancePath+"/receipt",schemaPath:"#/oneOf/6/properties/receipt/required",keyword:"required",params:{missingProperty: missing99},message:"must have required property '"+missing99+"'"};
if(vErrors === null){
vErrors = [err790];
}
else {
vErrors.push(err790);
}
errors++;
}
else {
const _errs768 = errors;
for(const key99 in data265){
if(!(key99 === "position")){
const err791 = {instancePath:instancePath+"/receipt",schemaPath:"#/oneOf/6/properties/receipt/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key99},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err791];
}
else {
vErrors.push(err791);
}
errors++;
break;
}
}
if(_errs768 === errors){
if(data265.position !== undefined){
let data266 = data265.position;
const _errs769 = errors;
if(!(((typeof data266 == "number") && (!(data266 % 1) && !isNaN(data266))) && (isFinite(data266)))){
const err792 = {instancePath:instancePath+"/receipt/position",schemaPath:"#/oneOf/6/properties/receipt/properties/position/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err792];
}
else {
vErrors.push(err792);
}
errors++;
}
if(errors === _errs769){
if((typeof data266 == "number") && (isFinite(data266))){
if(data266 > 9007199254740991 || isNaN(data266)){
const err793 = {instancePath:instancePath+"/receipt/position",schemaPath:"#/oneOf/6/properties/receipt/properties/position/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err793];
}
else {
vErrors.push(err793);
}
errors++;
}
else {
if(data266 < 0 || isNaN(data266)){
const err794 = {instancePath:instancePath+"/receipt/position",schemaPath:"#/oneOf/6/properties/receipt/properties/position/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err794];
}
else {
vErrors.push(err794);
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
const err795 = {instancePath:instancePath+"/receipt",schemaPath:"#/oneOf/6/properties/receipt/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err795];
}
else {
vErrors.push(err795);
}
errors++;
}
}
}
}
}
}
else {
const err796 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err796];
}
else {
vErrors.push(err796);
}
errors++;
}
}
var _valid0 = _errs763 === errors;
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
const _errs771 = errors;
if(errors === _errs771){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing100;
if((data.observation === undefined) && (missing100 = "observation")){
const err797 = {instancePath,schemaPath:"#/oneOf/7/required",keyword:"required",params:{missingProperty: missing100},message:"must have required property '"+missing100+"'"};
if(vErrors === null){
vErrors = [err797];
}
else {
vErrors.push(err797);
}
errors++;
}
else {
const _errs773 = errors;
for(const key100 in data){
if(!(key100 === "observation")){
const err798 = {instancePath,schemaPath:"#/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key100},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err798];
}
else {
vErrors.push(err798);
}
errors++;
break;
}
}
if(_errs773 === errors){
if(data.observation !== undefined){
let data267 = data.observation;
const _errs775 = errors;
let valid148 = false;
let passing12 = null;
const _errs776 = errors;
if(errors === _errs776){
if(data267 && typeof data267 == "object" && !Array.isArray(data267)){
let missing101;
if((data267.pending === undefined) && (missing101 = "pending")){
const err799 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/7/properties/observation/oneOf/0/required",keyword:"required",params:{missingProperty: missing101},message:"must have required property '"+missing101+"'"};
if(vErrors === null){
vErrors = [err799];
}
else {
vErrors.push(err799);
}
errors++;
}
else {
const _errs778 = errors;
for(const key101 in data267){
if(!(key101 === "pending")){
const err800 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/7/properties/observation/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key101},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err800];
}
else {
vErrors.push(err800);
}
errors++;
break;
}
}
if(_errs778 === errors){
if(data267.pending !== undefined){
let data268 = data267.pending;
const _errs779 = errors;
if(errors === _errs779){
if(data268 && typeof data268 == "object" && !Array.isArray(data268)){
if(Object.keys(data268).length > 0){
const err801 = {instancePath:instancePath+"/observation/pending",schemaPath:"#/oneOf/7/properties/observation/oneOf/0/properties/pending/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
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
const err802 = {instancePath:instancePath+"/observation/pending",schemaPath:"#/oneOf/7/properties/observation/oneOf/0/properties/pending/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err802];
}
else {
vErrors.push(err802);
}
errors++;
}
}
}
}
}
}
else {
const err803 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/7/properties/observation/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err803];
}
else {
vErrors.push(err803);
}
errors++;
}
}
var _valid21 = _errs776 === errors;
if(_valid21){
valid148 = true;
passing12 = 0;
var props14 = true;
}
const _errs781 = errors;
if(errors === _errs781){
if(data267 && typeof data267 == "object" && !Array.isArray(data267)){
let missing102;
if((data267.committed === undefined) && (missing102 = "committed")){
const err804 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/7/properties/observation/oneOf/1/required",keyword:"required",params:{missingProperty: missing102},message:"must have required property '"+missing102+"'"};
if(vErrors === null){
vErrors = [err804];
}
else {
vErrors.push(err804);
}
errors++;
}
else {
const _errs783 = errors;
for(const key102 in data267){
if(!(key102 === "committed")){
const err805 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/7/properties/observation/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key102},message:"must NOT have additional properties"};
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
if(_errs783 === errors){
if(data267.committed !== undefined){
let data269 = data267.committed;
const _errs784 = errors;
if(errors === _errs784){
if(data269 && typeof data269 == "object" && !Array.isArray(data269)){
if(Object.keys(data269).length > 0){
const err806 = {instancePath:instancePath+"/observation/committed",schemaPath:"#/oneOf/7/properties/observation/oneOf/1/properties/committed/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err806];
}
else {
vErrors.push(err806);
}
errors++;
}
}
else {
const err807 = {instancePath:instancePath+"/observation/committed",schemaPath:"#/oneOf/7/properties/observation/oneOf/1/properties/committed/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err807];
}
else {
vErrors.push(err807);
}
errors++;
}
}
}
}
}
}
else {
const err808 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/7/properties/observation/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err808];
}
else {
vErrors.push(err808);
}
errors++;
}
}
var _valid21 = _errs781 === errors;
if(_valid21 && valid148){
valid148 = false;
passing12 = [passing12, 1];
}
else {
if(_valid21){
valid148 = true;
passing12 = 1;
if(props14 !== true){
props14 = true;
}
}
const _errs786 = errors;
if(errors === _errs786){
if(data267 && typeof data267 == "object" && !Array.isArray(data267)){
let missing103;
if((data267.rejected === undefined) && (missing103 = "rejected")){
const err809 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/7/properties/observation/oneOf/2/required",keyword:"required",params:{missingProperty: missing103},message:"must have required property '"+missing103+"'"};
if(vErrors === null){
vErrors = [err809];
}
else {
vErrors.push(err809);
}
errors++;
}
else {
const _errs788 = errors;
for(const key103 in data267){
if(!(key103 === "rejected")){
const err810 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/7/properties/observation/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key103},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err810];
}
else {
vErrors.push(err810);
}
errors++;
break;
}
}
if(_errs788 === errors){
if(data267.rejected !== undefined){
let data270 = data267.rejected;
const _errs789 = errors;
if(errors === _errs789){
if(typeof data270 === "string"){
if(func1(data270) > 512){
const err811 = {instancePath:instancePath+"/observation/rejected",schemaPath:"#/oneOf/7/properties/observation/oneOf/2/properties/rejected/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err811];
}
else {
vErrors.push(err811);
}
errors++;
}
else {
if(!pattern4.test(data270)){
const err812 = {instancePath:instancePath+"/observation/rejected",schemaPath:"#/oneOf/7/properties/observation/oneOf/2/properties/rejected/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
if(vErrors === null){
vErrors = [err812];
}
else {
vErrors.push(err812);
}
errors++;
}
}
}
else {
const err813 = {instancePath:instancePath+"/observation/rejected",schemaPath:"#/oneOf/7/properties/observation/oneOf/2/properties/rejected/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err813];
}
else {
vErrors.push(err813);
}
errors++;
}
}
}
}
}
}
else {
const err814 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/7/properties/observation/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err814];
}
else {
vErrors.push(err814);
}
errors++;
}
}
var _valid21 = _errs786 === errors;
if(_valid21 && valid148){
valid148 = false;
passing12 = [passing12, 2];
}
else {
if(_valid21){
valid148 = true;
passing12 = 2;
if(props14 !== true){
props14 = true;
}
}
}
}
if(!valid148){
const err815 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/7/properties/observation/oneOf",keyword:"oneOf",params:{passingSchemas: passing12},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err815];
}
else {
vErrors.push(err815);
}
errors++;
}
else {
errors = _errs775;
if(vErrors !== null){
if(_errs775){
vErrors.length = _errs775;
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
const err816 = {instancePath,schemaPath:"#/oneOf/7/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err816];
}
else {
vErrors.push(err816);
}
errors++;
}
}
var _valid0 = _errs771 === errors;
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
const _errs791 = errors;
if(errors === _errs791){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing104;
if((data.status === undefined) && (missing104 = "status")){
const err817 = {instancePath,schemaPath:"#/oneOf/8/required",keyword:"required",params:{missingProperty: missing104},message:"must have required property '"+missing104+"'"};
if(vErrors === null){
vErrors = [err817];
}
else {
vErrors.push(err817);
}
errors++;
}
else {
const _errs793 = errors;
for(const key104 in data){
if(!(key104 === "status")){
const err818 = {instancePath,schemaPath:"#/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key104},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err818];
}
else {
vErrors.push(err818);
}
errors++;
break;
}
}
if(_errs793 === errors){
if(data.status !== undefined){
let data271 = data.status;
const _errs795 = errors;
let valid153 = false;
const _errs796 = errors;
if(errors === _errs796){
if(data271 && typeof data271 == "object" && !Array.isArray(data271)){
let missing105;
if((((((data271.reference === undefined) && (missing105 = "reference")) || ((data271.phase === undefined) && (missing105 = "phase"))) || ((data271.correlation === undefined) && (missing105 = "correlation"))) || ((data271.manifest === undefined) && (missing105 = "manifest"))) || ((data271.collected === undefined) && (missing105 = "collected"))){
const err819 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/8/properties/status/anyOf/0/required",keyword:"required",params:{missingProperty: missing105},message:"must have required property '"+missing105+"'"};
if(vErrors === null){
vErrors = [err819];
}
else {
vErrors.push(err819);
}
errors++;
}
else {
const _errs798 = errors;
for(const key105 in data271){
if(!(((((key105 === "reference") || (key105 === "phase")) || (key105 === "correlation")) || (key105 === "manifest")) || (key105 === "collected"))){
const err820 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/8/properties/status/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key105},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err820];
}
else {
vErrors.push(err820);
}
errors++;
break;
}
}
if(_errs798 === errors){
if(data271.reference !== undefined){
let data272 = data271.reference;
const _errs799 = errors;
if(errors === _errs799){
if(typeof data272 === "string"){
if(func1(data272) > 512){
const err821 = {instancePath:instancePath+"/status/reference",schemaPath:"#/oneOf/8/properties/status/anyOf/0/properties/reference/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err821];
}
else {
vErrors.push(err821);
}
errors++;
}
else {
if(!pattern4.test(data272)){
const err822 = {instancePath:instancePath+"/status/reference",schemaPath:"#/oneOf/8/properties/status/anyOf/0/properties/reference/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
if(vErrors === null){
vErrors = [err822];
}
else {
vErrors.push(err822);
}
errors++;
}
}
}
else {
const err823 = {instancePath:instancePath+"/status/reference",schemaPath:"#/oneOf/8/properties/status/anyOf/0/properties/reference/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err823];
}
else {
vErrors.push(err823);
}
errors++;
}
}
var valid154 = _errs799 === errors;
}
else {
var valid154 = true;
}
if(valid154){
if(data271.phase !== undefined){
let data273 = data271.phase;
const _errs801 = errors;
if(typeof data273 !== "string"){
const err824 = {instancePath:instancePath+"/status/phase",schemaPath:"#/oneOf/8/properties/status/anyOf/0/properties/phase/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err824];
}
else {
vErrors.push(err824);
}
errors++;
}
if(!((((((((data273 === "uploading") || (data273 === "sealed")) || (data273 === "admitted")) || (data273 === "complete")) || (data273 === "cancelled")) || (data273 === "denied")) || (data273 === "rejected")) || (data273 === "retired"))){
const err825 = {instancePath:instancePath+"/status/phase",schemaPath:"#/oneOf/8/properties/status/anyOf/0/properties/phase/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[8].properties.status.anyOf[0].properties.phase.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err825];
}
else {
vErrors.push(err825);
}
errors++;
}
var valid154 = _errs801 === errors;
}
else {
var valid154 = true;
}
if(valid154){
if(data271.correlation !== undefined){
let data274 = data271.correlation;
const _errs803 = errors;
if(errors === _errs803){
if(typeof data274 === "string"){
if(func1(data274) > 131072){
const err826 = {instancePath:instancePath+"/status/correlation",schemaPath:"#/oneOf/8/properties/status/anyOf/0/properties/correlation/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err826];
}
else {
vErrors.push(err826);
}
errors++;
}
}
else {
const err827 = {instancePath:instancePath+"/status/correlation",schemaPath:"#/oneOf/8/properties/status/anyOf/0/properties/correlation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err827];
}
else {
vErrors.push(err827);
}
errors++;
}
}
var valid154 = _errs803 === errors;
}
else {
var valid154 = true;
}
if(valid154){
if(data271.manifest !== undefined){
let data275 = data271.manifest;
const _errs805 = errors;
const _errs806 = errors;
let valid155 = false;
const _errs807 = errors;
if(errors === _errs807){
if(typeof data275 === "string"){
if(func1(data275) > 512){
const err828 = {instancePath:instancePath+"/status/manifest",schemaPath:"#/oneOf/8/properties/status/anyOf/0/properties/manifest/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err828];
}
else {
vErrors.push(err828);
}
errors++;
}
else {
if(!pattern4.test(data275)){
const err829 = {instancePath:instancePath+"/status/manifest",schemaPath:"#/oneOf/8/properties/status/anyOf/0/properties/manifest/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
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
else {
const err830 = {instancePath:instancePath+"/status/manifest",schemaPath:"#/oneOf/8/properties/status/anyOf/0/properties/manifest/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err830];
}
else {
vErrors.push(err830);
}
errors++;
}
}
var _valid23 = _errs807 === errors;
valid155 = valid155 || _valid23;
const _errs809 = errors;
if(data275 !== null){
const err831 = {instancePath:instancePath+"/status/manifest",schemaPath:"#/oneOf/8/properties/status/anyOf/0/properties/manifest/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err831];
}
else {
vErrors.push(err831);
}
errors++;
}
var _valid23 = _errs809 === errors;
valid155 = valid155 || _valid23;
if(!valid155){
const err832 = {instancePath:instancePath+"/status/manifest",schemaPath:"#/oneOf/8/properties/status/anyOf/0/properties/manifest/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err832];
}
else {
vErrors.push(err832);
}
errors++;
}
else {
errors = _errs806;
if(vErrors !== null){
if(_errs806){
vErrors.length = _errs806;
}
else {
vErrors = null;
}
}
}
var valid154 = _errs805 === errors;
}
else {
var valid154 = true;
}
if(valid154){
if(data271.collected !== undefined){
const _errs811 = errors;
if(typeof data271.collected !== "boolean"){
const err833 = {instancePath:instancePath+"/status/collected",schemaPath:"#/oneOf/8/properties/status/anyOf/0/properties/collected/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err833];
}
else {
vErrors.push(err833);
}
errors++;
}
var valid154 = _errs811 === errors;
}
else {
var valid154 = true;
}
}
}
}
}
}
}
}
else {
const err834 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/8/properties/status/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err834];
}
else {
vErrors.push(err834);
}
errors++;
}
}
var _valid22 = _errs796 === errors;
valid153 = valid153 || _valid22;
const _errs813 = errors;
if(data271 !== null){
const err835 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/8/properties/status/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err835];
}
else {
vErrors.push(err835);
}
errors++;
}
var _valid22 = _errs813 === errors;
valid153 = valid153 || _valid22;
if(!valid153){
const err836 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/8/properties/status/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err836];
}
else {
vErrors.push(err836);
}
errors++;
}
else {
errors = _errs795;
if(vErrors !== null){
if(_errs795){
vErrors.length = _errs795;
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
const err837 = {instancePath,schemaPath:"#/oneOf/8/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err837];
}
else {
vErrors.push(err837);
}
errors++;
}
}
var _valid0 = _errs791 === errors;
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
const _errs815 = errors;
if(errors === _errs815){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing106;
if((data.page === undefined) && (missing106 = "page")){
const err838 = {instancePath,schemaPath:"#/oneOf/9/required",keyword:"required",params:{missingProperty: missing106},message:"must have required property '"+missing106+"'"};
if(vErrors === null){
vErrors = [err838];
}
else {
vErrors.push(err838);
}
errors++;
}
else {
const _errs817 = errors;
for(const key106 in data){
if(!(key106 === "page")){
const err839 = {instancePath,schemaPath:"#/oneOf/9/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key106},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err839];
}
else {
vErrors.push(err839);
}
errors++;
break;
}
}
if(_errs817 === errors){
if(data.page !== undefined){
let data277 = data.page;
const _errs818 = errors;
if(errors === _errs818){
if(data277 && typeof data277 == "object" && !Array.isArray(data277)){
let missing107;
if(((data277.evidence === undefined) && (missing107 = "evidence")) || ((data277.cells === undefined) && (missing107 = "cells"))){
const err840 = {instancePath:instancePath+"/page",schemaPath:"#/oneOf/9/properties/page/required",keyword:"required",params:{missingProperty: missing107},message:"must have required property '"+missing107+"'"};
if(vErrors === null){
vErrors = [err840];
}
else {
vErrors.push(err840);
}
errors++;
}
else {
const _errs820 = errors;
for(const key107 in data277){
if(!((key107 === "evidence") || (key107 === "cells"))){
const err841 = {instancePath:instancePath+"/page",schemaPath:"#/oneOf/9/properties/page/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key107},message:"must NOT have additional properties"};
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
if(_errs820 === errors){
if(data277.evidence !== undefined){
let data278 = data277.evidence;
const _errs821 = errors;
if(errors === _errs821){
if(data278 && typeof data278 == "object" && !Array.isArray(data278)){
let missing108;
if(((((((data278.manifest === undefined) && (missing108 = "manifest")) || ((data278.columns === undefined) && (missing108 = "columns"))) || ((data278.ordinal === undefined) && (missing108 = "ordinal"))) || ((data278.rows === undefined) && (missing108 = "rows"))) || ((data278.ipc === undefined) && (missing108 = "ipc"))) || ((data278.next === undefined) && (missing108 = "next"))){
const err842 = {instancePath:instancePath+"/page/evidence",schemaPath:"#/oneOf/9/properties/page/properties/evidence/required",keyword:"required",params:{missingProperty: missing108},message:"must have required property '"+missing108+"'"};
if(vErrors === null){
vErrors = [err842];
}
else {
vErrors.push(err842);
}
errors++;
}
else {
const _errs823 = errors;
for(const key108 in data278){
if(!((((((key108 === "manifest") || (key108 === "columns")) || (key108 === "ordinal")) || (key108 === "rows")) || (key108 === "ipc")) || (key108 === "next"))){
const err843 = {instancePath:instancePath+"/page/evidence",schemaPath:"#/oneOf/9/properties/page/properties/evidence/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key108},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err843];
}
else {
vErrors.push(err843);
}
errors++;
break;
}
}
if(_errs823 === errors){
if(data278.manifest !== undefined){
let data279 = data278.manifest;
const _errs824 = errors;
if(errors === _errs824){
if(data279 && typeof data279 == "object" && !Array.isArray(data279)){
let missing109;
if(((((((((((((((((((data279.job === undefined) && (missing109 = "job")) || ((data279.source === undefined) && (missing109 = "source"))) || ((data279.requester === undefined) && (missing109 = "requester"))) || ((data279.correlation === undefined) && (missing109 = "correlation"))) || ((data279.policy_revision === undefined) && (missing109 = "policy_revision"))) || ((data279.request === undefined) && (missing109 = "request"))) || ((data279.basis === undefined) && (missing109 = "basis"))) || ((data279.plan === undefined) && (missing109 = "plan"))) || ((data279.pages === undefined) && (missing109 = "pages"))) || ((data279.scanned === undefined) && (missing109 = "scanned"))) || ((data279.selected === undefined) && (missing109 = "selected"))) || ((data279.value_count === undefined) && (missing109 = "value_count"))) || ((data279.segments === undefined) && (missing109 = "segments"))) || ((data279.rows === undefined) && (missing109 = "rows"))) || ((data279.bytes === undefined) && (missing109 = "bytes"))) || ((data279.sum === undefined) && (missing109 = "sum"))) || ((data279.finished === undefined) && (missing109 = "finished"))) || ((data279.chain === undefined) && (missing109 = "chain"))){
const err844 = {instancePath:instancePath+"/page/evidence/manifest",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/required",keyword:"required",params:{missingProperty: missing109},message:"must have required property '"+missing109+"'"};
if(vErrors === null){
vErrors = [err844];
}
else {
vErrors.push(err844);
}
errors++;
}
else {
const _errs826 = errors;
for(const key109 in data279){
if(!(func19.call(schema33.oneOf[9].properties.page.properties.evidence.properties.manifest.properties, key109))){
const err845 = {instancePath:instancePath+"/page/evidence/manifest",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key109},message:"must NOT have additional properties"};
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
if(_errs826 === errors){
if(data279.job !== undefined){
let data280 = data279.job;
const _errs827 = errors;
if(!(((typeof data280 == "number") && (!(data280 % 1) && !isNaN(data280))) && (isFinite(data280)))){
const err846 = {instancePath:instancePath+"/page/evidence/manifest/job",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/job/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err846];
}
else {
vErrors.push(err846);
}
errors++;
}
if(errors === _errs827){
if((typeof data280 == "number") && (isFinite(data280))){
if(data280 > 9007199254740991 || isNaN(data280)){
const err847 = {instancePath:instancePath+"/page/evidence/manifest/job",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/job/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err847];
}
else {
vErrors.push(err847);
}
errors++;
}
else {
if(data280 < 0 || isNaN(data280)){
const err848 = {instancePath:instancePath+"/page/evidence/manifest/job",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/job/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err848];
}
else {
vErrors.push(err848);
}
errors++;
}
}
}
}
var valid159 = _errs827 === errors;
}
else {
var valid159 = true;
}
if(valid159){
if(data279.source !== undefined){
let data281 = data279.source;
const _errs829 = errors;
if(errors === _errs829){
if(data281 && typeof data281 == "object" && !Array.isArray(data281)){
let missing110;
if((((data281.pid === undefined) && (missing110 = "pid")) || ((data281.input === undefined) && (missing110 = "input"))) || ((data281.index === undefined) && (missing110 = "index"))){
const err849 = {instancePath:instancePath+"/page/evidence/manifest/source",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/source/required",keyword:"required",params:{missingProperty: missing110},message:"must have required property '"+missing110+"'"};
if(vErrors === null){
vErrors = [err849];
}
else {
vErrors.push(err849);
}
errors++;
}
else {
const _errs831 = errors;
for(const key110 in data281){
if(!(((key110 === "pid") || (key110 === "input")) || (key110 === "index"))){
const err850 = {instancePath:instancePath+"/page/evidence/manifest/source",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/source/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key110},message:"must NOT have additional properties"};
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
if(_errs831 === errors){
if(data281.pid !== undefined){
let data282 = data281.pid;
const _errs832 = errors;
if(!(((typeof data282 == "number") && (!(data282 % 1) && !isNaN(data282))) && (isFinite(data282)))){
const err851 = {instancePath:instancePath+"/page/evidence/manifest/source/pid",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/source/properties/pid/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err851];
}
else {
vErrors.push(err851);
}
errors++;
}
if(errors === _errs832){
if((typeof data282 == "number") && (isFinite(data282))){
if(data282 > 9007199254740991 || isNaN(data282)){
const err852 = {instancePath:instancePath+"/page/evidence/manifest/source/pid",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/source/properties/pid/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err852];
}
else {
vErrors.push(err852);
}
errors++;
}
else {
if(data282 < 0 || isNaN(data282)){
const err853 = {instancePath:instancePath+"/page/evidence/manifest/source/pid",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/source/properties/pid/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err853];
}
else {
vErrors.push(err853);
}
errors++;
}
}
}
}
var valid160 = _errs832 === errors;
}
else {
var valid160 = true;
}
if(valid160){
if(data281.input !== undefined){
let data283 = data281.input;
const _errs834 = errors;
if(!(((typeof data283 == "number") && (!(data283 % 1) && !isNaN(data283))) && (isFinite(data283)))){
const err854 = {instancePath:instancePath+"/page/evidence/manifest/source/input",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/source/properties/input/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err854];
}
else {
vErrors.push(err854);
}
errors++;
}
if(errors === _errs834){
if((typeof data283 == "number") && (isFinite(data283))){
if(data283 > 9007199254740991 || isNaN(data283)){
const err855 = {instancePath:instancePath+"/page/evidence/manifest/source/input",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/source/properties/input/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err855];
}
else {
vErrors.push(err855);
}
errors++;
}
else {
if(data283 < 0 || isNaN(data283)){
const err856 = {instancePath:instancePath+"/page/evidence/manifest/source/input",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/source/properties/input/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err856];
}
else {
vErrors.push(err856);
}
errors++;
}
}
}
}
var valid160 = _errs834 === errors;
}
else {
var valid160 = true;
}
if(valid160){
if(data281.index !== undefined){
let data284 = data281.index;
const _errs836 = errors;
if(!(((typeof data284 == "number") && (!(data284 % 1) && !isNaN(data284))) && (isFinite(data284)))){
const err857 = {instancePath:instancePath+"/page/evidence/manifest/source/index",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/source/properties/index/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err857];
}
else {
vErrors.push(err857);
}
errors++;
}
if(errors === _errs836){
if((typeof data284 == "number") && (isFinite(data284))){
if(data284 > 255 || isNaN(data284)){
const err858 = {instancePath:instancePath+"/page/evidence/manifest/source/index",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/source/properties/index/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err858];
}
else {
vErrors.push(err858);
}
errors++;
}
else {
if(data284 < 0 || isNaN(data284)){
const err859 = {instancePath:instancePath+"/page/evidence/manifest/source/index",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/source/properties/index/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err859];
}
else {
vErrors.push(err859);
}
errors++;
}
}
}
}
var valid160 = _errs836 === errors;
}
else {
var valid160 = true;
}
}
}
}
}
}
else {
const err860 = {instancePath:instancePath+"/page/evidence/manifest/source",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/source/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err860];
}
else {
vErrors.push(err860);
}
errors++;
}
}
var valid159 = _errs829 === errors;
}
else {
var valid159 = true;
}
if(valid159){
if(data279.requester !== undefined){
let data285 = data279.requester;
const _errs838 = errors;
if(!(((typeof data285 == "number") && (!(data285 % 1) && !isNaN(data285))) && (isFinite(data285)))){
const err861 = {instancePath:instancePath+"/page/evidence/manifest/requester",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/requester/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err861];
}
else {
vErrors.push(err861);
}
errors++;
}
if(errors === _errs838){
if((typeof data285 == "number") && (isFinite(data285))){
if(data285 > 9007199254740991 || isNaN(data285)){
const err862 = {instancePath:instancePath+"/page/evidence/manifest/requester",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/requester/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err862];
}
else {
vErrors.push(err862);
}
errors++;
}
else {
if(data285 < 0 || isNaN(data285)){
const err863 = {instancePath:instancePath+"/page/evidence/manifest/requester",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/requester/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err863];
}
else {
vErrors.push(err863);
}
errors++;
}
}
}
}
var valid159 = _errs838 === errors;
}
else {
var valid159 = true;
}
if(valid159){
if(data279.correlation !== undefined){
let data286 = data279.correlation;
const _errs840 = errors;
if(errors === _errs840){
if(typeof data286 === "string"){
if(func1(data286) > 131072){
const err864 = {instancePath:instancePath+"/page/evidence/manifest/correlation",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/correlation/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err864];
}
else {
vErrors.push(err864);
}
errors++;
}
}
else {
const err865 = {instancePath:instancePath+"/page/evidence/manifest/correlation",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/correlation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err865];
}
else {
vErrors.push(err865);
}
errors++;
}
}
var valid159 = _errs840 === errors;
}
else {
var valid159 = true;
}
if(valid159){
if(data279.policy_revision !== undefined){
let data287 = data279.policy_revision;
const _errs842 = errors;
if(errors === _errs842){
if(typeof data287 === "string"){
if(func1(data287) > 131072){
const err866 = {instancePath:instancePath+"/page/evidence/manifest/policy_revision",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/policy_revision/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err866];
}
else {
vErrors.push(err866);
}
errors++;
}
}
else {
const err867 = {instancePath:instancePath+"/page/evidence/manifest/policy_revision",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/policy_revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err867];
}
else {
vErrors.push(err867);
}
errors++;
}
}
var valid159 = _errs842 === errors;
}
else {
var valid159 = true;
}
if(valid159){
if(data279.request !== undefined){
let data288 = data279.request;
const _errs844 = errors;
if(errors === _errs844){
if(typeof data288 === "string"){
if(func1(data288) > 512){
const err868 = {instancePath:instancePath+"/page/evidence/manifest/request",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/request/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err868];
}
else {
vErrors.push(err868);
}
errors++;
}
else {
if(!pattern4.test(data288)){
const err869 = {instancePath:instancePath+"/page/evidence/manifest/request",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/request/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
if(vErrors === null){
vErrors = [err869];
}
else {
vErrors.push(err869);
}
errors++;
}
}
}
else {
const err870 = {instancePath:instancePath+"/page/evidence/manifest/request",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/request/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err870];
}
else {
vErrors.push(err870);
}
errors++;
}
}
var valid159 = _errs844 === errors;
}
else {
var valid159 = true;
}
if(valid159){
if(data279.basis !== undefined){
let data289 = data279.basis;
const _errs846 = errors;
if(errors === _errs846){
if(data289 && typeof data289 == "object" && !Array.isArray(data289)){
let missing111;
if((((((data289.kind === undefined) && (missing111 = "kind")) || ((data289.resource === undefined) && (missing111 = "resource"))) || ((data289.revision === undefined) && (missing111 = "revision"))) || ((data289.contract === undefined) && (missing111 = "contract"))) || ((data289.schema === undefined) && (missing111 = "schema"))){
const err871 = {instancePath:instancePath+"/page/evidence/manifest/basis",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/required",keyword:"required",params:{missingProperty: missing111},message:"must have required property '"+missing111+"'"};
if(vErrors === null){
vErrors = [err871];
}
else {
vErrors.push(err871);
}
errors++;
}
else {
const _errs848 = errors;
for(const key111 in data289){
if(!(((((key111 === "kind") || (key111 === "resource")) || (key111 === "revision")) || (key111 === "contract")) || (key111 === "schema"))){
const err872 = {instancePath:instancePath+"/page/evidence/manifest/basis",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key111},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err872];
}
else {
vErrors.push(err872);
}
errors++;
break;
}
}
if(_errs848 === errors){
if(data289.kind !== undefined){
let data290 = data289.kind;
const _errs849 = errors;
if(typeof data290 !== "string"){
const err873 = {instancePath:instancePath+"/page/evidence/manifest/basis/kind",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err873];
}
else {
vErrors.push(err873);
}
errors++;
}
if(!(((data290 === "kv") || (data290 === "table")) || (data290 === "document"))){
const err874 = {instancePath:instancePath+"/page/evidence/manifest/basis/kind",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/kind/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[9].properties.page.properties.evidence.properties.manifest.properties.basis.properties.kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err874];
}
else {
vErrors.push(err874);
}
errors++;
}
var valid161 = _errs849 === errors;
}
else {
var valid161 = true;
}
if(valid161){
if(data289.resource !== undefined){
let data291 = data289.resource;
const _errs851 = errors;
if(!(((typeof data291 == "number") && (!(data291 % 1) && !isNaN(data291))) && (isFinite(data291)))){
const err875 = {instancePath:instancePath+"/page/evidence/manifest/basis/resource",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/resource/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err875];
}
else {
vErrors.push(err875);
}
errors++;
}
if(errors === _errs851){
if((typeof data291 == "number") && (isFinite(data291))){
if(data291 > 9007199254740991 || isNaN(data291)){
const err876 = {instancePath:instancePath+"/page/evidence/manifest/basis/resource",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/resource/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err876];
}
else {
vErrors.push(err876);
}
errors++;
}
else {
if(data291 < 0 || isNaN(data291)){
const err877 = {instancePath:instancePath+"/page/evidence/manifest/basis/resource",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/resource/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err877];
}
else {
vErrors.push(err877);
}
errors++;
}
}
}
}
var valid161 = _errs851 === errors;
}
else {
var valid161 = true;
}
if(valid161){
if(data289.revision !== undefined){
let data292 = data289.revision;
const _errs853 = errors;
if(!(((typeof data292 == "number") && (!(data292 % 1) && !isNaN(data292))) && (isFinite(data292)))){
const err878 = {instancePath:instancePath+"/page/evidence/manifest/basis/revision",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/revision/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err878];
}
else {
vErrors.push(err878);
}
errors++;
}
if(errors === _errs853){
if((typeof data292 == "number") && (isFinite(data292))){
if(data292 > 9007199254740991 || isNaN(data292)){
const err879 = {instancePath:instancePath+"/page/evidence/manifest/basis/revision",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/revision/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err879];
}
else {
vErrors.push(err879);
}
errors++;
}
else {
if(data292 < 0 || isNaN(data292)){
const err880 = {instancePath:instancePath+"/page/evidence/manifest/basis/revision",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/revision/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid161 = _errs853 === errors;
}
else {
var valid161 = true;
}
if(valid161){
if(data289.contract !== undefined){
let data293 = data289.contract;
const _errs855 = errors;
if(errors === _errs855){
if(Array.isArray(data293)){
if(data293.length > 32){
const err881 = {instancePath:instancePath+"/page/evidence/manifest/basis/contract",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/contract/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err881];
}
else {
vErrors.push(err881);
}
errors++;
}
else {
if(data293.length < 32){
const err882 = {instancePath:instancePath+"/page/evidence/manifest/basis/contract",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/contract/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err882];
}
else {
vErrors.push(err882);
}
errors++;
}
else {
var valid162 = true;
const len26 = data293.length;
for(let i26=0; i26<len26; i26++){
let data294 = data293[i26];
const _errs857 = errors;
if(!(((typeof data294 == "number") && (!(data294 % 1) && !isNaN(data294))) && (isFinite(data294)))){
const err883 = {instancePath:instancePath+"/page/evidence/manifest/basis/contract/" + i26,schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/contract/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err883];
}
else {
vErrors.push(err883);
}
errors++;
}
if(errors === _errs857){
if((typeof data294 == "number") && (isFinite(data294))){
if(data294 > 255 || isNaN(data294)){
const err884 = {instancePath:instancePath+"/page/evidence/manifest/basis/contract/" + i26,schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/contract/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err884];
}
else {
vErrors.push(err884);
}
errors++;
}
else {
if(data294 < 0 || isNaN(data294)){
const err885 = {instancePath:instancePath+"/page/evidence/manifest/basis/contract/" + i26,schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/contract/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid162 = _errs857 === errors;
if(!valid162){
break;
}
}
}
}
}
else {
const err886 = {instancePath:instancePath+"/page/evidence/manifest/basis/contract",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/contract/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err886];
}
else {
vErrors.push(err886);
}
errors++;
}
}
var valid161 = _errs855 === errors;
}
else {
var valid161 = true;
}
if(valid161){
if(data289.schema !== undefined){
let data295 = data289.schema;
const _errs859 = errors;
if(errors === _errs859){
if(Array.isArray(data295)){
if(data295.length > 32){
const err887 = {instancePath:instancePath+"/page/evidence/manifest/basis/schema",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/schema/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err887];
}
else {
vErrors.push(err887);
}
errors++;
}
else {
if(data295.length < 32){
const err888 = {instancePath:instancePath+"/page/evidence/manifest/basis/schema",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/schema/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err888];
}
else {
vErrors.push(err888);
}
errors++;
}
else {
var valid163 = true;
const len27 = data295.length;
for(let i27=0; i27<len27; i27++){
let data296 = data295[i27];
const _errs861 = errors;
if(!(((typeof data296 == "number") && (!(data296 % 1) && !isNaN(data296))) && (isFinite(data296)))){
const err889 = {instancePath:instancePath+"/page/evidence/manifest/basis/schema/" + i27,schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/schema/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err889];
}
else {
vErrors.push(err889);
}
errors++;
}
if(errors === _errs861){
if((typeof data296 == "number") && (isFinite(data296))){
if(data296 > 255 || isNaN(data296)){
const err890 = {instancePath:instancePath+"/page/evidence/manifest/basis/schema/" + i27,schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/schema/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err890];
}
else {
vErrors.push(err890);
}
errors++;
}
else {
if(data296 < 0 || isNaN(data296)){
const err891 = {instancePath:instancePath+"/page/evidence/manifest/basis/schema/" + i27,schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/schema/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
}
var valid163 = _errs861 === errors;
if(!valid163){
break;
}
}
}
}
}
else {
const err892 = {instancePath:instancePath+"/page/evidence/manifest/basis/schema",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/properties/schema/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err892];
}
else {
vErrors.push(err892);
}
errors++;
}
}
var valid161 = _errs859 === errors;
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
else {
const err893 = {instancePath:instancePath+"/page/evidence/manifest/basis",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/basis/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err893];
}
else {
vErrors.push(err893);
}
errors++;
}
}
var valid159 = _errs846 === errors;
}
else {
var valid159 = true;
}
if(valid159){
if(data279.plan !== undefined){
let data297 = data279.plan;
const _errs863 = errors;
if(errors === _errs863){
if(Array.isArray(data297)){
if(data297.length > 32){
const err894 = {instancePath:instancePath+"/page/evidence/manifest/plan",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/plan/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err894];
}
else {
vErrors.push(err894);
}
errors++;
}
else {
if(data297.length < 32){
const err895 = {instancePath:instancePath+"/page/evidence/manifest/plan",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/plan/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err895];
}
else {
vErrors.push(err895);
}
errors++;
}
else {
var valid164 = true;
const len28 = data297.length;
for(let i28=0; i28<len28; i28++){
let data298 = data297[i28];
const _errs865 = errors;
if(!(((typeof data298 == "number") && (!(data298 % 1) && !isNaN(data298))) && (isFinite(data298)))){
const err896 = {instancePath:instancePath+"/page/evidence/manifest/plan/" + i28,schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/plan/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err896];
}
else {
vErrors.push(err896);
}
errors++;
}
if(errors === _errs865){
if((typeof data298 == "number") && (isFinite(data298))){
if(data298 > 255 || isNaN(data298)){
const err897 = {instancePath:instancePath+"/page/evidence/manifest/plan/" + i28,schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/plan/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err897];
}
else {
vErrors.push(err897);
}
errors++;
}
else {
if(data298 < 0 || isNaN(data298)){
const err898 = {instancePath:instancePath+"/page/evidence/manifest/plan/" + i28,schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/plan/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err898];
}
else {
vErrors.push(err898);
}
errors++;
}
}
}
}
var valid164 = _errs865 === errors;
if(!valid164){
break;
}
}
}
}
}
else {
const err899 = {instancePath:instancePath+"/page/evidence/manifest/plan",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/plan/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err899];
}
else {
vErrors.push(err899);
}
errors++;
}
}
var valid159 = _errs863 === errors;
}
else {
var valid159 = true;
}
if(valid159){
if(data279.pages !== undefined){
let data299 = data279.pages;
const _errs867 = errors;
if(errors === _errs867){
if(typeof data299 === "string"){
if(func1(data299) > 131072){
const err900 = {instancePath:instancePath+"/page/evidence/manifest/pages",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/pages/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err900];
}
else {
vErrors.push(err900);
}
errors++;
}
}
else {
const err901 = {instancePath:instancePath+"/page/evidence/manifest/pages",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/pages/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err901];
}
else {
vErrors.push(err901);
}
errors++;
}
}
var valid159 = _errs867 === errors;
}
else {
var valid159 = true;
}
if(valid159){
if(data279.scanned !== undefined){
let data300 = data279.scanned;
const _errs869 = errors;
if(errors === _errs869){
if(typeof data300 === "string"){
if(func1(data300) > 131072){
const err902 = {instancePath:instancePath+"/page/evidence/manifest/scanned",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/scanned/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err902];
}
else {
vErrors.push(err902);
}
errors++;
}
}
else {
const err903 = {instancePath:instancePath+"/page/evidence/manifest/scanned",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/scanned/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err903];
}
else {
vErrors.push(err903);
}
errors++;
}
}
var valid159 = _errs869 === errors;
}
else {
var valid159 = true;
}
if(valid159){
if(data279.selected !== undefined){
let data301 = data279.selected;
const _errs871 = errors;
if(errors === _errs871){
if(typeof data301 === "string"){
if(func1(data301) > 131072){
const err904 = {instancePath:instancePath+"/page/evidence/manifest/selected",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/selected/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err904];
}
else {
vErrors.push(err904);
}
errors++;
}
}
else {
const err905 = {instancePath:instancePath+"/page/evidence/manifest/selected",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/selected/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err905];
}
else {
vErrors.push(err905);
}
errors++;
}
}
var valid159 = _errs871 === errors;
}
else {
var valid159 = true;
}
if(valid159){
if(data279.value_count !== undefined){
let data302 = data279.value_count;
const _errs873 = errors;
if(errors === _errs873){
if(typeof data302 === "string"){
if(func1(data302) > 131072){
const err906 = {instancePath:instancePath+"/page/evidence/manifest/value_count",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/value_count/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err906];
}
else {
vErrors.push(err906);
}
errors++;
}
}
else {
const err907 = {instancePath:instancePath+"/page/evidence/manifest/value_count",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/value_count/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err907];
}
else {
vErrors.push(err907);
}
errors++;
}
}
var valid159 = _errs873 === errors;
}
else {
var valid159 = true;
}
if(valid159){
if(data279.segments !== undefined){
let data303 = data279.segments;
const _errs875 = errors;
if(errors === _errs875){
if(typeof data303 === "string"){
if(func1(data303) > 131072){
const err908 = {instancePath:instancePath+"/page/evidence/manifest/segments",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/segments/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err908];
}
else {
vErrors.push(err908);
}
errors++;
}
}
else {
const err909 = {instancePath:instancePath+"/page/evidence/manifest/segments",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/segments/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err909];
}
else {
vErrors.push(err909);
}
errors++;
}
}
var valid159 = _errs875 === errors;
}
else {
var valid159 = true;
}
if(valid159){
if(data279.rows !== undefined){
let data304 = data279.rows;
const _errs877 = errors;
if(errors === _errs877){
if(typeof data304 === "string"){
if(func1(data304) > 131072){
const err910 = {instancePath:instancePath+"/page/evidence/manifest/rows",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/rows/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err910];
}
else {
vErrors.push(err910);
}
errors++;
}
}
else {
const err911 = {instancePath:instancePath+"/page/evidence/manifest/rows",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/rows/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err911];
}
else {
vErrors.push(err911);
}
errors++;
}
}
var valid159 = _errs877 === errors;
}
else {
var valid159 = true;
}
if(valid159){
if(data279.bytes !== undefined){
let data305 = data279.bytes;
const _errs879 = errors;
if(errors === _errs879){
if(typeof data305 === "string"){
if(func1(data305) > 131072){
const err912 = {instancePath:instancePath+"/page/evidence/manifest/bytes",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/bytes/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err912];
}
else {
vErrors.push(err912);
}
errors++;
}
}
else {
const err913 = {instancePath:instancePath+"/page/evidence/manifest/bytes",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/bytes/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err913];
}
else {
vErrors.push(err913);
}
errors++;
}
}
var valid159 = _errs879 === errors;
}
else {
var valid159 = true;
}
if(valid159){
if(data279.sum !== undefined){
let data306 = data279.sum;
const _errs881 = errors;
const _errs882 = errors;
let valid165 = false;
const _errs883 = errors;
if(errors === _errs883){
if(typeof data306 === "string"){
if(func1(data306) > 131072){
const err914 = {instancePath:instancePath+"/page/evidence/manifest/sum",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/sum/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err914];
}
else {
vErrors.push(err914);
}
errors++;
}
}
else {
const err915 = {instancePath:instancePath+"/page/evidence/manifest/sum",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/sum/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err915];
}
else {
vErrors.push(err915);
}
errors++;
}
}
var _valid24 = _errs883 === errors;
valid165 = valid165 || _valid24;
const _errs885 = errors;
if(data306 !== null){
const err916 = {instancePath:instancePath+"/page/evidence/manifest/sum",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/sum/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err916];
}
else {
vErrors.push(err916);
}
errors++;
}
var _valid24 = _errs885 === errors;
valid165 = valid165 || _valid24;
if(!valid165){
const err917 = {instancePath:instancePath+"/page/evidence/manifest/sum",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/sum/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err917];
}
else {
vErrors.push(err917);
}
errors++;
}
else {
errors = _errs882;
if(vErrors !== null){
if(_errs882){
vErrors.length = _errs882;
}
else {
vErrors = null;
}
}
}
var valid159 = _errs881 === errors;
}
else {
var valid159 = true;
}
if(valid159){
if(data279.finished !== undefined){
let data307 = data279.finished;
const _errs887 = errors;
const _errs888 = errors;
let valid166 = false;
const _errs889 = errors;
if(typeof data307 !== "string"){
const err918 = {instancePath:instancePath+"/page/evidence/manifest/finished",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/finished/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err918];
}
else {
vErrors.push(err918);
}
errors++;
}
if(!((data307 === "source_end") || (data307 === "limit"))){
const err919 = {instancePath:instancePath+"/page/evidence/manifest/finished",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/finished/anyOf/0/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[9].properties.page.properties.evidence.properties.manifest.properties.finished.anyOf[0].enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err919];
}
else {
vErrors.push(err919);
}
errors++;
}
var _valid25 = _errs889 === errors;
valid166 = valid166 || _valid25;
const _errs891 = errors;
if(data307 !== null){
const err920 = {instancePath:instancePath+"/page/evidence/manifest/finished",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/finished/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err920];
}
else {
vErrors.push(err920);
}
errors++;
}
var _valid25 = _errs891 === errors;
valid166 = valid166 || _valid25;
if(!valid166){
const err921 = {instancePath:instancePath+"/page/evidence/manifest/finished",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/finished/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err921];
}
else {
vErrors.push(err921);
}
errors++;
}
else {
errors = _errs888;
if(vErrors !== null){
if(_errs888){
vErrors.length = _errs888;
}
else {
vErrors = null;
}
}
}
var valid159 = _errs887 === errors;
}
else {
var valid159 = true;
}
if(valid159){
if(data279.chain !== undefined){
let data308 = data279.chain;
const _errs893 = errors;
if(errors === _errs893){
if(Array.isArray(data308)){
if(data308.length > 32){
const err922 = {instancePath:instancePath+"/page/evidence/manifest/chain",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/chain/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err922];
}
else {
vErrors.push(err922);
}
errors++;
}
else {
if(data308.length < 32){
const err923 = {instancePath:instancePath+"/page/evidence/manifest/chain",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/chain/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err923];
}
else {
vErrors.push(err923);
}
errors++;
}
else {
var valid167 = true;
const len29 = data308.length;
for(let i29=0; i29<len29; i29++){
let data309 = data308[i29];
const _errs895 = errors;
if(!(((typeof data309 == "number") && (!(data309 % 1) && !isNaN(data309))) && (isFinite(data309)))){
const err924 = {instancePath:instancePath+"/page/evidence/manifest/chain/" + i29,schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/chain/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err924];
}
else {
vErrors.push(err924);
}
errors++;
}
if(errors === _errs895){
if((typeof data309 == "number") && (isFinite(data309))){
if(data309 > 255 || isNaN(data309)){
const err925 = {instancePath:instancePath+"/page/evidence/manifest/chain/" + i29,schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/chain/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err925];
}
else {
vErrors.push(err925);
}
errors++;
}
else {
if(data309 < 0 || isNaN(data309)){
const err926 = {instancePath:instancePath+"/page/evidence/manifest/chain/" + i29,schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/chain/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
}
var valid167 = _errs895 === errors;
if(!valid167){
break;
}
}
}
}
}
else {
const err927 = {instancePath:instancePath+"/page/evidence/manifest/chain",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/properties/chain/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err927];
}
else {
vErrors.push(err927);
}
errors++;
}
}
var valid159 = _errs893 === errors;
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
}
}
}
}
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
const err928 = {instancePath:instancePath+"/page/evidence/manifest",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/manifest/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err928];
}
else {
vErrors.push(err928);
}
errors++;
}
}
var valid158 = _errs824 === errors;
}
else {
var valid158 = true;
}
if(valid158){
if(data278.columns !== undefined){
let data310 = data278.columns;
const _errs897 = errors;
if(errors === _errs897){
if(Array.isArray(data310)){
if(data310.length > 8){
const err929 = {instancePath:instancePath+"/page/evidence/columns",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/columns/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err929];
}
else {
vErrors.push(err929);
}
errors++;
}
else {
var valid168 = true;
const len30 = data310.length;
for(let i30=0; i30<len30; i30++){
let data311 = data310[i30];
const _errs899 = errors;
if(errors === _errs899){
if(data311 && typeof data311 == "object" && !Array.isArray(data311)){
let missing112;
if(((data311.name === undefined) && (missing112 = "name")) || ((data311.type === undefined) && (missing112 = "type"))){
const err930 = {instancePath:instancePath+"/page/evidence/columns/" + i30,schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/columns/items/required",keyword:"required",params:{missingProperty: missing112},message:"must have required property '"+missing112+"'"};
if(vErrors === null){
vErrors = [err930];
}
else {
vErrors.push(err930);
}
errors++;
}
else {
const _errs901 = errors;
for(const key112 in data311){
if(!((key112 === "name") || (key112 === "type"))){
const err931 = {instancePath:instancePath+"/page/evidence/columns/" + i30,schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/columns/items/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key112},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err931];
}
else {
vErrors.push(err931);
}
errors++;
break;
}
}
if(_errs901 === errors){
if(data311.name !== undefined){
let data312 = data311.name;
const _errs902 = errors;
if(errors === _errs902){
if(typeof data312 === "string"){
if(func1(data312) > 131072){
const err932 = {instancePath:instancePath+"/page/evidence/columns/" + i30+"/name",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/columns/items/properties/name/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err932];
}
else {
vErrors.push(err932);
}
errors++;
}
}
else {
const err933 = {instancePath:instancePath+"/page/evidence/columns/" + i30+"/name",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/columns/items/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err933];
}
else {
vErrors.push(err933);
}
errors++;
}
}
var valid169 = _errs902 === errors;
}
else {
var valid169 = true;
}
if(valid169){
if(data311.type !== undefined){
let data313 = data311.type;
const _errs904 = errors;
if(typeof data313 !== "string"){
const err934 = {instancePath:instancePath+"/page/evidence/columns/" + i30+"/type",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/columns/items/properties/type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err934];
}
else {
vErrors.push(err934);
}
errors++;
}
if(!((((((data313 === "int64") || (data313 === "uint64")) || (data313 === "float64")) || (data313 === "boolean")) || (data313 === "utf8")) || (data313 === "binary"))){
const err935 = {instancePath:instancePath+"/page/evidence/columns/" + i30+"/type",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/columns/items/properties/type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[9].properties.page.properties.evidence.properties.columns.items.properties.type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err935];
}
else {
vErrors.push(err935);
}
errors++;
}
var valid169 = _errs904 === errors;
}
else {
var valid169 = true;
}
}
}
}
}
else {
const err936 = {instancePath:instancePath+"/page/evidence/columns/" + i30,schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/columns/items/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err936];
}
else {
vErrors.push(err936);
}
errors++;
}
}
var valid168 = _errs899 === errors;
if(!valid168){
break;
}
}
}
}
else {
const err937 = {instancePath:instancePath+"/page/evidence/columns",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/columns/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err937];
}
else {
vErrors.push(err937);
}
errors++;
}
}
var valid158 = _errs897 === errors;
}
else {
var valid158 = true;
}
if(valid158){
if(data278.ordinal !== undefined){
let data314 = data278.ordinal;
const _errs906 = errors;
if(errors === _errs906){
if(typeof data314 === "string"){
if(func1(data314) > 131072){
const err938 = {instancePath:instancePath+"/page/evidence/ordinal",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/ordinal/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err939 = {instancePath:instancePath+"/page/evidence/ordinal",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/ordinal/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err939];
}
else {
vErrors.push(err939);
}
errors++;
}
}
var valid158 = _errs906 === errors;
}
else {
var valid158 = true;
}
if(valid158){
if(data278.rows !== undefined){
let data315 = data278.rows;
const _errs908 = errors;
if(!(((typeof data315 == "number") && (!(data315 % 1) && !isNaN(data315))) && (isFinite(data315)))){
const err940 = {instancePath:instancePath+"/page/evidence/rows",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/rows/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err940];
}
else {
vErrors.push(err940);
}
errors++;
}
if(errors === _errs908){
if((typeof data315 == "number") && (isFinite(data315))){
if(data315 > 255 || isNaN(data315)){
const err941 = {instancePath:instancePath+"/page/evidence/rows",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/rows/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err941];
}
else {
vErrors.push(err941);
}
errors++;
}
else {
if(data315 < 0 || isNaN(data315)){
const err942 = {instancePath:instancePath+"/page/evidence/rows",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/rows/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err942];
}
else {
vErrors.push(err942);
}
errors++;
}
}
}
}
var valid158 = _errs908 === errors;
}
else {
var valid158 = true;
}
if(valid158){
if(data278.ipc !== undefined){
let data316 = data278.ipc;
const _errs910 = errors;
if(errors === _errs910){
if(typeof data316 === "string"){
if(func1(data316) > 131072){
const err943 = {instancePath:instancePath+"/page/evidence/ipc",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/ipc/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err943];
}
else {
vErrors.push(err943);
}
errors++;
}
}
else {
const err944 = {instancePath:instancePath+"/page/evidence/ipc",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/ipc/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err944];
}
else {
vErrors.push(err944);
}
errors++;
}
}
var valid158 = _errs910 === errors;
}
else {
var valid158 = true;
}
if(valid158){
if(data278.next !== undefined){
let data317 = data278.next;
const _errs912 = errors;
const _errs913 = errors;
let valid170 = false;
const _errs914 = errors;
if(errors === _errs914){
if(typeof data317 === "string"){
if(func1(data317) > 131072){
const err945 = {instancePath:instancePath+"/page/evidence/next",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/next/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err945];
}
else {
vErrors.push(err945);
}
errors++;
}
}
else {
const err946 = {instancePath:instancePath+"/page/evidence/next",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/next/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err946];
}
else {
vErrors.push(err946);
}
errors++;
}
}
var _valid26 = _errs914 === errors;
valid170 = valid170 || _valid26;
const _errs916 = errors;
if(data317 !== null){
const err947 = {instancePath:instancePath+"/page/evidence/next",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/next/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err947];
}
else {
vErrors.push(err947);
}
errors++;
}
var _valid26 = _errs916 === errors;
valid170 = valid170 || _valid26;
if(!valid170){
const err948 = {instancePath:instancePath+"/page/evidence/next",schemaPath:"#/oneOf/9/properties/page/properties/evidence/properties/next/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err948];
}
else {
vErrors.push(err948);
}
errors++;
}
else {
errors = _errs913;
if(vErrors !== null){
if(_errs913){
vErrors.length = _errs913;
}
else {
vErrors = null;
}
}
}
var valid158 = _errs912 === errors;
}
else {
var valid158 = true;
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
const err949 = {instancePath:instancePath+"/page/evidence",schemaPath:"#/oneOf/9/properties/page/properties/evidence/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err949];
}
else {
vErrors.push(err949);
}
errors++;
}
}
var valid157 = _errs821 === errors;
}
else {
var valid157 = true;
}
if(valid157){
if(data277.cells !== undefined){
let data318 = data277.cells;
const _errs918 = errors;
if(errors === _errs918){
if(Array.isArray(data318)){
if(data318.length > 8){
const err950 = {instancePath:instancePath+"/page/cells",schemaPath:"#/oneOf/9/properties/page/properties/cells/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err950];
}
else {
vErrors.push(err950);
}
errors++;
}
else {
var valid171 = true;
const len31 = data318.length;
for(let i31=0; i31<len31; i31++){
let data319 = data318[i31];
const _errs920 = errors;
if(errors === _errs920){
if(Array.isArray(data319)){
if(data319.length > 8){
const err951 = {instancePath:instancePath+"/page/cells/" + i31,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err951];
}
else {
vErrors.push(err951);
}
errors++;
}
else {
var valid172 = true;
const len32 = data319.length;
for(let i32=0; i32<len32; i32++){
let data320 = data319[i32];
const _errs922 = errors;
const _errs923 = errors;
let valid173 = false;
let passing13 = null;
const _errs924 = errors;
if(errors === _errs924){
if(data320 && typeof data320 == "object" && !Array.isArray(data320)){
let missing113;
if((data320.missing === undefined) && (missing113 = "missing")){
const err952 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/0/required",keyword:"required",params:{missingProperty: missing113},message:"must have required property '"+missing113+"'"};
if(vErrors === null){
vErrors = [err952];
}
else {
vErrors.push(err952);
}
errors++;
}
else {
const _errs926 = errors;
for(const key113 in data320){
if(!(key113 === "missing")){
const err953 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key113},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err953];
}
else {
vErrors.push(err953);
}
errors++;
break;
}
}
if(_errs926 === errors){
if(data320.missing !== undefined){
let data321 = data320.missing;
const _errs927 = errors;
if(errors === _errs927){
if(data321 && typeof data321 == "object" && !Array.isArray(data321)){
if(Object.keys(data321).length > 0){
const err954 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/missing",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/0/properties/missing/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err954];
}
else {
vErrors.push(err954);
}
errors++;
}
}
else {
const err955 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/missing",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/0/properties/missing/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err955];
}
else {
vErrors.push(err955);
}
errors++;
}
}
}
}
}
}
else {
const err956 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err956];
}
else {
vErrors.push(err956);
}
errors++;
}
}
var _valid27 = _errs924 === errors;
if(_valid27){
valid173 = true;
passing13 = 0;
var props16 = true;
}
const _errs929 = errors;
if(errors === _errs929){
if(data320 && typeof data320 == "object" && !Array.isArray(data320)){
let missing114;
if((data320.null === undefined) && (missing114 = "null")){
const err957 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/1/required",keyword:"required",params:{missingProperty: missing114},message:"must have required property '"+missing114+"'"};
if(vErrors === null){
vErrors = [err957];
}
else {
vErrors.push(err957);
}
errors++;
}
else {
const _errs931 = errors;
for(const key114 in data320){
if(!(key114 === "null")){
const err958 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key114},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err958];
}
else {
vErrors.push(err958);
}
errors++;
break;
}
}
if(_errs931 === errors){
if(data320.null !== undefined){
let data322 = data320.null;
const _errs932 = errors;
if(errors === _errs932){
if(data322 && typeof data322 == "object" && !Array.isArray(data322)){
if(Object.keys(data322).length > 0){
const err959 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/null",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/1/properties/null/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err959];
}
else {
vErrors.push(err959);
}
errors++;
}
}
else {
const err960 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/null",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/1/properties/null/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err960];
}
else {
vErrors.push(err960);
}
errors++;
}
}
}
}
}
}
else {
const err961 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err961];
}
else {
vErrors.push(err961);
}
errors++;
}
}
var _valid27 = _errs929 === errors;
if(_valid27 && valid173){
valid173 = false;
passing13 = [passing13, 1];
}
else {
if(_valid27){
valid173 = true;
passing13 = 1;
if(props16 !== true){
props16 = true;
}
}
const _errs934 = errors;
if(errors === _errs934){
if(data320 && typeof data320 == "object" && !Array.isArray(data320)){
let missing115;
if((data320.type_error === undefined) && (missing115 = "type_error")){
const err962 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/2/required",keyword:"required",params:{missingProperty: missing115},message:"must have required property '"+missing115+"'"};
if(vErrors === null){
vErrors = [err962];
}
else {
vErrors.push(err962);
}
errors++;
}
else {
const _errs936 = errors;
for(const key115 in data320){
if(!(key115 === "type_error")){
const err963 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key115},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err963];
}
else {
vErrors.push(err963);
}
errors++;
break;
}
}
if(_errs936 === errors){
if(data320.type_error !== undefined){
let data323 = data320.type_error;
if(typeof data323 !== "string"){
const err964 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/type_error",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/2/properties/type_error/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err964];
}
else {
vErrors.push(err964);
}
errors++;
}
if(!((((((((((((data323 === "unknown") || (data323 === "int64")) || (data323 === "uint64")) || (data323 === "float64")) || (data323 === "boolean")) || (data323 === "utf8")) || (data323 === "binary")) || (data323 === "null_value")) || (data323 === "map")) || (data323 === "list")) || (data323 === "text")) || (data323 === "character"))){
const err965 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/type_error",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/2/properties/type_error/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[9].properties.page.properties.cells.items.items.oneOf[2].properties.type_error.enum},message:"must be equal to one of the allowed values"};
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
else {
const err966 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err966];
}
else {
vErrors.push(err966);
}
errors++;
}
}
var _valid27 = _errs934 === errors;
if(_valid27 && valid173){
valid173 = false;
passing13 = [passing13, 2];
}
else {
if(_valid27){
valid173 = true;
passing13 = 2;
if(props16 !== true){
props16 = true;
}
}
const _errs939 = errors;
if(errors === _errs939){
if(data320 && typeof data320 == "object" && !Array.isArray(data320)){
let missing116;
if((data320.value === undefined) && (missing116 = "value")){
const err967 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/required",keyword:"required",params:{missingProperty: missing116},message:"must have required property '"+missing116+"'"};
if(vErrors === null){
vErrors = [err967];
}
else {
vErrors.push(err967);
}
errors++;
}
else {
const _errs941 = errors;
for(const key116 in data320){
if(!(key116 === "value")){
const err968 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key116},message:"must NOT have additional properties"};
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
if(_errs941 === errors){
if(data320.value !== undefined){
let data324 = data320.value;
const _errs943 = errors;
let valid178 = false;
let passing14 = null;
const _errs944 = errors;
if(errors === _errs944){
if(data324 && typeof data324 == "object" && !Array.isArray(data324)){
let missing117;
if((data324.int64 === undefined) && (missing117 = "int64")){
const err969 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/0/required",keyword:"required",params:{missingProperty: missing117},message:"must have required property '"+missing117+"'"};
if(vErrors === null){
vErrors = [err969];
}
else {
vErrors.push(err969);
}
errors++;
}
else {
const _errs946 = errors;
for(const key117 in data324){
if(!(key117 === "int64")){
const err970 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key117},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err970];
}
else {
vErrors.push(err970);
}
errors++;
break;
}
}
if(_errs946 === errors){
if(data324.int64 !== undefined){
let data325 = data324.int64;
const _errs947 = errors;
if(errors === _errs947){
if(typeof data325 === "string"){
if(func1(data325) > 131072){
const err971 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/value/int64",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/0/properties/int64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err971];
}
else {
vErrors.push(err971);
}
errors++;
}
}
else {
const err972 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/value/int64",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/0/properties/int64/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err972];
}
else {
vErrors.push(err972);
}
errors++;
}
}
}
}
}
}
else {
const err973 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err973];
}
else {
vErrors.push(err973);
}
errors++;
}
}
var _valid28 = _errs944 === errors;
if(_valid28){
valid178 = true;
passing14 = 0;
var props17 = true;
}
const _errs949 = errors;
if(errors === _errs949){
if(data324 && typeof data324 == "object" && !Array.isArray(data324)){
let missing118;
if((data324.uint64 === undefined) && (missing118 = "uint64")){
const err974 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/1/required",keyword:"required",params:{missingProperty: missing118},message:"must have required property '"+missing118+"'"};
if(vErrors === null){
vErrors = [err974];
}
else {
vErrors.push(err974);
}
errors++;
}
else {
const _errs951 = errors;
for(const key118 in data324){
if(!(key118 === "uint64")){
const err975 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key118},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err975];
}
else {
vErrors.push(err975);
}
errors++;
break;
}
}
if(_errs951 === errors){
if(data324.uint64 !== undefined){
let data326 = data324.uint64;
const _errs952 = errors;
if(errors === _errs952){
if(typeof data326 === "string"){
if(func1(data326) > 131072){
const err976 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/value/uint64",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/1/properties/uint64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err976];
}
else {
vErrors.push(err976);
}
errors++;
}
}
else {
const err977 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/value/uint64",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/1/properties/uint64/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
}
}
else {
const err978 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err978];
}
else {
vErrors.push(err978);
}
errors++;
}
}
var _valid28 = _errs949 === errors;
if(_valid28 && valid178){
valid178 = false;
passing14 = [passing14, 1];
}
else {
if(_valid28){
valid178 = true;
passing14 = 1;
if(props17 !== true){
props17 = true;
}
}
const _errs954 = errors;
if(errors === _errs954){
if(data324 && typeof data324 == "object" && !Array.isArray(data324)){
let missing119;
if((data324.float_bits === undefined) && (missing119 = "float_bits")){
const err979 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/2/required",keyword:"required",params:{missingProperty: missing119},message:"must have required property '"+missing119+"'"};
if(vErrors === null){
vErrors = [err979];
}
else {
vErrors.push(err979);
}
errors++;
}
else {
const _errs956 = errors;
for(const key119 in data324){
if(!(key119 === "float_bits")){
const err980 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key119},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err980];
}
else {
vErrors.push(err980);
}
errors++;
break;
}
}
if(_errs956 === errors){
if(data324.float_bits !== undefined){
let data327 = data324.float_bits;
const _errs957 = errors;
if(errors === _errs957){
if(typeof data327 === "string"){
if(func1(data327) > 131072){
const err981 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/value/float_bits",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/2/properties/float_bits/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err981];
}
else {
vErrors.push(err981);
}
errors++;
}
}
else {
const err982 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/value/float_bits",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/2/properties/float_bits/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err982];
}
else {
vErrors.push(err982);
}
errors++;
}
}
}
}
}
}
else {
const err983 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err983];
}
else {
vErrors.push(err983);
}
errors++;
}
}
var _valid28 = _errs954 === errors;
if(_valid28 && valid178){
valid178 = false;
passing14 = [passing14, 2];
}
else {
if(_valid28){
valid178 = true;
passing14 = 2;
if(props17 !== true){
props17 = true;
}
}
const _errs959 = errors;
if(errors === _errs959){
if(data324 && typeof data324 == "object" && !Array.isArray(data324)){
let missing120;
if((data324.boolean === undefined) && (missing120 = "boolean")){
const err984 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/3/required",keyword:"required",params:{missingProperty: missing120},message:"must have required property '"+missing120+"'"};
if(vErrors === null){
vErrors = [err984];
}
else {
vErrors.push(err984);
}
errors++;
}
else {
const _errs961 = errors;
for(const key120 in data324){
if(!(key120 === "boolean")){
const err985 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key120},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err985];
}
else {
vErrors.push(err985);
}
errors++;
break;
}
}
if(_errs961 === errors){
if(data324.boolean !== undefined){
if(typeof data324.boolean !== "boolean"){
const err986 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/value/boolean",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/3/properties/boolean/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err986];
}
else {
vErrors.push(err986);
}
errors++;
}
}
}
}
}
else {
const err987 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err987];
}
else {
vErrors.push(err987);
}
errors++;
}
}
var _valid28 = _errs959 === errors;
if(_valid28 && valid178){
valid178 = false;
passing14 = [passing14, 3];
}
else {
if(_valid28){
valid178 = true;
passing14 = 3;
if(props17 !== true){
props17 = true;
}
}
const _errs964 = errors;
if(errors === _errs964){
if(data324 && typeof data324 == "object" && !Array.isArray(data324)){
let missing121;
if((data324.utf8 === undefined) && (missing121 = "utf8")){
const err988 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/4/required",keyword:"required",params:{missingProperty: missing121},message:"must have required property '"+missing121+"'"};
if(vErrors === null){
vErrors = [err988];
}
else {
vErrors.push(err988);
}
errors++;
}
else {
const _errs966 = errors;
for(const key121 in data324){
if(!(key121 === "utf8")){
const err989 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key121},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err989];
}
else {
vErrors.push(err989);
}
errors++;
break;
}
}
if(_errs966 === errors){
if(data324.utf8 !== undefined){
let data329 = data324.utf8;
const _errs967 = errors;
if(errors === _errs967){
if(typeof data329 === "string"){
if(func1(data329) > 131072){
const err990 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/value/utf8",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/4/properties/utf8/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err990];
}
else {
vErrors.push(err990);
}
errors++;
}
}
else {
const err991 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/value/utf8",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/4/properties/utf8/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err991];
}
else {
vErrors.push(err991);
}
errors++;
}
}
}
}
}
}
else {
const err992 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err992];
}
else {
vErrors.push(err992);
}
errors++;
}
}
var _valid28 = _errs964 === errors;
if(_valid28 && valid178){
valid178 = false;
passing14 = [passing14, 4];
}
else {
if(_valid28){
valid178 = true;
passing14 = 4;
if(props17 !== true){
props17 = true;
}
}
const _errs969 = errors;
if(errors === _errs969){
if(data324 && typeof data324 == "object" && !Array.isArray(data324)){
let missing122;
if((data324.binary === undefined) && (missing122 = "binary")){
const err993 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/5/required",keyword:"required",params:{missingProperty: missing122},message:"must have required property '"+missing122+"'"};
if(vErrors === null){
vErrors = [err993];
}
else {
vErrors.push(err993);
}
errors++;
}
else {
const _errs971 = errors;
for(const key122 in data324){
if(!(key122 === "binary")){
const err994 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key122},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err994];
}
else {
vErrors.push(err994);
}
errors++;
break;
}
}
if(_errs971 === errors){
if(data324.binary !== undefined){
let data330 = data324.binary;
const _errs972 = errors;
if(errors === _errs972){
if(typeof data330 === "string"){
if(func1(data330) > 131072){
const err995 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/value/binary",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/5/properties/binary/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err995];
}
else {
vErrors.push(err995);
}
errors++;
}
}
else {
const err996 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/value/binary",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/5/properties/binary/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err996];
}
else {
vErrors.push(err996);
}
errors++;
}
}
}
}
}
}
else {
const err997 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err997];
}
else {
vErrors.push(err997);
}
errors++;
}
}
var _valid28 = _errs969 === errors;
if(_valid28 && valid178){
valid178 = false;
passing14 = [passing14, 5];
}
else {
if(_valid28){
valid178 = true;
passing14 = 5;
if(props17 !== true){
props17 = true;
}
}
}
}
}
}
}
if(!valid178){
const err998 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf",keyword:"oneOf",params:{passingSchemas: passing14},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err998];
}
else {
vErrors.push(err998);
}
errors++;
}
else {
errors = _errs943;
if(vErrors !== null){
if(_errs943){
vErrors.length = _errs943;
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
const err999 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err999];
}
else {
vErrors.push(err999);
}
errors++;
}
}
var _valid27 = _errs939 === errors;
if(_valid27 && valid173){
valid173 = false;
passing13 = [passing13, 3];
}
else {
if(_valid27){
valid173 = true;
passing13 = 3;
if(props16 !== true){
props16 = true;
}
}
const _errs974 = errors;
if(errors === _errs974){
if(data320 && typeof data320 == "object" && !Array.isArray(data320)){
let missing123;
if((data320.conflict === undefined) && (missing123 = "conflict")){
const err1000 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/required",keyword:"required",params:{missingProperty: missing123},message:"must have required property '"+missing123+"'"};
if(vErrors === null){
vErrors = [err1000];
}
else {
vErrors.push(err1000);
}
errors++;
}
else {
const _errs976 = errors;
for(const key123 in data320){
if(!(key123 === "conflict")){
const err1001 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key123},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1001];
}
else {
vErrors.push(err1001);
}
errors++;
break;
}
}
if(_errs976 === errors){
if(data320.conflict !== undefined){
let data331 = data320.conflict;
const _errs977 = errors;
if(errors === _errs977){
if(Array.isArray(data331)){
if(data331.length > 8){
const err1002 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err1002];
}
else {
vErrors.push(err1002);
}
errors++;
}
else {
var valid186 = true;
const len33 = data331.length;
for(let i33=0; i33<len33; i33++){
let data332 = data331[i33];
const _errs979 = errors;
if(errors === _errs979){
if(data332 && typeof data332 == "object" && !Array.isArray(data332)){
let missing124;
if((((data332.counter === undefined) && (missing124 = "counter")) || ((data332.replica === undefined) && (missing124 = "replica"))) || ((data332.value === undefined) && (missing124 = "value"))){
const err1003 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/required",keyword:"required",params:{missingProperty: missing124},message:"must have required property '"+missing124+"'"};
if(vErrors === null){
vErrors = [err1003];
}
else {
vErrors.push(err1003);
}
errors++;
}
else {
const _errs981 = errors;
for(const key124 in data332){
if(!(((key124 === "counter") || (key124 === "replica")) || (key124 === "value"))){
const err1004 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key124},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1004];
}
else {
vErrors.push(err1004);
}
errors++;
break;
}
}
if(_errs981 === errors){
if(data332.counter !== undefined){
let data333 = data332.counter;
const _errs982 = errors;
if(errors === _errs982){
if(typeof data333 === "string"){
if(func1(data333) > 131072){
const err1005 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/counter",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/counter/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1005];
}
else {
vErrors.push(err1005);
}
errors++;
}
}
else {
const err1006 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/counter",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/counter/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1006];
}
else {
vErrors.push(err1006);
}
errors++;
}
}
var valid187 = _errs982 === errors;
}
else {
var valid187 = true;
}
if(valid187){
if(data332.replica !== undefined){
let data334 = data332.replica;
const _errs984 = errors;
if(errors === _errs984){
if(typeof data334 === "string"){
if(func1(data334) > 131072){
const err1007 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/replica",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/replica/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1007];
}
else {
vErrors.push(err1007);
}
errors++;
}
}
else {
const err1008 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/replica",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/replica/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1008];
}
else {
vErrors.push(err1008);
}
errors++;
}
}
var valid187 = _errs984 === errors;
}
else {
var valid187 = true;
}
if(valid187){
if(data332.value !== undefined){
let data335 = data332.value;
const _errs986 = errors;
const _errs987 = errors;
let valid188 = false;
let passing15 = null;
const _errs988 = errors;
if(errors === _errs988){
if(data335 && typeof data335 == "object" && !Array.isArray(data335)){
let missing125;
if((data335.null === undefined) && (missing125 = "null")){
const err1009 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/0/required",keyword:"required",params:{missingProperty: missing125},message:"must have required property '"+missing125+"'"};
if(vErrors === null){
vErrors = [err1009];
}
else {
vErrors.push(err1009);
}
errors++;
}
else {
const _errs990 = errors;
for(const key125 in data335){
if(!(key125 === "null")){
const err1010 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key125},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1010];
}
else {
vErrors.push(err1010);
}
errors++;
break;
}
}
if(_errs990 === errors){
if(data335.null !== undefined){
let data336 = data335.null;
const _errs991 = errors;
if(errors === _errs991){
if(data336 && typeof data336 == "object" && !Array.isArray(data336)){
if(Object.keys(data336).length > 0){
const err1011 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/null",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/0/properties/null/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err1011];
}
else {
vErrors.push(err1011);
}
errors++;
}
}
else {
const err1012 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/null",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/0/properties/null/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1012];
}
else {
vErrors.push(err1012);
}
errors++;
}
}
}
}
}
}
else {
const err1013 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1013];
}
else {
vErrors.push(err1013);
}
errors++;
}
}
var _valid29 = _errs988 === errors;
if(_valid29){
valid188 = true;
passing15 = 0;
var props18 = true;
}
const _errs993 = errors;
if(errors === _errs993){
if(data335 && typeof data335 == "object" && !Array.isArray(data335)){
let missing126;
if((data335.type_error === undefined) && (missing126 = "type_error")){
const err1014 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/1/required",keyword:"required",params:{missingProperty: missing126},message:"must have required property '"+missing126+"'"};
if(vErrors === null){
vErrors = [err1014];
}
else {
vErrors.push(err1014);
}
errors++;
}
else {
const _errs995 = errors;
for(const key126 in data335){
if(!(key126 === "type_error")){
const err1015 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key126},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1015];
}
else {
vErrors.push(err1015);
}
errors++;
break;
}
}
if(_errs995 === errors){
if(data335.type_error !== undefined){
let data337 = data335.type_error;
if(typeof data337 !== "string"){
const err1016 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/type_error",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/1/properties/type_error/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1016];
}
else {
vErrors.push(err1016);
}
errors++;
}
if(!((((((((((((data337 === "unknown") || (data337 === "int64")) || (data337 === "uint64")) || (data337 === "float64")) || (data337 === "boolean")) || (data337 === "utf8")) || (data337 === "binary")) || (data337 === "null_value")) || (data337 === "map")) || (data337 === "list")) || (data337 === "text")) || (data337 === "character"))){
const err1017 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/type_error",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/1/properties/type_error/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[9].properties.page.properties.cells.items.items.oneOf[4].properties.conflict.items.properties.value.oneOf[1].properties.type_error.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err1017];
}
else {
vErrors.push(err1017);
}
errors++;
}
}
}
}
}
else {
const err1018 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1018];
}
else {
vErrors.push(err1018);
}
errors++;
}
}
var _valid29 = _errs993 === errors;
if(_valid29 && valid188){
valid188 = false;
passing15 = [passing15, 1];
}
else {
if(_valid29){
valid188 = true;
passing15 = 1;
if(props18 !== true){
props18 = true;
}
}
const _errs998 = errors;
if(errors === _errs998){
if(data335 && typeof data335 == "object" && !Array.isArray(data335)){
let missing127;
if((data335.value === undefined) && (missing127 = "value")){
const err1019 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/required",keyword:"required",params:{missingProperty: missing127},message:"must have required property '"+missing127+"'"};
if(vErrors === null){
vErrors = [err1019];
}
else {
vErrors.push(err1019);
}
errors++;
}
else {
const _errs1000 = errors;
for(const key127 in data335){
if(!(key127 === "value")){
const err1020 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key127},message:"must NOT have additional properties"};
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
if(_errs1000 === errors){
if(data335.value !== undefined){
let data338 = data335.value;
const _errs1002 = errors;
let valid192 = false;
let passing16 = null;
const _errs1003 = errors;
if(errors === _errs1003){
if(data338 && typeof data338 == "object" && !Array.isArray(data338)){
let missing128;
if((data338.int64 === undefined) && (missing128 = "int64")){
const err1021 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/0/required",keyword:"required",params:{missingProperty: missing128},message:"must have required property '"+missing128+"'"};
if(vErrors === null){
vErrors = [err1021];
}
else {
vErrors.push(err1021);
}
errors++;
}
else {
const _errs1005 = errors;
for(const key128 in data338){
if(!(key128 === "int64")){
const err1022 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key128},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1022];
}
else {
vErrors.push(err1022);
}
errors++;
break;
}
}
if(_errs1005 === errors){
if(data338.int64 !== undefined){
let data339 = data338.int64;
const _errs1006 = errors;
if(errors === _errs1006){
if(typeof data339 === "string"){
if(func1(data339) > 131072){
const err1023 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/value/int64",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/0/properties/int64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1023];
}
else {
vErrors.push(err1023);
}
errors++;
}
}
else {
const err1024 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/value/int64",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/0/properties/int64/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1024];
}
else {
vErrors.push(err1024);
}
errors++;
}
}
}
}
}
}
else {
const err1025 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1025];
}
else {
vErrors.push(err1025);
}
errors++;
}
}
var _valid30 = _errs1003 === errors;
if(_valid30){
valid192 = true;
passing16 = 0;
var props19 = true;
}
const _errs1008 = errors;
if(errors === _errs1008){
if(data338 && typeof data338 == "object" && !Array.isArray(data338)){
let missing129;
if((data338.uint64 === undefined) && (missing129 = "uint64")){
const err1026 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/1/required",keyword:"required",params:{missingProperty: missing129},message:"must have required property '"+missing129+"'"};
if(vErrors === null){
vErrors = [err1026];
}
else {
vErrors.push(err1026);
}
errors++;
}
else {
const _errs1010 = errors;
for(const key129 in data338){
if(!(key129 === "uint64")){
const err1027 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key129},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1027];
}
else {
vErrors.push(err1027);
}
errors++;
break;
}
}
if(_errs1010 === errors){
if(data338.uint64 !== undefined){
let data340 = data338.uint64;
const _errs1011 = errors;
if(errors === _errs1011){
if(typeof data340 === "string"){
if(func1(data340) > 131072){
const err1028 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/value/uint64",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/1/properties/uint64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1028];
}
else {
vErrors.push(err1028);
}
errors++;
}
}
else {
const err1029 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/value/uint64",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/1/properties/uint64/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1029];
}
else {
vErrors.push(err1029);
}
errors++;
}
}
}
}
}
}
else {
const err1030 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1030];
}
else {
vErrors.push(err1030);
}
errors++;
}
}
var _valid30 = _errs1008 === errors;
if(_valid30 && valid192){
valid192 = false;
passing16 = [passing16, 1];
}
else {
if(_valid30){
valid192 = true;
passing16 = 1;
if(props19 !== true){
props19 = true;
}
}
const _errs1013 = errors;
if(errors === _errs1013){
if(data338 && typeof data338 == "object" && !Array.isArray(data338)){
let missing130;
if((data338.float_bits === undefined) && (missing130 = "float_bits")){
const err1031 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/2/required",keyword:"required",params:{missingProperty: missing130},message:"must have required property '"+missing130+"'"};
if(vErrors === null){
vErrors = [err1031];
}
else {
vErrors.push(err1031);
}
errors++;
}
else {
const _errs1015 = errors;
for(const key130 in data338){
if(!(key130 === "float_bits")){
const err1032 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key130},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1032];
}
else {
vErrors.push(err1032);
}
errors++;
break;
}
}
if(_errs1015 === errors){
if(data338.float_bits !== undefined){
let data341 = data338.float_bits;
const _errs1016 = errors;
if(errors === _errs1016){
if(typeof data341 === "string"){
if(func1(data341) > 131072){
const err1033 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/value/float_bits",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/2/properties/float_bits/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1033];
}
else {
vErrors.push(err1033);
}
errors++;
}
}
else {
const err1034 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/value/float_bits",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/2/properties/float_bits/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1034];
}
else {
vErrors.push(err1034);
}
errors++;
}
}
}
}
}
}
else {
const err1035 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1035];
}
else {
vErrors.push(err1035);
}
errors++;
}
}
var _valid30 = _errs1013 === errors;
if(_valid30 && valid192){
valid192 = false;
passing16 = [passing16, 2];
}
else {
if(_valid30){
valid192 = true;
passing16 = 2;
if(props19 !== true){
props19 = true;
}
}
const _errs1018 = errors;
if(errors === _errs1018){
if(data338 && typeof data338 == "object" && !Array.isArray(data338)){
let missing131;
if((data338.boolean === undefined) && (missing131 = "boolean")){
const err1036 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/3/required",keyword:"required",params:{missingProperty: missing131},message:"must have required property '"+missing131+"'"};
if(vErrors === null){
vErrors = [err1036];
}
else {
vErrors.push(err1036);
}
errors++;
}
else {
const _errs1020 = errors;
for(const key131 in data338){
if(!(key131 === "boolean")){
const err1037 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key131},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1037];
}
else {
vErrors.push(err1037);
}
errors++;
break;
}
}
if(_errs1020 === errors){
if(data338.boolean !== undefined){
if(typeof data338.boolean !== "boolean"){
const err1038 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/value/boolean",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/3/properties/boolean/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err1038];
}
else {
vErrors.push(err1038);
}
errors++;
}
}
}
}
}
else {
const err1039 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1039];
}
else {
vErrors.push(err1039);
}
errors++;
}
}
var _valid30 = _errs1018 === errors;
if(_valid30 && valid192){
valid192 = false;
passing16 = [passing16, 3];
}
else {
if(_valid30){
valid192 = true;
passing16 = 3;
if(props19 !== true){
props19 = true;
}
}
const _errs1023 = errors;
if(errors === _errs1023){
if(data338 && typeof data338 == "object" && !Array.isArray(data338)){
let missing132;
if((data338.utf8 === undefined) && (missing132 = "utf8")){
const err1040 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/4/required",keyword:"required",params:{missingProperty: missing132},message:"must have required property '"+missing132+"'"};
if(vErrors === null){
vErrors = [err1040];
}
else {
vErrors.push(err1040);
}
errors++;
}
else {
const _errs1025 = errors;
for(const key132 in data338){
if(!(key132 === "utf8")){
const err1041 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key132},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1041];
}
else {
vErrors.push(err1041);
}
errors++;
break;
}
}
if(_errs1025 === errors){
if(data338.utf8 !== undefined){
let data343 = data338.utf8;
const _errs1026 = errors;
if(errors === _errs1026){
if(typeof data343 === "string"){
if(func1(data343) > 131072){
const err1042 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/value/utf8",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/4/properties/utf8/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1042];
}
else {
vErrors.push(err1042);
}
errors++;
}
}
else {
const err1043 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/value/utf8",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/4/properties/utf8/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1043];
}
else {
vErrors.push(err1043);
}
errors++;
}
}
}
}
}
}
else {
const err1044 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1044];
}
else {
vErrors.push(err1044);
}
errors++;
}
}
var _valid30 = _errs1023 === errors;
if(_valid30 && valid192){
valid192 = false;
passing16 = [passing16, 4];
}
else {
if(_valid30){
valid192 = true;
passing16 = 4;
if(props19 !== true){
props19 = true;
}
}
const _errs1028 = errors;
if(errors === _errs1028){
if(data338 && typeof data338 == "object" && !Array.isArray(data338)){
let missing133;
if((data338.binary === undefined) && (missing133 = "binary")){
const err1045 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/5/required",keyword:"required",params:{missingProperty: missing133},message:"must have required property '"+missing133+"'"};
if(vErrors === null){
vErrors = [err1045];
}
else {
vErrors.push(err1045);
}
errors++;
}
else {
const _errs1030 = errors;
for(const key133 in data338){
if(!(key133 === "binary")){
const err1046 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key133},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1046];
}
else {
vErrors.push(err1046);
}
errors++;
break;
}
}
if(_errs1030 === errors){
if(data338.binary !== undefined){
let data344 = data338.binary;
const _errs1031 = errors;
if(errors === _errs1031){
if(typeof data344 === "string"){
if(func1(data344) > 131072){
const err1047 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/value/binary",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/5/properties/binary/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1047];
}
else {
vErrors.push(err1047);
}
errors++;
}
}
else {
const err1048 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/value/binary",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/5/properties/binary/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1048];
}
else {
vErrors.push(err1048);
}
errors++;
}
}
}
}
}
}
else {
const err1049 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1049];
}
else {
vErrors.push(err1049);
}
errors++;
}
}
var _valid30 = _errs1028 === errors;
if(_valid30 && valid192){
valid192 = false;
passing16 = [passing16, 5];
}
else {
if(_valid30){
valid192 = true;
passing16 = 5;
if(props19 !== true){
props19 = true;
}
}
}
}
}
}
}
if(!valid192){
const err1050 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf",keyword:"oneOf",params:{passingSchemas: passing16},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err1050];
}
else {
vErrors.push(err1050);
}
errors++;
}
else {
errors = _errs1002;
if(vErrors !== null){
if(_errs1002){
vErrors.length = _errs1002;
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
const err1051 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1051];
}
else {
vErrors.push(err1051);
}
errors++;
}
}
var _valid29 = _errs998 === errors;
if(_valid29 && valid188){
valid188 = false;
passing15 = [passing15, 2];
}
else {
if(_valid29){
valid188 = true;
passing15 = 2;
if(props18 !== true){
props18 = true;
}
}
}
}
if(!valid188){
const err1052 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33+"/value",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf",keyword:"oneOf",params:{passingSchemas: passing15},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err1052];
}
else {
vErrors.push(err1052);
}
errors++;
}
else {
errors = _errs987;
if(vErrors !== null){
if(_errs987){
vErrors.length = _errs987;
}
else {
vErrors = null;
}
}
}
var valid187 = _errs986 === errors;
}
else {
var valid187 = true;
}
}
}
}
}
}
else {
const err1053 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict/" + i33,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1053];
}
else {
vErrors.push(err1053);
}
errors++;
}
}
var valid186 = _errs979 === errors;
if(!valid186){
break;
}
}
}
}
else {
const err1054 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32+"/conflict",schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err1054];
}
else {
vErrors.push(err1054);
}
errors++;
}
}
}
}
}
}
else {
const err1055 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1055];
}
else {
vErrors.push(err1055);
}
errors++;
}
}
var _valid27 = _errs974 === errors;
if(_valid27 && valid173){
valid173 = false;
passing13 = [passing13, 4];
}
else {
if(_valid27){
valid173 = true;
passing13 = 4;
if(props16 !== true){
props16 = true;
}
}
}
}
}
}
if(!valid173){
const err1056 = {instancePath:instancePath+"/page/cells/" + i31+"/" + i32,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/items/oneOf",keyword:"oneOf",params:{passingSchemas: passing13},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err1056];
}
else {
vErrors.push(err1056);
}
errors++;
}
else {
errors = _errs923;
if(vErrors !== null){
if(_errs923){
vErrors.length = _errs923;
}
else {
vErrors = null;
}
}
}
var valid172 = _errs922 === errors;
if(!valid172){
break;
}
}
}
}
else {
const err1057 = {instancePath:instancePath+"/page/cells/" + i31,schemaPath:"#/oneOf/9/properties/page/properties/cells/items/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err1057];
}
else {
vErrors.push(err1057);
}
errors++;
}
}
var valid171 = _errs920 === errors;
if(!valid171){
break;
}
}
}
}
else {
const err1058 = {instancePath:instancePath+"/page/cells",schemaPath:"#/oneOf/9/properties/page/properties/cells/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err1058];
}
else {
vErrors.push(err1058);
}
errors++;
}
}
var valid157 = _errs918 === errors;
}
else {
var valid157 = true;
}
}
}
}
}
else {
const err1059 = {instancePath:instancePath+"/page",schemaPath:"#/oneOf/9/properties/page/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1059];
}
else {
vErrors.push(err1059);
}
errors++;
}
}
}
}
}
}
else {
const err1060 = {instancePath,schemaPath:"#/oneOf/9/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1060];
}
else {
vErrors.push(err1060);
}
errors++;
}
}
var _valid0 = _errs815 === errors;
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
const _errs1033 = errors;
if(errors === _errs1033){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing134;
if((data.draft === undefined) && (missing134 = "draft")){
const err1061 = {instancePath,schemaPath:"#/oneOf/10/required",keyword:"required",params:{missingProperty: missing134},message:"must have required property '"+missing134+"'"};
if(vErrors === null){
vErrors = [err1061];
}
else {
vErrors.push(err1061);
}
errors++;
}
else {
const _errs1035 = errors;
for(const key134 in data){
if(!(key134 === "draft")){
const err1062 = {instancePath,schemaPath:"#/oneOf/10/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key134},message:"must NOT have additional properties"};
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
if(_errs1035 === errors){
if(data.draft !== undefined){
let data345 = data.draft;
const _errs1037 = errors;
let valid200 = false;
const _errs1038 = errors;
if(errors === _errs1038){
if(data345 && typeof data345 == "object" && !Array.isArray(data345)){
let missing135;
if((((((((data345.generation === undefined) && (missing135 = "generation")) || ((data345.limit === undefined) && (missing135 = "limit"))) || ((data345.starts === undefined) && (missing135 = "starts"))) || ((data345.enabled === undefined) && (missing135 = "enabled"))) || ((data345.contract === undefined) && (missing135 = "contract"))) || ((data345.budgets === undefined) && (missing135 = "budgets"))) || ((data345.namespaces === undefined) && (missing135 = "namespaces"))){
const err1063 = {instancePath:instancePath+"/draft",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/required",keyword:"required",params:{missingProperty: missing135},message:"must have required property '"+missing135+"'"};
if(vErrors === null){
vErrors = [err1063];
}
else {
vErrors.push(err1063);
}
errors++;
}
else {
const _errs1040 = errors;
for(const key135 in data345){
if(!(((((((key135 === "generation") || (key135 === "limit")) || (key135 === "starts")) || (key135 === "enabled")) || (key135 === "contract")) || (key135 === "budgets")) || (key135 === "namespaces"))){
const err1064 = {instancePath:instancePath+"/draft",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key135},message:"must NOT have additional properties"};
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
if(_errs1040 === errors){
if(data345.generation !== undefined){
let data346 = data345.generation;
const _errs1041 = errors;
if(errors === _errs1041){
if(typeof data346 === "string"){
if(func1(data346) > 131072){
const err1065 = {instancePath:instancePath+"/draft/generation",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/generation/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1065];
}
else {
vErrors.push(err1065);
}
errors++;
}
}
else {
const err1066 = {instancePath:instancePath+"/draft/generation",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/generation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1066];
}
else {
vErrors.push(err1066);
}
errors++;
}
}
var valid201 = _errs1041 === errors;
}
else {
var valid201 = true;
}
if(valid201){
if(data345.limit !== undefined){
let data347 = data345.limit;
const _errs1043 = errors;
if(!(((typeof data347 == "number") && (!(data347 % 1) && !isNaN(data347))) && (isFinite(data347)))){
const err1067 = {instancePath:instancePath+"/draft/limit",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/limit/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err1067];
}
else {
vErrors.push(err1067);
}
errors++;
}
if(errors === _errs1043){
if((typeof data347 == "number") && (isFinite(data347))){
if(data347 > 255 || isNaN(data347)){
const err1068 = {instancePath:instancePath+"/draft/limit",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/limit/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err1068];
}
else {
vErrors.push(err1068);
}
errors++;
}
else {
if(data347 < 0 || isNaN(data347)){
const err1069 = {instancePath:instancePath+"/draft/limit",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/limit/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid201 = _errs1043 === errors;
}
else {
var valid201 = true;
}
if(valid201){
if(data345.starts !== undefined){
let data348 = data345.starts;
const _errs1045 = errors;
if(!(((typeof data348 == "number") && (!(data348 % 1) && !isNaN(data348))) && (isFinite(data348)))){
const err1070 = {instancePath:instancePath+"/draft/starts",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/starts/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err1070];
}
else {
vErrors.push(err1070);
}
errors++;
}
if(errors === _errs1045){
if((typeof data348 == "number") && (isFinite(data348))){
if(data348 > 255 || isNaN(data348)){
const err1071 = {instancePath:instancePath+"/draft/starts",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/starts/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err1071];
}
else {
vErrors.push(err1071);
}
errors++;
}
else {
if(data348 < 0 || isNaN(data348)){
const err1072 = {instancePath:instancePath+"/draft/starts",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/starts/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err1072];
}
else {
vErrors.push(err1072);
}
errors++;
}
}
}
}
var valid201 = _errs1045 === errors;
}
else {
var valid201 = true;
}
if(valid201){
if(data345.enabled !== undefined){
const _errs1047 = errors;
if(typeof data345.enabled !== "boolean"){
const err1073 = {instancePath:instancePath+"/draft/enabled",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/enabled/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err1073];
}
else {
vErrors.push(err1073);
}
errors++;
}
var valid201 = _errs1047 === errors;
}
else {
var valid201 = true;
}
if(valid201){
if(data345.contract !== undefined){
let data350 = data345.contract;
const _errs1049 = errors;
if(errors === _errs1049){
if(Array.isArray(data350)){
if(data350.length > 32){
const err1074 = {instancePath:instancePath+"/draft/contract",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/contract/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err1074];
}
else {
vErrors.push(err1074);
}
errors++;
}
else {
if(data350.length < 32){
const err1075 = {instancePath:instancePath+"/draft/contract",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/contract/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err1075];
}
else {
vErrors.push(err1075);
}
errors++;
}
else {
var valid202 = true;
const len34 = data350.length;
for(let i34=0; i34<len34; i34++){
let data351 = data350[i34];
const _errs1051 = errors;
if(!(((typeof data351 == "number") && (!(data351 % 1) && !isNaN(data351))) && (isFinite(data351)))){
const err1076 = {instancePath:instancePath+"/draft/contract/" + i34,schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/contract/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err1076];
}
else {
vErrors.push(err1076);
}
errors++;
}
if(errors === _errs1051){
if((typeof data351 == "number") && (isFinite(data351))){
if(data351 > 255 || isNaN(data351)){
const err1077 = {instancePath:instancePath+"/draft/contract/" + i34,schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/contract/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err1077];
}
else {
vErrors.push(err1077);
}
errors++;
}
else {
if(data351 < 0 || isNaN(data351)){
const err1078 = {instancePath:instancePath+"/draft/contract/" + i34,schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/contract/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err1078];
}
else {
vErrors.push(err1078);
}
errors++;
}
}
}
}
var valid202 = _errs1051 === errors;
if(!valid202){
break;
}
}
}
}
}
else {
const err1079 = {instancePath:instancePath+"/draft/contract",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/contract/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err1079];
}
else {
vErrors.push(err1079);
}
errors++;
}
}
var valid201 = _errs1049 === errors;
}
else {
var valid201 = true;
}
if(valid201){
if(data345.budgets !== undefined){
let data352 = data345.budgets;
const _errs1053 = errors;
if(errors === _errs1053){
if(data352 && typeof data352 == "object" && !Array.isArray(data352)){
let missing136;
if((((data352.pages === undefined) && (missing136 = "pages")) || ((data352.segments === undefined) && (missing136 = "segments"))) || ((data352.result_bytes === undefined) && (missing136 = "result_bytes"))){
const err1080 = {instancePath:instancePath+"/draft/budgets",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/budgets/required",keyword:"required",params:{missingProperty: missing136},message:"must have required property '"+missing136+"'"};
if(vErrors === null){
vErrors = [err1080];
}
else {
vErrors.push(err1080);
}
errors++;
}
else {
const _errs1055 = errors;
for(const key136 in data352){
if(!(((key136 === "pages") || (key136 === "segments")) || (key136 === "result_bytes"))){
const err1081 = {instancePath:instancePath+"/draft/budgets",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/budgets/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key136},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1081];
}
else {
vErrors.push(err1081);
}
errors++;
break;
}
}
if(_errs1055 === errors){
if(data352.pages !== undefined){
let data353 = data352.pages;
const _errs1056 = errors;
if(errors === _errs1056){
if(typeof data353 === "string"){
if(func1(data353) > 131072){
const err1082 = {instancePath:instancePath+"/draft/budgets/pages",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/budgets/properties/pages/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1082];
}
else {
vErrors.push(err1082);
}
errors++;
}
}
else {
const err1083 = {instancePath:instancePath+"/draft/budgets/pages",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/budgets/properties/pages/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1083];
}
else {
vErrors.push(err1083);
}
errors++;
}
}
var valid203 = _errs1056 === errors;
}
else {
var valid203 = true;
}
if(valid203){
if(data352.segments !== undefined){
let data354 = data352.segments;
const _errs1058 = errors;
if(errors === _errs1058){
if(typeof data354 === "string"){
if(func1(data354) > 131072){
const err1084 = {instancePath:instancePath+"/draft/budgets/segments",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/budgets/properties/segments/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1084];
}
else {
vErrors.push(err1084);
}
errors++;
}
}
else {
const err1085 = {instancePath:instancePath+"/draft/budgets/segments",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/budgets/properties/segments/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1085];
}
else {
vErrors.push(err1085);
}
errors++;
}
}
var valid203 = _errs1058 === errors;
}
else {
var valid203 = true;
}
if(valid203){
if(data352.result_bytes !== undefined){
let data355 = data352.result_bytes;
const _errs1060 = errors;
if(errors === _errs1060){
if(typeof data355 === "string"){
if(func1(data355) > 131072){
const err1086 = {instancePath:instancePath+"/draft/budgets/result_bytes",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/budgets/properties/result_bytes/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1086];
}
else {
vErrors.push(err1086);
}
errors++;
}
}
else {
const err1087 = {instancePath:instancePath+"/draft/budgets/result_bytes",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/budgets/properties/result_bytes/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1087];
}
else {
vErrors.push(err1087);
}
errors++;
}
}
var valid203 = _errs1060 === errors;
}
else {
var valid203 = true;
}
}
}
}
}
}
else {
const err1088 = {instancePath:instancePath+"/draft/budgets",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/budgets/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1088];
}
else {
vErrors.push(err1088);
}
errors++;
}
}
var valid201 = _errs1053 === errors;
}
else {
var valid201 = true;
}
if(valid201){
if(data345.namespaces !== undefined){
let data356 = data345.namespaces;
const _errs1062 = errors;
if(errors === _errs1062){
if(Array.isArray(data356)){
if(data356.length > 8){
const err1089 = {instancePath:instancePath+"/draft/namespaces",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/namespaces/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err1089];
}
else {
vErrors.push(err1089);
}
errors++;
}
else {
if(data356.length < 8){
const err1090 = {instancePath:instancePath+"/draft/namespaces",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/namespaces/minItems",keyword:"minItems",params:{limit: 8},message:"must NOT have fewer than 8 items"};
if(vErrors === null){
vErrors = [err1090];
}
else {
vErrors.push(err1090);
}
errors++;
}
else {
var valid204 = true;
const len35 = data356.length;
for(let i35=0; i35<len35; i35++){
let data357 = data356[i35];
const _errs1064 = errors;
if(errors === _errs1064){
if(typeof data357 === "string"){
if(func1(data357) > 131072){
const err1091 = {instancePath:instancePath+"/draft/namespaces/" + i35,schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/namespaces/items/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1091];
}
else {
vErrors.push(err1091);
}
errors++;
}
}
else {
const err1092 = {instancePath:instancePath+"/draft/namespaces/" + i35,schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/namespaces/items/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1092];
}
else {
vErrors.push(err1092);
}
errors++;
}
}
var valid204 = _errs1064 === errors;
if(!valid204){
break;
}
}
}
}
}
else {
const err1093 = {instancePath:instancePath+"/draft/namespaces",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/properties/namespaces/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err1093];
}
else {
vErrors.push(err1093);
}
errors++;
}
}
var valid201 = _errs1062 === errors;
}
else {
var valid201 = true;
}
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
const err1094 = {instancePath:instancePath+"/draft",schemaPath:"#/oneOf/10/properties/draft/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1094];
}
else {
vErrors.push(err1094);
}
errors++;
}
}
var _valid31 = _errs1038 === errors;
valid200 = valid200 || _valid31;
const _errs1066 = errors;
if(data345 !== null){
const err1095 = {instancePath:instancePath+"/draft",schemaPath:"#/oneOf/10/properties/draft/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err1095];
}
else {
vErrors.push(err1095);
}
errors++;
}
var _valid31 = _errs1066 === errors;
valid200 = valid200 || _valid31;
if(!valid200){
const err1096 = {instancePath:instancePath+"/draft",schemaPath:"#/oneOf/10/properties/draft/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err1096];
}
else {
vErrors.push(err1096);
}
errors++;
}
else {
errors = _errs1037;
if(vErrors !== null){
if(_errs1037){
vErrors.length = _errs1037;
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
const err1097 = {instancePath,schemaPath:"#/oneOf/10/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1097];
}
else {
vErrors.push(err1097);
}
errors++;
}
}
var _valid0 = _errs1033 === errors;
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
const err1098 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err1098];
}
else {
vErrors.push(err1098);
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
