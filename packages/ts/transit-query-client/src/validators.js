// Generated; no runtime code generation or eval.
import lengthModule from "ajv/dist/runtime/ucs2length.js";
const ucs2length = lengthModule.default ?? lengthModule;
"use strict";
export const Request = validate21;
const schema32 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["describe"],"properties":{"describe":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["compile"],"properties":{"compile":{"type":"object","additionalProperties":false,"properties":{"sql":{"type":"string","maxLength":131072}},"required":["sql"]}}},{"type":"object","additionalProperties":false,"required":["next"],"properties":{"next":{"type":"object","additionalProperties":false,"properties":{"namespace":{"type":"string","maxLength":131072},"bundle":{"type":"string","maxLength":131072}},"required":["namespace","bundle"]}}},{"type":"object","additionalProperties":false,"required":["next_draft"],"properties":{"next_draft":{"type":"object","additionalProperties":false,"properties":{"namespace":{"type":"string","maxLength":131072},"bundle":{"type":"string","maxLength":131072},"generation":{"type":"string","maxLength":131072}},"required":["namespace","bundle","generation"]}}},{"type":"object","additionalProperties":false,"required":["draft_open"],"properties":{"draft_open":{"type":"object","additionalProperties":false,"properties":{"expected":{"type":"string","maxLength":131072},"limit":{"type":"integer","minimum":0,"maximum":255}},"required":["expected","limit"]}}},{"type":"object","additionalProperties":false,"required":["draft_close"],"properties":{"draft_close":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["draft_status"],"properties":{"draft_status":{"anyOf":[{"type":"string","maxLength":131072},{"type":"null"}]}}},{"type":"object","additionalProperties":false,"required":["submit"],"properties":{"submit":{"type":"object","additionalProperties":false,"properties":{"token":{"type":"string","maxLength":131072}},"required":["token"]}}},{"type":"object","additionalProperties":false,"required":["observe"],"properties":{"observe":{"type":"integer","minimum":0,"maximum":9007199254740991}}},{"type":"object","additionalProperties":false,"required":["status"],"properties":{"status":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["page"],"properties":{"page":{"type":"object","additionalProperties":false,"properties":{"namespace":{"type":"string","maxLength":131072},"cursor":{"anyOf":[{"type":"string","maxLength":131072},{"type":"null"}]}},"required":["namespace","cursor"]}}},{"type":"object","additionalProperties":false,"required":["prepare_control"],"properties":{"prepare_control":{"type":"object","additionalProperties":false,"properties":{"namespace":{"type":"string","maxLength":131072},"operation":{"type":"string","enum":["cancel","collect","retire"]}},"required":["namespace","operation"]}}}]};
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
if((data.compile === undefined) && (missing1 = "compile")){
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
if(!(key1 === "compile")){
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
if(data.compile !== undefined){
let data1 = data.compile;
const _errs9 = errors;
if(errors === _errs9){
if(data1 && typeof data1 == "object" && !Array.isArray(data1)){
let missing2;
if((data1.sql === undefined) && (missing2 = "sql")){
const err7 = {instancePath:instancePath+"/compile",schemaPath:"#/oneOf/1/properties/compile/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
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
if(!(key2 === "sql")){
const err8 = {instancePath:instancePath+"/compile",schemaPath:"#/oneOf/1/properties/compile/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(data1.sql !== undefined){
let data2 = data1.sql;
const _errs12 = errors;
if(errors === _errs12){
if(typeof data2 === "string"){
if(func1(data2) > 131072){
const err9 = {instancePath:instancePath+"/compile/sql",schemaPath:"#/oneOf/1/properties/compile/properties/sql/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err10 = {instancePath:instancePath+"/compile/sql",schemaPath:"#/oneOf/1/properties/compile/properties/sql/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
const err11 = {instancePath:instancePath+"/compile",schemaPath:"#/oneOf/1/properties/compile/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.next === undefined) && (missing3 = "next")){
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
if(!(key3 === "next")){
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
if(data.next !== undefined){
let data3 = data.next;
const _errs17 = errors;
if(errors === _errs17){
if(data3 && typeof data3 == "object" && !Array.isArray(data3)){
let missing4;
if(((data3.namespace === undefined) && (missing4 = "namespace")) || ((data3.bundle === undefined) && (missing4 = "bundle"))){
const err15 = {instancePath:instancePath+"/next",schemaPath:"#/oneOf/2/properties/next/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
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
if(!((key4 === "namespace") || (key4 === "bundle"))){
const err16 = {instancePath:instancePath+"/next",schemaPath:"#/oneOf/2/properties/next/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(data3.namespace !== undefined){
let data4 = data3.namespace;
const _errs20 = errors;
if(errors === _errs20){
if(typeof data4 === "string"){
if(func1(data4) > 131072){
const err17 = {instancePath:instancePath+"/next/namespace",schemaPath:"#/oneOf/2/properties/next/properties/namespace/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err18 = {instancePath:instancePath+"/next/namespace",schemaPath:"#/oneOf/2/properties/next/properties/namespace/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
if(data3.bundle !== undefined){
let data5 = data3.bundle;
const _errs22 = errors;
if(errors === _errs22){
if(typeof data5 === "string"){
if(func1(data5) > 131072){
const err19 = {instancePath:instancePath+"/next/bundle",schemaPath:"#/oneOf/2/properties/next/properties/bundle/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
}
}
else {
const err20 = {instancePath:instancePath+"/next/bundle",schemaPath:"#/oneOf/2/properties/next/properties/bundle/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err20];
}
else {
vErrors.push(err20);
}
errors++;
}
}
var valid5 = _errs22 === errors;
}
else {
var valid5 = true;
}
}
}
}
}
else {
const err21 = {instancePath:instancePath+"/next",schemaPath:"#/oneOf/2/properties/next/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err22 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err22];
}
else {
vErrors.push(err22);
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
const _errs24 = errors;
if(errors === _errs24){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing5;
if((data.next_draft === undefined) && (missing5 = "next_draft")){
const err23 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
if(vErrors === null){
vErrors = [err23];
}
else {
vErrors.push(err23);
}
errors++;
}
else {
const _errs26 = errors;
for(const key5 in data){
if(!(key5 === "next_draft")){
const err24 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
}
errors++;
break;
}
}
if(_errs26 === errors){
if(data.next_draft !== undefined){
let data6 = data.next_draft;
const _errs27 = errors;
if(errors === _errs27){
if(data6 && typeof data6 == "object" && !Array.isArray(data6)){
let missing6;
if((((data6.namespace === undefined) && (missing6 = "namespace")) || ((data6.bundle === undefined) && (missing6 = "bundle"))) || ((data6.generation === undefined) && (missing6 = "generation"))){
const err25 = {instancePath:instancePath+"/next_draft",schemaPath:"#/oneOf/3/properties/next_draft/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
if(vErrors === null){
vErrors = [err25];
}
else {
vErrors.push(err25);
}
errors++;
}
else {
const _errs29 = errors;
for(const key6 in data6){
if(!(((key6 === "namespace") || (key6 === "bundle")) || (key6 === "generation"))){
const err26 = {instancePath:instancePath+"/next_draft",schemaPath:"#/oneOf/3/properties/next_draft/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err26];
}
else {
vErrors.push(err26);
}
errors++;
break;
}
}
if(_errs29 === errors){
if(data6.namespace !== undefined){
let data7 = data6.namespace;
const _errs30 = errors;
if(errors === _errs30){
if(typeof data7 === "string"){
if(func1(data7) > 131072){
const err27 = {instancePath:instancePath+"/next_draft/namespace",schemaPath:"#/oneOf/3/properties/next_draft/properties/namespace/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err27];
}
else {
vErrors.push(err27);
}
errors++;
}
}
else {
const err28 = {instancePath:instancePath+"/next_draft/namespace",schemaPath:"#/oneOf/3/properties/next_draft/properties/namespace/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err28];
}
else {
vErrors.push(err28);
}
errors++;
}
}
var valid7 = _errs30 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data6.bundle !== undefined){
let data8 = data6.bundle;
const _errs32 = errors;
if(errors === _errs32){
if(typeof data8 === "string"){
if(func1(data8) > 131072){
const err29 = {instancePath:instancePath+"/next_draft/bundle",schemaPath:"#/oneOf/3/properties/next_draft/properties/bundle/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err29];
}
else {
vErrors.push(err29);
}
errors++;
}
}
else {
const err30 = {instancePath:instancePath+"/next_draft/bundle",schemaPath:"#/oneOf/3/properties/next_draft/properties/bundle/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
}
errors++;
}
}
var valid7 = _errs32 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data6.generation !== undefined){
let data9 = data6.generation;
const _errs34 = errors;
if(errors === _errs34){
if(typeof data9 === "string"){
if(func1(data9) > 131072){
const err31 = {instancePath:instancePath+"/next_draft/generation",schemaPath:"#/oneOf/3/properties/next_draft/properties/generation/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err32 = {instancePath:instancePath+"/next_draft/generation",schemaPath:"#/oneOf/3/properties/next_draft/properties/generation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err32];
}
else {
vErrors.push(err32);
}
errors++;
}
}
var valid7 = _errs34 === errors;
}
else {
var valid7 = true;
}
}
}
}
}
}
else {
const err33 = {instancePath:instancePath+"/next_draft",schemaPath:"#/oneOf/3/properties/next_draft/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err34 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err34];
}
else {
vErrors.push(err34);
}
errors++;
}
}
var _valid0 = _errs24 === errors;
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
if((data.draft_open === undefined) && (missing7 = "draft_open")){
const err35 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
if(vErrors === null){
vErrors = [err35];
}
else {
vErrors.push(err35);
}
errors++;
}
else {
const _errs38 = errors;
for(const key7 in data){
if(!(key7 === "draft_open")){
const err36 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
break;
}
}
if(_errs38 === errors){
if(data.draft_open !== undefined){
let data10 = data.draft_open;
const _errs39 = errors;
if(errors === _errs39){
if(data10 && typeof data10 == "object" && !Array.isArray(data10)){
let missing8;
if(((data10.expected === undefined) && (missing8 = "expected")) || ((data10.limit === undefined) && (missing8 = "limit"))){
const err37 = {instancePath:instancePath+"/draft_open",schemaPath:"#/oneOf/4/properties/draft_open/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
if(vErrors === null){
vErrors = [err37];
}
else {
vErrors.push(err37);
}
errors++;
}
else {
const _errs41 = errors;
for(const key8 in data10){
if(!((key8 === "expected") || (key8 === "limit"))){
const err38 = {instancePath:instancePath+"/draft_open",schemaPath:"#/oneOf/4/properties/draft_open/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
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
if(_errs41 === errors){
if(data10.expected !== undefined){
let data11 = data10.expected;
const _errs42 = errors;
if(errors === _errs42){
if(typeof data11 === "string"){
if(func1(data11) > 131072){
const err39 = {instancePath:instancePath+"/draft_open/expected",schemaPath:"#/oneOf/4/properties/draft_open/properties/expected/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err39];
}
else {
vErrors.push(err39);
}
errors++;
}
}
else {
const err40 = {instancePath:instancePath+"/draft_open/expected",schemaPath:"#/oneOf/4/properties/draft_open/properties/expected/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err40];
}
else {
vErrors.push(err40);
}
errors++;
}
}
var valid9 = _errs42 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data10.limit !== undefined){
let data12 = data10.limit;
const _errs44 = errors;
if(!(((typeof data12 == "number") && (!(data12 % 1) && !isNaN(data12))) && (isFinite(data12)))){
const err41 = {instancePath:instancePath+"/draft_open/limit",schemaPath:"#/oneOf/4/properties/draft_open/properties/limit/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err41];
}
else {
vErrors.push(err41);
}
errors++;
}
if(errors === _errs44){
if((typeof data12 == "number") && (isFinite(data12))){
if(data12 > 255 || isNaN(data12)){
const err42 = {instancePath:instancePath+"/draft_open/limit",schemaPath:"#/oneOf/4/properties/draft_open/properties/limit/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err42];
}
else {
vErrors.push(err42);
}
errors++;
}
else {
if(data12 < 0 || isNaN(data12)){
const err43 = {instancePath:instancePath+"/draft_open/limit",schemaPath:"#/oneOf/4/properties/draft_open/properties/limit/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid9 = _errs44 === errors;
}
else {
var valid9 = true;
}
}
}
}
}
else {
const err44 = {instancePath:instancePath+"/draft_open",schemaPath:"#/oneOf/4/properties/draft_open/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err45 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err45];
}
else {
vErrors.push(err45);
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
const _errs46 = errors;
if(errors === _errs46){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing9;
if((data.draft_close === undefined) && (missing9 = "draft_close")){
const err46 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
if(vErrors === null){
vErrors = [err46];
}
else {
vErrors.push(err46);
}
errors++;
}
else {
const _errs48 = errors;
for(const key9 in data){
if(!(key9 === "draft_close")){
const err47 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
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
if(_errs48 === errors){
if(data.draft_close !== undefined){
let data13 = data.draft_close;
const _errs49 = errors;
if(errors === _errs49){
if(typeof data13 === "string"){
if(func1(data13) > 131072){
const err48 = {instancePath:instancePath+"/draft_close",schemaPath:"#/oneOf/5/properties/draft_close/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err49 = {instancePath:instancePath+"/draft_close",schemaPath:"#/oneOf/5/properties/draft_close/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
const err50 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err50];
}
else {
vErrors.push(err50);
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
const _errs51 = errors;
if(errors === _errs51){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing10;
if((data.draft_status === undefined) && (missing10 = "draft_status")){
const err51 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"};
if(vErrors === null){
vErrors = [err51];
}
else {
vErrors.push(err51);
}
errors++;
}
else {
const _errs53 = errors;
for(const key10 in data){
if(!(key10 === "draft_status")){
const err52 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"};
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
if(_errs53 === errors){
if(data.draft_status !== undefined){
let data14 = data.draft_status;
const _errs55 = errors;
let valid12 = false;
const _errs56 = errors;
if(errors === _errs56){
if(typeof data14 === "string"){
if(func1(data14) > 131072){
const err53 = {instancePath:instancePath+"/draft_status",schemaPath:"#/oneOf/6/properties/draft_status/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err54 = {instancePath:instancePath+"/draft_status",schemaPath:"#/oneOf/6/properties/draft_status/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err54];
}
else {
vErrors.push(err54);
}
errors++;
}
}
var _valid1 = _errs56 === errors;
valid12 = valid12 || _valid1;
const _errs58 = errors;
if(data14 !== null){
const err55 = {instancePath:instancePath+"/draft_status",schemaPath:"#/oneOf/6/properties/draft_status/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err55];
}
else {
vErrors.push(err55);
}
errors++;
}
var _valid1 = _errs58 === errors;
valid12 = valid12 || _valid1;
if(!valid12){
const err56 = {instancePath:instancePath+"/draft_status",schemaPath:"#/oneOf/6/properties/draft_status/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err56];
}
else {
vErrors.push(err56);
}
errors++;
}
else {
errors = _errs55;
if(vErrors !== null){
if(_errs55){
vErrors.length = _errs55;
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
var _valid0 = _errs51 === errors;
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
const _errs60 = errors;
if(errors === _errs60){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing11;
if((data.submit === undefined) && (missing11 = "submit")){
const err58 = {instancePath,schemaPath:"#/oneOf/7/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
if(vErrors === null){
vErrors = [err58];
}
else {
vErrors.push(err58);
}
errors++;
}
else {
const _errs62 = errors;
for(const key11 in data){
if(!(key11 === "submit")){
const err59 = {instancePath,schemaPath:"#/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
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
if(_errs62 === errors){
if(data.submit !== undefined){
let data15 = data.submit;
const _errs63 = errors;
if(errors === _errs63){
if(data15 && typeof data15 == "object" && !Array.isArray(data15)){
let missing12;
if((data15.token === undefined) && (missing12 = "token")){
const err60 = {instancePath:instancePath+"/submit",schemaPath:"#/oneOf/7/properties/submit/required",keyword:"required",params:{missingProperty: missing12},message:"must have required property '"+missing12+"'"};
if(vErrors === null){
vErrors = [err60];
}
else {
vErrors.push(err60);
}
errors++;
}
else {
const _errs65 = errors;
for(const key12 in data15){
if(!(key12 === "token")){
const err61 = {instancePath:instancePath+"/submit",schemaPath:"#/oneOf/7/properties/submit/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key12},message:"must NOT have additional properties"};
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
if(_errs65 === errors){
if(data15.token !== undefined){
let data16 = data15.token;
const _errs66 = errors;
if(errors === _errs66){
if(typeof data16 === "string"){
if(func1(data16) > 131072){
const err62 = {instancePath:instancePath+"/submit/token",schemaPath:"#/oneOf/7/properties/submit/properties/token/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err63 = {instancePath:instancePath+"/submit/token",schemaPath:"#/oneOf/7/properties/submit/properties/token/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
const err64 = {instancePath:instancePath+"/submit",schemaPath:"#/oneOf/7/properties/submit/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err64];
}
else {
vErrors.push(err64);
}
errors++;
}
}
}
}
}
}
else {
const err65 = {instancePath,schemaPath:"#/oneOf/7/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err65];
}
else {
vErrors.push(err65);
}
errors++;
}
}
var _valid0 = _errs60 === errors;
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
const _errs68 = errors;
if(errors === _errs68){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing13;
if((data.observe === undefined) && (missing13 = "observe")){
const err66 = {instancePath,schemaPath:"#/oneOf/8/required",keyword:"required",params:{missingProperty: missing13},message:"must have required property '"+missing13+"'"};
if(vErrors === null){
vErrors = [err66];
}
else {
vErrors.push(err66);
}
errors++;
}
else {
const _errs70 = errors;
for(const key13 in data){
if(!(key13 === "observe")){
const err67 = {instancePath,schemaPath:"#/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key13},message:"must NOT have additional properties"};
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
if(_errs70 === errors){
if(data.observe !== undefined){
let data17 = data.observe;
const _errs71 = errors;
if(!(((typeof data17 == "number") && (!(data17 % 1) && !isNaN(data17))) && (isFinite(data17)))){
const err68 = {instancePath:instancePath+"/observe",schemaPath:"#/oneOf/8/properties/observe/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err68];
}
else {
vErrors.push(err68);
}
errors++;
}
if(errors === _errs71){
if((typeof data17 == "number") && (isFinite(data17))){
if(data17 > 9007199254740991 || isNaN(data17)){
const err69 = {instancePath:instancePath+"/observe",schemaPath:"#/oneOf/8/properties/observe/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err69];
}
else {
vErrors.push(err69);
}
errors++;
}
else {
if(data17 < 0 || isNaN(data17)){
const err70 = {instancePath:instancePath+"/observe",schemaPath:"#/oneOf/8/properties/observe/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err70];
}
else {
vErrors.push(err70);
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
const err71 = {instancePath,schemaPath:"#/oneOf/8/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err71];
}
else {
vErrors.push(err71);
}
errors++;
}
}
var _valid0 = _errs68 === errors;
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
const _errs73 = errors;
if(errors === _errs73){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing14;
if((data.status === undefined) && (missing14 = "status")){
const err72 = {instancePath,schemaPath:"#/oneOf/9/required",keyword:"required",params:{missingProperty: missing14},message:"must have required property '"+missing14+"'"};
if(vErrors === null){
vErrors = [err72];
}
else {
vErrors.push(err72);
}
errors++;
}
else {
const _errs75 = errors;
for(const key14 in data){
if(!(key14 === "status")){
const err73 = {instancePath,schemaPath:"#/oneOf/9/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key14},message:"must NOT have additional properties"};
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
if(_errs75 === errors){
if(data.status !== undefined){
let data18 = data.status;
const _errs76 = errors;
if(errors === _errs76){
if(typeof data18 === "string"){
if(func1(data18) > 131072){
const err74 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/9/properties/status/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err75 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/9/properties/status/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
const err76 = {instancePath,schemaPath:"#/oneOf/9/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err76];
}
else {
vErrors.push(err76);
}
errors++;
}
}
var _valid0 = _errs73 === errors;
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
const _errs78 = errors;
if(errors === _errs78){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing15;
if((data.page === undefined) && (missing15 = "page")){
const err77 = {instancePath,schemaPath:"#/oneOf/10/required",keyword:"required",params:{missingProperty: missing15},message:"must have required property '"+missing15+"'"};
if(vErrors === null){
vErrors = [err77];
}
else {
vErrors.push(err77);
}
errors++;
}
else {
const _errs80 = errors;
for(const key15 in data){
if(!(key15 === "page")){
const err78 = {instancePath,schemaPath:"#/oneOf/10/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key15},message:"must NOT have additional properties"};
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
if(_errs80 === errors){
if(data.page !== undefined){
let data19 = data.page;
const _errs81 = errors;
if(errors === _errs81){
if(data19 && typeof data19 == "object" && !Array.isArray(data19)){
let missing16;
if(((data19.namespace === undefined) && (missing16 = "namespace")) || ((data19.cursor === undefined) && (missing16 = "cursor"))){
const err79 = {instancePath:instancePath+"/page",schemaPath:"#/oneOf/10/properties/page/required",keyword:"required",params:{missingProperty: missing16},message:"must have required property '"+missing16+"'"};
if(vErrors === null){
vErrors = [err79];
}
else {
vErrors.push(err79);
}
errors++;
}
else {
const _errs83 = errors;
for(const key16 in data19){
if(!((key16 === "namespace") || (key16 === "cursor"))){
const err80 = {instancePath:instancePath+"/page",schemaPath:"#/oneOf/10/properties/page/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key16},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err80];
}
else {
vErrors.push(err80);
}
errors++;
break;
}
}
if(_errs83 === errors){
if(data19.namespace !== undefined){
let data20 = data19.namespace;
const _errs84 = errors;
if(errors === _errs84){
if(typeof data20 === "string"){
if(func1(data20) > 131072){
const err81 = {instancePath:instancePath+"/page/namespace",schemaPath:"#/oneOf/10/properties/page/properties/namespace/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err81];
}
else {
vErrors.push(err81);
}
errors++;
}
}
else {
const err82 = {instancePath:instancePath+"/page/namespace",schemaPath:"#/oneOf/10/properties/page/properties/namespace/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err82];
}
else {
vErrors.push(err82);
}
errors++;
}
}
var valid18 = _errs84 === errors;
}
else {
var valid18 = true;
}
if(valid18){
if(data19.cursor !== undefined){
let data21 = data19.cursor;
const _errs86 = errors;
const _errs87 = errors;
let valid19 = false;
const _errs88 = errors;
if(errors === _errs88){
if(typeof data21 === "string"){
if(func1(data21) > 131072){
const err83 = {instancePath:instancePath+"/page/cursor",schemaPath:"#/oneOf/10/properties/page/properties/cursor/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err83];
}
else {
vErrors.push(err83);
}
errors++;
}
}
else {
const err84 = {instancePath:instancePath+"/page/cursor",schemaPath:"#/oneOf/10/properties/page/properties/cursor/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err84];
}
else {
vErrors.push(err84);
}
errors++;
}
}
var _valid2 = _errs88 === errors;
valid19 = valid19 || _valid2;
const _errs90 = errors;
if(data21 !== null){
const err85 = {instancePath:instancePath+"/page/cursor",schemaPath:"#/oneOf/10/properties/page/properties/cursor/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err85];
}
else {
vErrors.push(err85);
}
errors++;
}
var _valid2 = _errs90 === errors;
valid19 = valid19 || _valid2;
if(!valid19){
const err86 = {instancePath:instancePath+"/page/cursor",schemaPath:"#/oneOf/10/properties/page/properties/cursor/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err86];
}
else {
vErrors.push(err86);
}
errors++;
}
else {
errors = _errs87;
if(vErrors !== null){
if(_errs87){
vErrors.length = _errs87;
}
else {
vErrors = null;
}
}
}
var valid18 = _errs86 === errors;
}
else {
var valid18 = true;
}
}
}
}
}
else {
const err87 = {instancePath:instancePath+"/page",schemaPath:"#/oneOf/10/properties/page/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err87];
}
else {
vErrors.push(err87);
}
errors++;
}
}
}
}
}
}
else {
const err88 = {instancePath,schemaPath:"#/oneOf/10/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err88];
}
else {
vErrors.push(err88);
}
errors++;
}
}
var _valid0 = _errs78 === errors;
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
const _errs92 = errors;
if(errors === _errs92){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing17;
if((data.prepare_control === undefined) && (missing17 = "prepare_control")){
const err89 = {instancePath,schemaPath:"#/oneOf/11/required",keyword:"required",params:{missingProperty: missing17},message:"must have required property '"+missing17+"'"};
if(vErrors === null){
vErrors = [err89];
}
else {
vErrors.push(err89);
}
errors++;
}
else {
const _errs94 = errors;
for(const key17 in data){
if(!(key17 === "prepare_control")){
const err90 = {instancePath,schemaPath:"#/oneOf/11/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key17},message:"must NOT have additional properties"};
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
if(_errs94 === errors){
if(data.prepare_control !== undefined){
let data22 = data.prepare_control;
const _errs95 = errors;
if(errors === _errs95){
if(data22 && typeof data22 == "object" && !Array.isArray(data22)){
let missing18;
if(((data22.namespace === undefined) && (missing18 = "namespace")) || ((data22.operation === undefined) && (missing18 = "operation"))){
const err91 = {instancePath:instancePath+"/prepare_control",schemaPath:"#/oneOf/11/properties/prepare_control/required",keyword:"required",params:{missingProperty: missing18},message:"must have required property '"+missing18+"'"};
if(vErrors === null){
vErrors = [err91];
}
else {
vErrors.push(err91);
}
errors++;
}
else {
const _errs97 = errors;
for(const key18 in data22){
if(!((key18 === "namespace") || (key18 === "operation"))){
const err92 = {instancePath:instancePath+"/prepare_control",schemaPath:"#/oneOf/11/properties/prepare_control/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key18},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err92];
}
else {
vErrors.push(err92);
}
errors++;
break;
}
}
if(_errs97 === errors){
if(data22.namespace !== undefined){
let data23 = data22.namespace;
const _errs98 = errors;
if(errors === _errs98){
if(typeof data23 === "string"){
if(func1(data23) > 131072){
const err93 = {instancePath:instancePath+"/prepare_control/namespace",schemaPath:"#/oneOf/11/properties/prepare_control/properties/namespace/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err93];
}
else {
vErrors.push(err93);
}
errors++;
}
}
else {
const err94 = {instancePath:instancePath+"/prepare_control/namespace",schemaPath:"#/oneOf/11/properties/prepare_control/properties/namespace/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err94];
}
else {
vErrors.push(err94);
}
errors++;
}
}
var valid21 = _errs98 === errors;
}
else {
var valid21 = true;
}
if(valid21){
if(data22.operation !== undefined){
let data24 = data22.operation;
const _errs100 = errors;
if(typeof data24 !== "string"){
const err95 = {instancePath:instancePath+"/prepare_control/operation",schemaPath:"#/oneOf/11/properties/prepare_control/properties/operation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err95];
}
else {
vErrors.push(err95);
}
errors++;
}
if(!(((data24 === "cancel") || (data24 === "collect")) || (data24 === "retire"))){
const err96 = {instancePath:instancePath+"/prepare_control/operation",schemaPath:"#/oneOf/11/properties/prepare_control/properties/operation/enum",keyword:"enum",params:{allowedValues: schema32.oneOf[11].properties.prepare_control.properties.operation.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err96];
}
else {
vErrors.push(err96);
}
errors++;
}
var valid21 = _errs100 === errors;
}
else {
var valid21 = true;
}
}
}
}
}
else {
const err97 = {instancePath:instancePath+"/prepare_control",schemaPath:"#/oneOf/11/properties/prepare_control/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err97];
}
else {
vErrors.push(err97);
}
errors++;
}
}
}
}
}
}
else {
const err98 = {instancePath,schemaPath:"#/oneOf/11/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err98];
}
else {
vErrors.push(err98);
}
errors++;
}
}
var _valid0 = _errs92 === errors;
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
const err99 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err99];
}
else {
vErrors.push(err99);
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
const schema33 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["description"],"properties":{"description":{"type":"object","additionalProperties":false,"properties":{"connection":{"type":"object","additionalProperties":false,"properties":{"realm":{"type":"integer","minimum":0,"maximum":9007199254740991},"principal":{"type":"integer","minimum":0,"maximum":9007199254740991},"source":{"type":"integer","minimum":0,"maximum":9007199254740991},"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"requester":{"type":"integer","minimum":0,"maximum":9007199254740991},"requests":{"type":"integer","minimum":0,"maximum":9007199254740991}},"required":["realm","principal","source","resource","requester","requests"]},"name":{"type":"string","maxLength":131072},"source":{"type":"object","additionalProperties":false,"properties":{"capabilities":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"source":{"type":"integer","minimum":0,"maximum":255},"plan":{"type":"integer","minimum":0,"maximum":255},"result":{"type":"integer","minimum":0,"maximum":255},"bundle_bytes":{"type":"integer","minimum":0,"maximum":4294967295},"part_bytes":{"type":"integer","minimum":0,"maximum":65535},"segment_bytes":{"type":"integer","minimum":0,"maximum":4294967295},"batch_rows":{"type":"integer","minimum":0,"maximum":255},"columns":{"type":"integer","minimum":0,"maximum":255},"kv":{"type":"boolean"},"table":{"type":"boolean"},"document":{"type":"boolean"}},"required":["version","source","plan","result","bundle_bytes","part_bytes","segment_bytes","batch_rows","columns","kv","table","document"]},"source":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"source":{"oneOf":[{"type":"object","additionalProperties":false,"required":["kv"],"properties":{"kv":{"type":"object","additionalProperties":false,"properties":{"prefix":{"type":"string","maxLength":131072},"key":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["version","type"]},"value":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["version","type"]}},"required":["prefix","key","value"]}}},{"type":"object","additionalProperties":false,"required":["table"],"properties":{"table":{"type":"object","additionalProperties":false,"properties":{"id":{"type":"integer","minimum":0,"maximum":4294967295},"names":{"type":"array","minItems":2,"maxItems":2,"items":{"type":"string","maxLength":131072}},"value_type":{"type":"string","enum":["int64","boolean","utf8","binary"]}},"required":["id","names","value_type"]}}},{"type":"object","additionalProperties":false,"required":["document"],"properties":{"document":{"type":"object","additionalProperties":false,"properties":{"reference":{"type":"object","additionalProperties":false,"properties":{"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"document":{"type":"string","maxLength":131072},"epoch":{"type":"string","maxLength":131072},"type_revision":{"type":"integer","minimum":0,"maximum":4294967295},"revision":{"type":"string","maxLength":131072}},"required":["resource","document","epoch","type_revision","revision"]},"change_format":{"type":"integer","minimum":0,"maximum":4294967295},"expand":{"anyOf":[{"type":"array","maxItems":8,"items":{"type":"string","maxLength":131072}},{"type":"null"}]},"projections":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"column":{"type":"object","additionalProperties":false,"properties":{"name":{"type":"string","maxLength":131072},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["name","type"]},"path":{"type":"array","maxItems":8,"items":{"type":"string","maxLength":131072}},"relative":{"type":"boolean"},"mode":{"type":"string","enum":["scalar","text","element_counter","element_replica"]},"text_bytes":{"type":"integer","minimum":0,"maximum":65535},"text_steps":{"type":"integer","minimum":0,"maximum":65535}},"required":["column","path","relative","mode","text_bytes","text_steps"]}}},"required":["reference","change_format","expand","projections"]}}}]}},"required":["version","resource","source"]},"resource_revision":{"type":"integer","minimum":0,"maximum":9007199254740991},"policy_revision":{"type":"string","maxLength":131072},"limits":{"type":"object","additionalProperties":false,"properties":{"pages":{"type":"string","maxLength":131072},"segments":{"type":"string","maxLength":131072},"result_bytes":{"type":"string","maxLength":131072}},"required":["pages","segments","result_bytes"]},"active":{"anyOf":[{"type":"string","maxLength":131072},{"type":"null"}]}},"required":["capabilities","source","resource_revision","policy_revision","limits","active"]},"sql":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"statement_bytes":{"type":"integer","minimum":0,"maximum":4294967295},"named_columns":{"type":"integer","minimum":0,"maximum":255},"star_columns":{"type":"integer","minimum":0,"maximum":255},"uint64_limits":{"type":"boolean"},"uint64_literals":{"type":"boolean"},"float64_literals":{"type":"boolean"},"null_comparison":{"type":"boolean"},"explicit_null_test":{"type":"boolean"},"writes":{"type":"boolean"},"continuous":{"type":"boolean"}},"required":["version","statement_bytes","named_columns","star_columns","uint64_limits","uint64_literals","float64_literals","null_comparison","explicit_null_test","writes","continuous"]},"budgets":{"type":"object","additionalProperties":false,"properties":{"pages":{"type":"string","maxLength":131072},"segments":{"type":"string","maxLength":131072},"result_bytes":{"type":"string","maxLength":131072}},"required":["pages","segments","result_bytes"]},"columns":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"name":{"type":"string","maxLength":131072},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["name","type"]}}},"required":["connection","name","source","sql","budgets","columns"]}}},{"type":"object","additionalProperties":false,"required":["compiled"],"properties":{"compiled":{"type":"object","additionalProperties":false,"properties":{"bundle":{"type":"string","maxLength":131072},"source":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"source":{"oneOf":[{"type":"object","additionalProperties":false,"required":["kv"],"properties":{"kv":{"type":"object","additionalProperties":false,"properties":{"prefix":{"type":"string","maxLength":131072},"key":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["version","type"]},"value":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["version","type"]}},"required":["prefix","key","value"]}}},{"type":"object","additionalProperties":false,"required":["table"],"properties":{"table":{"type":"object","additionalProperties":false,"properties":{"id":{"type":"integer","minimum":0,"maximum":4294967295},"names":{"type":"array","minItems":2,"maxItems":2,"items":{"type":"string","maxLength":131072}},"value_type":{"type":"string","enum":["int64","boolean","utf8","binary"]}},"required":["id","names","value_type"]}}},{"type":"object","additionalProperties":false,"required":["document"],"properties":{"document":{"type":"object","additionalProperties":false,"properties":{"reference":{"type":"object","additionalProperties":false,"properties":{"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"document":{"type":"string","maxLength":131072},"epoch":{"type":"string","maxLength":131072},"type_revision":{"type":"integer","minimum":0,"maximum":4294967295},"revision":{"type":"string","maxLength":131072}},"required":["resource","document","epoch","type_revision","revision"]},"change_format":{"type":"integer","minimum":0,"maximum":4294967295},"expand":{"anyOf":[{"type":"array","maxItems":8,"items":{"type":"string","maxLength":131072}},{"type":"null"}]},"projections":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"column":{"type":"object","additionalProperties":false,"properties":{"name":{"type":"string","maxLength":131072},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["name","type"]},"path":{"type":"array","maxItems":8,"items":{"type":"string","maxLength":131072}},"relative":{"type":"boolean"},"mode":{"type":"string","enum":["scalar","text","element_counter","element_replica"]},"text_bytes":{"type":"integer","minimum":0,"maximum":65535},"text_steps":{"type":"integer","minimum":0,"maximum":65535}},"required":["column","path","relative","mode","text_bytes","text_steps"]}}},"required":["reference","change_format","expand","projections"]}}}]}},"required":["version","resource","source"]},"plan":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"projection":{"type":"array","maxItems":8,"items":{"type":"integer","minimum":0,"maximum":4294967295}},"limit":{"anyOf":[{"type":"string","maxLength":131072},{"type":"null"}]},"aggregate":{"type":"string","enum":["rows","count","sum"]},"predicate":{"oneOf":[{"type":"object","additionalProperties":false,"required":["all"],"properties":{"all":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["state"],"properties":{"state":{"type":"object","additionalProperties":false,"properties":{"column":{"type":"integer","minimum":0,"maximum":255},"value":{"type":"string","enum":["missing","null","type_error","value","conflict"]}},"required":["column","value"]}}},{"type":"object","additionalProperties":false,"required":["compare"],"properties":{"compare":{"type":"object","additionalProperties":false,"properties":{"column":{"type":"integer","minimum":0,"maximum":255},"op":{"type":"string","enum":["eq","ne","lt","le","gt","ge"]},"value":{"oneOf":[{"type":"object","additionalProperties":false,"required":["int64"],"properties":{"int64":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["uint64"],"properties":{"uint64":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"type":"boolean"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"type":"string","maxLength":131072}}}]}},"required":["column","op","value"]}}}]}},"required":["version","projection","limit","aggregate","predicate"]},"limits":{"type":"object","additionalProperties":false,"properties":{"pages":{"type":"string","maxLength":131072},"segments":{"type":"string","maxLength":131072},"result_bytes":{"type":"string","maxLength":131072}},"required":["pages","segments","result_bytes"]},"contract":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"schema":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}}},"required":["bundle","source","plan","limits","contract","schema"]}}},{"type":"object","additionalProperties":false,"required":["prepared"],"properties":{"prepared":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"token":{"type":"string","maxLength":131072}},"required":["token"]},{"type":"null"}]}}},{"type":"object","additionalProperties":false,"required":["receipt"],"properties":{"receipt":{"type":"object","additionalProperties":false,"properties":{"position":{"type":"integer","minimum":0,"maximum":9007199254740991}},"required":["position"]}}},{"type":"object","additionalProperties":false,"required":["observation"],"properties":{"observation":{"oneOf":[{"type":"object","additionalProperties":false,"required":["pending"],"properties":{"pending":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["committed"],"properties":{"committed":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["rejected"],"properties":{"rejected":{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512}}}]}}},{"type":"object","additionalProperties":false,"required":["status"],"properties":{"status":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"reference":{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512},"phase":{"type":"string","enum":["uploading","sealed","admitted","complete","cancelled","denied","rejected","retired"]},"correlation":{"type":"string","maxLength":131072},"manifest":{"anyOf":[{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512},{"type":"null"}]},"collected":{"type":"boolean"}},"required":["reference","phase","correlation","manifest","collected"]},{"type":"null"}]}}},{"type":"object","additionalProperties":false,"required":["page"],"properties":{"page":{"type":"object","additionalProperties":false,"properties":{"evidence":{"type":"object","additionalProperties":false,"properties":{"manifest":{"type":"object","additionalProperties":false,"properties":{"job":{"type":"integer","minimum":0,"maximum":9007199254740991},"source":{"type":"object","additionalProperties":false,"properties":{"pid":{"type":"integer","minimum":0,"maximum":9007199254740991},"input":{"type":"integer","minimum":0,"maximum":9007199254740991},"index":{"type":"integer","minimum":0,"maximum":255}},"required":["pid","input","index"]},"requester":{"type":"integer","minimum":0,"maximum":9007199254740991},"correlation":{"type":"string","maxLength":131072},"policy_revision":{"type":"string","maxLength":131072},"request":{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512},"basis":{"type":"object","additionalProperties":false,"properties":{"kind":{"type":"string","enum":["kv","table","document"]},"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"revision":{"type":"integer","minimum":0,"maximum":9007199254740991},"contract":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"schema":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}}},"required":["kind","resource","revision","contract","schema"]},"plan":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"pages":{"type":"string","maxLength":131072},"scanned":{"type":"string","maxLength":131072},"selected":{"type":"string","maxLength":131072},"segments":{"type":"string","maxLength":131072},"rows":{"type":"string","maxLength":131072},"bytes":{"type":"string","maxLength":131072},"sum":{"anyOf":[{"type":"string","maxLength":131072},{"type":"null"}]},"finished":{"anyOf":[{"type":"string","enum":["source_end","limit"]},{"type":"null"}]},"chain":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}}},"required":["job","source","requester","correlation","policy_revision","request","basis","plan","pages","scanned","selected","segments","rows","bytes","sum","finished","chain"]},"columns":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"name":{"type":"string","maxLength":131072},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["name","type"]}},"ordinal":{"type":"string","maxLength":131072},"rows":{"type":"integer","minimum":0,"maximum":255},"ipc":{"type":"string","maxLength":131072},"next":{"anyOf":[{"type":"string","maxLength":131072},{"type":"null"}]}},"required":["manifest","columns","ordinal","rows","ipc","next"]},"cells":{"type":"array","maxItems":8,"items":{"type":"array","maxItems":8,"items":{"oneOf":[{"type":"object","additionalProperties":false,"required":["missing"],"properties":{"missing":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["null"],"properties":{"null":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["type_error"],"properties":{"type_error":{"type":"string","enum":["unknown","int64","uint64","float64","boolean","utf8","binary","null_value","map","list","text","character"]}}},{"type":"object","additionalProperties":false,"required":["value"],"properties":{"value":{"oneOf":[{"type":"object","additionalProperties":false,"required":["int64"],"properties":{"int64":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["uint64"],"properties":{"uint64":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"type":"boolean"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"type":"string","maxLength":131072}}}]}}},{"type":"object","additionalProperties":false,"required":["conflict"],"properties":{"conflict":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"counter":{"type":"string","maxLength":131072},"replica":{"type":"string","maxLength":131072},"value":{"oneOf":[{"type":"object","additionalProperties":false,"required":["null"],"properties":{"null":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["type_error"],"properties":{"type_error":{"type":"string","enum":["unknown","int64","uint64","float64","boolean","utf8","binary","null_value","map","list","text","character"]}}},{"type":"object","additionalProperties":false,"required":["value"],"properties":{"value":{"oneOf":[{"type":"object","additionalProperties":false,"required":["int64"],"properties":{"int64":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["uint64"],"properties":{"uint64":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"type":"boolean"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"type":"string","maxLength":131072}}}]}}}]}},"required":["counter","replica","value"]}}}}]}}}},"required":["evidence","cells"]}}},{"type":"object","additionalProperties":false,"required":["draft"],"properties":{"draft":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"generation":{"type":"string","maxLength":131072},"limit":{"type":"integer","minimum":0,"maximum":255},"starts":{"type":"integer","minimum":0,"maximum":255},"enabled":{"type":"boolean"},"contract":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"budgets":{"type":"object","additionalProperties":false,"properties":{"pages":{"type":"string","maxLength":131072},"segments":{"type":"string","maxLength":131072},"result_bytes":{"type":"string","maxLength":131072}},"required":["pages","segments","result_bytes"]},"namespaces":{"type":"array","minItems":8,"maxItems":8,"items":{"type":"string","maxLength":131072}}},"required":["generation","limit","starts","enabled","contract","budgets","namespaces"]},{"type":"null"}]}}}]};
const func16 = Object.prototype.hasOwnProperty;
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
if(!(func16.call(schema33.oneOf[0].properties.description.properties.source.properties.capabilities.properties, key4))){
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
if(!(func16.call(schema33.oneOf[0].properties.description.properties.sql.properties, key18))){
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
if((data.compiled === undefined) && (missing21 = "compiled")){
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
if(!(key21 === "compiled")){
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
if(data.compiled !== undefined){
let data88 = data.compiled;
const _errs217 = errors;
if(errors === _errs217){
if(data88 && typeof data88 == "object" && !Array.isArray(data88)){
let missing22;
if(((((((data88.bundle === undefined) && (missing22 = "bundle")) || ((data88.source === undefined) && (missing22 = "source"))) || ((data88.plan === undefined) && (missing22 = "plan"))) || ((data88.limits === undefined) && (missing22 = "limits"))) || ((data88.contract === undefined) && (missing22 = "contract"))) || ((data88.schema === undefined) && (missing22 = "schema"))){
const err230 = {instancePath:instancePath+"/compiled",schemaPath:"#/oneOf/1/properties/compiled/required",keyword:"required",params:{missingProperty: missing22},message:"must have required property '"+missing22+"'"};
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
if(!((((((key22 === "bundle") || (key22 === "source")) || (key22 === "plan")) || (key22 === "limits")) || (key22 === "contract")) || (key22 === "schema"))){
const err231 = {instancePath:instancePath+"/compiled",schemaPath:"#/oneOf/1/properties/compiled/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key22},message:"must NOT have additional properties"};
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
if(data88.bundle !== undefined){
let data89 = data88.bundle;
const _errs220 = errors;
if(errors === _errs220){
if(typeof data89 === "string"){
if(func1(data89) > 131072){
const err232 = {instancePath:instancePath+"/compiled/bundle",schemaPath:"#/oneOf/1/properties/compiled/properties/bundle/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err233 = {instancePath:instancePath+"/compiled/bundle",schemaPath:"#/oneOf/1/properties/compiled/properties/bundle/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err233];
}
else {
vErrors.push(err233);
}
errors++;
}
}
var valid31 = _errs220 === errors;
}
else {
var valid31 = true;
}
if(valid31){
if(data88.source !== undefined){
let data90 = data88.source;
const _errs222 = errors;
if(errors === _errs222){
if(data90 && typeof data90 == "object" && !Array.isArray(data90)){
let missing23;
if((((data90.version === undefined) && (missing23 = "version")) || ((data90.resource === undefined) && (missing23 = "resource"))) || ((data90.source === undefined) && (missing23 = "source"))){
const err234 = {instancePath:instancePath+"/compiled/source",schemaPath:"#/oneOf/1/properties/compiled/properties/source/required",keyword:"required",params:{missingProperty: missing23},message:"must have required property '"+missing23+"'"};
if(vErrors === null){
vErrors = [err234];
}
else {
vErrors.push(err234);
}
errors++;
}
else {
const _errs224 = errors;
for(const key23 in data90){
if(!(((key23 === "version") || (key23 === "resource")) || (key23 === "source"))){
const err235 = {instancePath:instancePath+"/compiled/source",schemaPath:"#/oneOf/1/properties/compiled/properties/source/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key23},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err235];
}
else {
vErrors.push(err235);
}
errors++;
break;
}
}
if(_errs224 === errors){
if(data90.version !== undefined){
let data91 = data90.version;
const _errs225 = errors;
if(!(((typeof data91 == "number") && (!(data91 % 1) && !isNaN(data91))) && (isFinite(data91)))){
const err236 = {instancePath:instancePath+"/compiled/source/version",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err236];
}
else {
vErrors.push(err236);
}
errors++;
}
if(errors === _errs225){
if((typeof data91 == "number") && (isFinite(data91))){
if(data91 > 255 || isNaN(data91)){
const err237 = {instancePath:instancePath+"/compiled/source/version",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/version/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
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
const err238 = {instancePath:instancePath+"/compiled/source/version",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/version/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid32 = _errs225 === errors;
}
else {
var valid32 = true;
}
if(valid32){
if(data90.resource !== undefined){
let data92 = data90.resource;
const _errs227 = errors;
if(!(((typeof data92 == "number") && (!(data92 % 1) && !isNaN(data92))) && (isFinite(data92)))){
const err239 = {instancePath:instancePath+"/compiled/source/resource",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/resource/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err239];
}
else {
vErrors.push(err239);
}
errors++;
}
if(errors === _errs227){
if((typeof data92 == "number") && (isFinite(data92))){
if(data92 > 9007199254740991 || isNaN(data92)){
const err240 = {instancePath:instancePath+"/compiled/source/resource",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/resource/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
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
const err241 = {instancePath:instancePath+"/compiled/source/resource",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/resource/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid32 = _errs227 === errors;
}
else {
var valid32 = true;
}
if(valid32){
if(data90.source !== undefined){
let data93 = data90.source;
const _errs229 = errors;
const _errs230 = errors;
let valid33 = false;
let passing2 = null;
const _errs231 = errors;
if(errors === _errs231){
if(data93 && typeof data93 == "object" && !Array.isArray(data93)){
let missing24;
if((data93.kv === undefined) && (missing24 = "kv")){
const err242 = {instancePath:instancePath+"/compiled/source/source",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/0/required",keyword:"required",params:{missingProperty: missing24},message:"must have required property '"+missing24+"'"};
if(vErrors === null){
vErrors = [err242];
}
else {
vErrors.push(err242);
}
errors++;
}
else {
const _errs233 = errors;
for(const key24 in data93){
if(!(key24 === "kv")){
const err243 = {instancePath:instancePath+"/compiled/source/source",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key24},message:"must NOT have additional properties"};
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
if(_errs233 === errors){
if(data93.kv !== undefined){
let data94 = data93.kv;
const _errs234 = errors;
if(errors === _errs234){
if(data94 && typeof data94 == "object" && !Array.isArray(data94)){
let missing25;
if((((data94.prefix === undefined) && (missing25 = "prefix")) || ((data94.key === undefined) && (missing25 = "key"))) || ((data94.value === undefined) && (missing25 = "value"))){
const err244 = {instancePath:instancePath+"/compiled/source/source/kv",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/required",keyword:"required",params:{missingProperty: missing25},message:"must have required property '"+missing25+"'"};
if(vErrors === null){
vErrors = [err244];
}
else {
vErrors.push(err244);
}
errors++;
}
else {
const _errs236 = errors;
for(const key25 in data94){
if(!(((key25 === "prefix") || (key25 === "key")) || (key25 === "value"))){
const err245 = {instancePath:instancePath+"/compiled/source/source/kv",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key25},message:"must NOT have additional properties"};
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
if(_errs236 === errors){
if(data94.prefix !== undefined){
let data95 = data94.prefix;
const _errs237 = errors;
if(errors === _errs237){
if(typeof data95 === "string"){
if(func1(data95) > 131072){
const err246 = {instancePath:instancePath+"/compiled/source/source/kv/prefix",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/prefix/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err247 = {instancePath:instancePath+"/compiled/source/source/kv/prefix",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/prefix/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err247];
}
else {
vErrors.push(err247);
}
errors++;
}
}
var valid35 = _errs237 === errors;
}
else {
var valid35 = true;
}
if(valid35){
if(data94.key !== undefined){
let data96 = data94.key;
const _errs239 = errors;
if(errors === _errs239){
if(data96 && typeof data96 == "object" && !Array.isArray(data96)){
let missing26;
if(((data96.version === undefined) && (missing26 = "version")) || ((data96.type === undefined) && (missing26 = "type"))){
const err248 = {instancePath:instancePath+"/compiled/source/source/kv/key",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/key/required",keyword:"required",params:{missingProperty: missing26},message:"must have required property '"+missing26+"'"};
if(vErrors === null){
vErrors = [err248];
}
else {
vErrors.push(err248);
}
errors++;
}
else {
const _errs241 = errors;
for(const key26 in data96){
if(!((key26 === "version") || (key26 === "type"))){
const err249 = {instancePath:instancePath+"/compiled/source/source/kv/key",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/key/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key26},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err249];
}
else {
vErrors.push(err249);
}
errors++;
break;
}
}
if(_errs241 === errors){
if(data96.version !== undefined){
let data97 = data96.version;
const _errs242 = errors;
if(!(((typeof data97 == "number") && (!(data97 % 1) && !isNaN(data97))) && (isFinite(data97)))){
const err250 = {instancePath:instancePath+"/compiled/source/source/kv/key/version",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/key/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err250];
}
else {
vErrors.push(err250);
}
errors++;
}
if(errors === _errs242){
if((typeof data97 == "number") && (isFinite(data97))){
if(data97 > 255 || isNaN(data97)){
const err251 = {instancePath:instancePath+"/compiled/source/source/kv/key/version",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/key/properties/version/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err251];
}
else {
vErrors.push(err251);
}
errors++;
}
else {
if(data97 < 0 || isNaN(data97)){
const err252 = {instancePath:instancePath+"/compiled/source/source/kv/key/version",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/key/properties/version/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err252];
}
else {
vErrors.push(err252);
}
errors++;
}
}
}
}
var valid36 = _errs242 === errors;
}
else {
var valid36 = true;
}
if(valid36){
if(data96.type !== undefined){
let data98 = data96.type;
const _errs244 = errors;
if(typeof data98 !== "string"){
const err253 = {instancePath:instancePath+"/compiled/source/source/kv/key/type",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/key/properties/type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err253];
}
else {
vErrors.push(err253);
}
errors++;
}
if(!((((((data98 === "int64") || (data98 === "uint64")) || (data98 === "float64")) || (data98 === "boolean")) || (data98 === "utf8")) || (data98 === "binary"))){
const err254 = {instancePath:instancePath+"/compiled/source/source/kv/key/type",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/key/properties/type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[1].properties.compiled.properties.source.properties.source.oneOf[0].properties.kv.properties.key.properties.type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err254];
}
else {
vErrors.push(err254);
}
errors++;
}
var valid36 = _errs244 === errors;
}
else {
var valid36 = true;
}
}
}
}
}
else {
const err255 = {instancePath:instancePath+"/compiled/source/source/kv/key",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/key/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err255];
}
else {
vErrors.push(err255);
}
errors++;
}
}
var valid35 = _errs239 === errors;
}
else {
var valid35 = true;
}
if(valid35){
if(data94.value !== undefined){
let data99 = data94.value;
const _errs246 = errors;
if(errors === _errs246){
if(data99 && typeof data99 == "object" && !Array.isArray(data99)){
let missing27;
if(((data99.version === undefined) && (missing27 = "version")) || ((data99.type === undefined) && (missing27 = "type"))){
const err256 = {instancePath:instancePath+"/compiled/source/source/kv/value",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/value/required",keyword:"required",params:{missingProperty: missing27},message:"must have required property '"+missing27+"'"};
if(vErrors === null){
vErrors = [err256];
}
else {
vErrors.push(err256);
}
errors++;
}
else {
const _errs248 = errors;
for(const key27 in data99){
if(!((key27 === "version") || (key27 === "type"))){
const err257 = {instancePath:instancePath+"/compiled/source/source/kv/value",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/value/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key27},message:"must NOT have additional properties"};
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
if(_errs248 === errors){
if(data99.version !== undefined){
let data100 = data99.version;
const _errs249 = errors;
if(!(((typeof data100 == "number") && (!(data100 % 1) && !isNaN(data100))) && (isFinite(data100)))){
const err258 = {instancePath:instancePath+"/compiled/source/source/kv/value/version",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/value/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err258];
}
else {
vErrors.push(err258);
}
errors++;
}
if(errors === _errs249){
if((typeof data100 == "number") && (isFinite(data100))){
if(data100 > 255 || isNaN(data100)){
const err259 = {instancePath:instancePath+"/compiled/source/source/kv/value/version",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/value/properties/version/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err259];
}
else {
vErrors.push(err259);
}
errors++;
}
else {
if(data100 < 0 || isNaN(data100)){
const err260 = {instancePath:instancePath+"/compiled/source/source/kv/value/version",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/value/properties/version/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err260];
}
else {
vErrors.push(err260);
}
errors++;
}
}
}
}
var valid37 = _errs249 === errors;
}
else {
var valid37 = true;
}
if(valid37){
if(data99.type !== undefined){
let data101 = data99.type;
const _errs251 = errors;
if(typeof data101 !== "string"){
const err261 = {instancePath:instancePath+"/compiled/source/source/kv/value/type",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/value/properties/type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err261];
}
else {
vErrors.push(err261);
}
errors++;
}
if(!((((((data101 === "int64") || (data101 === "uint64")) || (data101 === "float64")) || (data101 === "boolean")) || (data101 === "utf8")) || (data101 === "binary"))){
const err262 = {instancePath:instancePath+"/compiled/source/source/kv/value/type",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/value/properties/type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[1].properties.compiled.properties.source.properties.source.oneOf[0].properties.kv.properties.value.properties.type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err262];
}
else {
vErrors.push(err262);
}
errors++;
}
var valid37 = _errs251 === errors;
}
else {
var valid37 = true;
}
}
}
}
}
else {
const err263 = {instancePath:instancePath+"/compiled/source/source/kv/value",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/value/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err263];
}
else {
vErrors.push(err263);
}
errors++;
}
}
var valid35 = _errs246 === errors;
}
else {
var valid35 = true;
}
}
}
}
}
}
else {
const err264 = {instancePath:instancePath+"/compiled/source/source/kv",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err264];
}
else {
vErrors.push(err264);
}
errors++;
}
}
}
}
}
}
else {
const err265 = {instancePath:instancePath+"/compiled/source/source",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err265];
}
else {
vErrors.push(err265);
}
errors++;
}
}
var _valid4 = _errs231 === errors;
if(_valid4){
valid33 = true;
passing2 = 0;
var props2 = true;
}
const _errs253 = errors;
if(errors === _errs253){
if(data93 && typeof data93 == "object" && !Array.isArray(data93)){
let missing28;
if((data93.table === undefined) && (missing28 = "table")){
const err266 = {instancePath:instancePath+"/compiled/source/source",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/1/required",keyword:"required",params:{missingProperty: missing28},message:"must have required property '"+missing28+"'"};
if(vErrors === null){
vErrors = [err266];
}
else {
vErrors.push(err266);
}
errors++;
}
else {
const _errs255 = errors;
for(const key28 in data93){
if(!(key28 === "table")){
const err267 = {instancePath:instancePath+"/compiled/source/source",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key28},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err267];
}
else {
vErrors.push(err267);
}
errors++;
break;
}
}
if(_errs255 === errors){
if(data93.table !== undefined){
let data102 = data93.table;
const _errs256 = errors;
if(errors === _errs256){
if(data102 && typeof data102 == "object" && !Array.isArray(data102)){
let missing29;
if((((data102.id === undefined) && (missing29 = "id")) || ((data102.names === undefined) && (missing29 = "names"))) || ((data102.value_type === undefined) && (missing29 = "value_type"))){
const err268 = {instancePath:instancePath+"/compiled/source/source/table",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/required",keyword:"required",params:{missingProperty: missing29},message:"must have required property '"+missing29+"'"};
if(vErrors === null){
vErrors = [err268];
}
else {
vErrors.push(err268);
}
errors++;
}
else {
const _errs258 = errors;
for(const key29 in data102){
if(!(((key29 === "id") || (key29 === "names")) || (key29 === "value_type"))){
const err269 = {instancePath:instancePath+"/compiled/source/source/table",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key29},message:"must NOT have additional properties"};
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
if(_errs258 === errors){
if(data102.id !== undefined){
let data103 = data102.id;
const _errs259 = errors;
if(!(((typeof data103 == "number") && (!(data103 % 1) && !isNaN(data103))) && (isFinite(data103)))){
const err270 = {instancePath:instancePath+"/compiled/source/source/table/id",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/properties/id/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err270];
}
else {
vErrors.push(err270);
}
errors++;
}
if(errors === _errs259){
if((typeof data103 == "number") && (isFinite(data103))){
if(data103 > 4294967295 || isNaN(data103)){
const err271 = {instancePath:instancePath+"/compiled/source/source/table/id",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/properties/id/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err271];
}
else {
vErrors.push(err271);
}
errors++;
}
else {
if(data103 < 0 || isNaN(data103)){
const err272 = {instancePath:instancePath+"/compiled/source/source/table/id",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/properties/id/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid39 = _errs259 === errors;
}
else {
var valid39 = true;
}
if(valid39){
if(data102.names !== undefined){
let data104 = data102.names;
const _errs261 = errors;
if(errors === _errs261){
if(Array.isArray(data104)){
if(data104.length > 2){
const err273 = {instancePath:instancePath+"/compiled/source/source/table/names",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/properties/names/maxItems",keyword:"maxItems",params:{limit: 2},message:"must NOT have more than 2 items"};
if(vErrors === null){
vErrors = [err273];
}
else {
vErrors.push(err273);
}
errors++;
}
else {
if(data104.length < 2){
const err274 = {instancePath:instancePath+"/compiled/source/source/table/names",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/properties/names/minItems",keyword:"minItems",params:{limit: 2},message:"must NOT have fewer than 2 items"};
if(vErrors === null){
vErrors = [err274];
}
else {
vErrors.push(err274);
}
errors++;
}
else {
var valid40 = true;
const len5 = data104.length;
for(let i5=0; i5<len5; i5++){
let data105 = data104[i5];
const _errs263 = errors;
if(errors === _errs263){
if(typeof data105 === "string"){
if(func1(data105) > 131072){
const err275 = {instancePath:instancePath+"/compiled/source/source/table/names/" + i5,schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/properties/names/items/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err275];
}
else {
vErrors.push(err275);
}
errors++;
}
}
else {
const err276 = {instancePath:instancePath+"/compiled/source/source/table/names/" + i5,schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/properties/names/items/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err276];
}
else {
vErrors.push(err276);
}
errors++;
}
}
var valid40 = _errs263 === errors;
if(!valid40){
break;
}
}
}
}
}
else {
const err277 = {instancePath:instancePath+"/compiled/source/source/table/names",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/properties/names/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err277];
}
else {
vErrors.push(err277);
}
errors++;
}
}
var valid39 = _errs261 === errors;
}
else {
var valid39 = true;
}
if(valid39){
if(data102.value_type !== undefined){
let data106 = data102.value_type;
const _errs265 = errors;
if(typeof data106 !== "string"){
const err278 = {instancePath:instancePath+"/compiled/source/source/table/value_type",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/properties/value_type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err278];
}
else {
vErrors.push(err278);
}
errors++;
}
if(!((((data106 === "int64") || (data106 === "boolean")) || (data106 === "utf8")) || (data106 === "binary"))){
const err279 = {instancePath:instancePath+"/compiled/source/source/table/value_type",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/properties/value_type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[1].properties.compiled.properties.source.properties.source.oneOf[1].properties.table.properties.value_type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err279];
}
else {
vErrors.push(err279);
}
errors++;
}
var valid39 = _errs265 === errors;
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
const err280 = {instancePath:instancePath+"/compiled/source/source/table",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err280];
}
else {
vErrors.push(err280);
}
errors++;
}
}
}
}
}
}
else {
const err281 = {instancePath:instancePath+"/compiled/source/source",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err281];
}
else {
vErrors.push(err281);
}
errors++;
}
}
var _valid4 = _errs253 === errors;
if(_valid4 && valid33){
valid33 = false;
passing2 = [passing2, 1];
}
else {
if(_valid4){
valid33 = true;
passing2 = 1;
if(props2 !== true){
props2 = true;
}
}
const _errs267 = errors;
if(errors === _errs267){
if(data93 && typeof data93 == "object" && !Array.isArray(data93)){
let missing30;
if((data93.document === undefined) && (missing30 = "document")){
const err282 = {instancePath:instancePath+"/compiled/source/source",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/required",keyword:"required",params:{missingProperty: missing30},message:"must have required property '"+missing30+"'"};
if(vErrors === null){
vErrors = [err282];
}
else {
vErrors.push(err282);
}
errors++;
}
else {
const _errs269 = errors;
for(const key30 in data93){
if(!(key30 === "document")){
const err283 = {instancePath:instancePath+"/compiled/source/source",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key30},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err283];
}
else {
vErrors.push(err283);
}
errors++;
break;
}
}
if(_errs269 === errors){
if(data93.document !== undefined){
let data107 = data93.document;
const _errs270 = errors;
if(errors === _errs270){
if(data107 && typeof data107 == "object" && !Array.isArray(data107)){
let missing31;
if(((((data107.reference === undefined) && (missing31 = "reference")) || ((data107.change_format === undefined) && (missing31 = "change_format"))) || ((data107.expand === undefined) && (missing31 = "expand"))) || ((data107.projections === undefined) && (missing31 = "projections"))){
const err284 = {instancePath:instancePath+"/compiled/source/source/document",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/required",keyword:"required",params:{missingProperty: missing31},message:"must have required property '"+missing31+"'"};
if(vErrors === null){
vErrors = [err284];
}
else {
vErrors.push(err284);
}
errors++;
}
else {
const _errs272 = errors;
for(const key31 in data107){
if(!((((key31 === "reference") || (key31 === "change_format")) || (key31 === "expand")) || (key31 === "projections"))){
const err285 = {instancePath:instancePath+"/compiled/source/source/document",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key31},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err285];
}
else {
vErrors.push(err285);
}
errors++;
break;
}
}
if(_errs272 === errors){
if(data107.reference !== undefined){
let data108 = data107.reference;
const _errs273 = errors;
if(errors === _errs273){
if(data108 && typeof data108 == "object" && !Array.isArray(data108)){
let missing32;
if((((((data108.resource === undefined) && (missing32 = "resource")) || ((data108.document === undefined) && (missing32 = "document"))) || ((data108.epoch === undefined) && (missing32 = "epoch"))) || ((data108.type_revision === undefined) && (missing32 = "type_revision"))) || ((data108.revision === undefined) && (missing32 = "revision"))){
const err286 = {instancePath:instancePath+"/compiled/source/source/document/reference",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/required",keyword:"required",params:{missingProperty: missing32},message:"must have required property '"+missing32+"'"};
if(vErrors === null){
vErrors = [err286];
}
else {
vErrors.push(err286);
}
errors++;
}
else {
const _errs275 = errors;
for(const key32 in data108){
if(!(((((key32 === "resource") || (key32 === "document")) || (key32 === "epoch")) || (key32 === "type_revision")) || (key32 === "revision"))){
const err287 = {instancePath:instancePath+"/compiled/source/source/document/reference",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key32},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err287];
}
else {
vErrors.push(err287);
}
errors++;
break;
}
}
if(_errs275 === errors){
if(data108.resource !== undefined){
let data109 = data108.resource;
const _errs276 = errors;
if(!(((typeof data109 == "number") && (!(data109 % 1) && !isNaN(data109))) && (isFinite(data109)))){
const err288 = {instancePath:instancePath+"/compiled/source/source/document/reference/resource",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/resource/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err288];
}
else {
vErrors.push(err288);
}
errors++;
}
if(errors === _errs276){
if((typeof data109 == "number") && (isFinite(data109))){
if(data109 > 9007199254740991 || isNaN(data109)){
const err289 = {instancePath:instancePath+"/compiled/source/source/document/reference/resource",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/resource/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err289];
}
else {
vErrors.push(err289);
}
errors++;
}
else {
if(data109 < 0 || isNaN(data109)){
const err290 = {instancePath:instancePath+"/compiled/source/source/document/reference/resource",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/resource/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err290];
}
else {
vErrors.push(err290);
}
errors++;
}
}
}
}
var valid43 = _errs276 === errors;
}
else {
var valid43 = true;
}
if(valid43){
if(data108.document !== undefined){
let data110 = data108.document;
const _errs278 = errors;
if(errors === _errs278){
if(typeof data110 === "string"){
if(func1(data110) > 131072){
const err291 = {instancePath:instancePath+"/compiled/source/source/document/reference/document",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/document/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err291];
}
else {
vErrors.push(err291);
}
errors++;
}
}
else {
const err292 = {instancePath:instancePath+"/compiled/source/source/document/reference/document",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/document/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err292];
}
else {
vErrors.push(err292);
}
errors++;
}
}
var valid43 = _errs278 === errors;
}
else {
var valid43 = true;
}
if(valid43){
if(data108.epoch !== undefined){
let data111 = data108.epoch;
const _errs280 = errors;
if(errors === _errs280){
if(typeof data111 === "string"){
if(func1(data111) > 131072){
const err293 = {instancePath:instancePath+"/compiled/source/source/document/reference/epoch",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/epoch/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err294 = {instancePath:instancePath+"/compiled/source/source/document/reference/epoch",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/epoch/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err294];
}
else {
vErrors.push(err294);
}
errors++;
}
}
var valid43 = _errs280 === errors;
}
else {
var valid43 = true;
}
if(valid43){
if(data108.type_revision !== undefined){
let data112 = data108.type_revision;
const _errs282 = errors;
if(!(((typeof data112 == "number") && (!(data112 % 1) && !isNaN(data112))) && (isFinite(data112)))){
const err295 = {instancePath:instancePath+"/compiled/source/source/document/reference/type_revision",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/type_revision/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err295];
}
else {
vErrors.push(err295);
}
errors++;
}
if(errors === _errs282){
if((typeof data112 == "number") && (isFinite(data112))){
if(data112 > 4294967295 || isNaN(data112)){
const err296 = {instancePath:instancePath+"/compiled/source/source/document/reference/type_revision",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/type_revision/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err296];
}
else {
vErrors.push(err296);
}
errors++;
}
else {
if(data112 < 0 || isNaN(data112)){
const err297 = {instancePath:instancePath+"/compiled/source/source/document/reference/type_revision",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/type_revision/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err297];
}
else {
vErrors.push(err297);
}
errors++;
}
}
}
}
var valid43 = _errs282 === errors;
}
else {
var valid43 = true;
}
if(valid43){
if(data108.revision !== undefined){
let data113 = data108.revision;
const _errs284 = errors;
if(errors === _errs284){
if(typeof data113 === "string"){
if(func1(data113) > 131072){
const err298 = {instancePath:instancePath+"/compiled/source/source/document/reference/revision",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/revision/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err298];
}
else {
vErrors.push(err298);
}
errors++;
}
}
else {
const err299 = {instancePath:instancePath+"/compiled/source/source/document/reference/revision",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err299];
}
else {
vErrors.push(err299);
}
errors++;
}
}
var valid43 = _errs284 === errors;
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
else {
const err300 = {instancePath:instancePath+"/compiled/source/source/document/reference",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err300];
}
else {
vErrors.push(err300);
}
errors++;
}
}
var valid42 = _errs273 === errors;
}
else {
var valid42 = true;
}
if(valid42){
if(data107.change_format !== undefined){
let data114 = data107.change_format;
const _errs286 = errors;
if(!(((typeof data114 == "number") && (!(data114 % 1) && !isNaN(data114))) && (isFinite(data114)))){
const err301 = {instancePath:instancePath+"/compiled/source/source/document/change_format",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/change_format/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err301];
}
else {
vErrors.push(err301);
}
errors++;
}
if(errors === _errs286){
if((typeof data114 == "number") && (isFinite(data114))){
if(data114 > 4294967295 || isNaN(data114)){
const err302 = {instancePath:instancePath+"/compiled/source/source/document/change_format",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/change_format/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err302];
}
else {
vErrors.push(err302);
}
errors++;
}
else {
if(data114 < 0 || isNaN(data114)){
const err303 = {instancePath:instancePath+"/compiled/source/source/document/change_format",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/change_format/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err303];
}
else {
vErrors.push(err303);
}
errors++;
}
}
}
}
var valid42 = _errs286 === errors;
}
else {
var valid42 = true;
}
if(valid42){
if(data107.expand !== undefined){
let data115 = data107.expand;
const _errs288 = errors;
const _errs289 = errors;
let valid44 = false;
const _errs290 = errors;
if(errors === _errs290){
if(Array.isArray(data115)){
if(data115.length > 8){
const err304 = {instancePath:instancePath+"/compiled/source/source/document/expand",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/expand/anyOf/0/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err304];
}
else {
vErrors.push(err304);
}
errors++;
}
else {
var valid45 = true;
const len6 = data115.length;
for(let i6=0; i6<len6; i6++){
let data116 = data115[i6];
const _errs292 = errors;
if(errors === _errs292){
if(typeof data116 === "string"){
if(func1(data116) > 131072){
const err305 = {instancePath:instancePath+"/compiled/source/source/document/expand/" + i6,schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/expand/anyOf/0/items/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err305];
}
else {
vErrors.push(err305);
}
errors++;
}
}
else {
const err306 = {instancePath:instancePath+"/compiled/source/source/document/expand/" + i6,schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/expand/anyOf/0/items/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err306];
}
else {
vErrors.push(err306);
}
errors++;
}
}
var valid45 = _errs292 === errors;
if(!valid45){
break;
}
}
}
}
else {
const err307 = {instancePath:instancePath+"/compiled/source/source/document/expand",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/expand/anyOf/0/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err307];
}
else {
vErrors.push(err307);
}
errors++;
}
}
var _valid5 = _errs290 === errors;
valid44 = valid44 || _valid5;
const _errs294 = errors;
if(data115 !== null){
const err308 = {instancePath:instancePath+"/compiled/source/source/document/expand",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/expand/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err308];
}
else {
vErrors.push(err308);
}
errors++;
}
var _valid5 = _errs294 === errors;
valid44 = valid44 || _valid5;
if(!valid44){
const err309 = {instancePath:instancePath+"/compiled/source/source/document/expand",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/expand/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err309];
}
else {
vErrors.push(err309);
}
errors++;
}
else {
errors = _errs289;
if(vErrors !== null){
if(_errs289){
vErrors.length = _errs289;
}
else {
vErrors = null;
}
}
}
var valid42 = _errs288 === errors;
}
else {
var valid42 = true;
}
if(valid42){
if(data107.projections !== undefined){
let data117 = data107.projections;
const _errs296 = errors;
if(errors === _errs296){
if(Array.isArray(data117)){
if(data117.length > 8){
const err310 = {instancePath:instancePath+"/compiled/source/source/document/projections",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err310];
}
else {
vErrors.push(err310);
}
errors++;
}
else {
var valid46 = true;
const len7 = data117.length;
for(let i7=0; i7<len7; i7++){
let data118 = data117[i7];
const _errs298 = errors;
if(errors === _errs298){
if(data118 && typeof data118 == "object" && !Array.isArray(data118)){
let missing33;
if(((((((data118.column === undefined) && (missing33 = "column")) || ((data118.path === undefined) && (missing33 = "path"))) || ((data118.relative === undefined) && (missing33 = "relative"))) || ((data118.mode === undefined) && (missing33 = "mode"))) || ((data118.text_bytes === undefined) && (missing33 = "text_bytes"))) || ((data118.text_steps === undefined) && (missing33 = "text_steps"))){
const err311 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i7,schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/required",keyword:"required",params:{missingProperty: missing33},message:"must have required property '"+missing33+"'"};
if(vErrors === null){
vErrors = [err311];
}
else {
vErrors.push(err311);
}
errors++;
}
else {
const _errs300 = errors;
for(const key33 in data118){
if(!((((((key33 === "column") || (key33 === "path")) || (key33 === "relative")) || (key33 === "mode")) || (key33 === "text_bytes")) || (key33 === "text_steps"))){
const err312 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i7,schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key33},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err312];
}
else {
vErrors.push(err312);
}
errors++;
break;
}
}
if(_errs300 === errors){
if(data118.column !== undefined){
let data119 = data118.column;
const _errs301 = errors;
if(errors === _errs301){
if(data119 && typeof data119 == "object" && !Array.isArray(data119)){
let missing34;
if(((data119.name === undefined) && (missing34 = "name")) || ((data119.type === undefined) && (missing34 = "type"))){
const err313 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i7+"/column",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/column/required",keyword:"required",params:{missingProperty: missing34},message:"must have required property '"+missing34+"'"};
if(vErrors === null){
vErrors = [err313];
}
else {
vErrors.push(err313);
}
errors++;
}
else {
const _errs303 = errors;
for(const key34 in data119){
if(!((key34 === "name") || (key34 === "type"))){
const err314 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i7+"/column",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/column/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key34},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err314];
}
else {
vErrors.push(err314);
}
errors++;
break;
}
}
if(_errs303 === errors){
if(data119.name !== undefined){
let data120 = data119.name;
const _errs304 = errors;
if(errors === _errs304){
if(typeof data120 === "string"){
if(func1(data120) > 131072){
const err315 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i7+"/column/name",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/column/properties/name/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err315];
}
else {
vErrors.push(err315);
}
errors++;
}
}
else {
const err316 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i7+"/column/name",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/column/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err316];
}
else {
vErrors.push(err316);
}
errors++;
}
}
var valid48 = _errs304 === errors;
}
else {
var valid48 = true;
}
if(valid48){
if(data119.type !== undefined){
let data121 = data119.type;
const _errs306 = errors;
if(typeof data121 !== "string"){
const err317 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i7+"/column/type",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/column/properties/type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err317];
}
else {
vErrors.push(err317);
}
errors++;
}
if(!((((((data121 === "int64") || (data121 === "uint64")) || (data121 === "float64")) || (data121 === "boolean")) || (data121 === "utf8")) || (data121 === "binary"))){
const err318 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i7+"/column/type",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/column/properties/type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[1].properties.compiled.properties.source.properties.source.oneOf[2].properties.document.properties.projections.items.properties.column.properties.type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err318];
}
else {
vErrors.push(err318);
}
errors++;
}
var valid48 = _errs306 === errors;
}
else {
var valid48 = true;
}
}
}
}
}
else {
const err319 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i7+"/column",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/column/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err319];
}
else {
vErrors.push(err319);
}
errors++;
}
}
var valid47 = _errs301 === errors;
}
else {
var valid47 = true;
}
if(valid47){
if(data118.path !== undefined){
let data122 = data118.path;
const _errs308 = errors;
if(errors === _errs308){
if(Array.isArray(data122)){
if(data122.length > 8){
const err320 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i7+"/path",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/path/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err320];
}
else {
vErrors.push(err320);
}
errors++;
}
else {
var valid49 = true;
const len8 = data122.length;
for(let i8=0; i8<len8; i8++){
let data123 = data122[i8];
const _errs310 = errors;
if(errors === _errs310){
if(typeof data123 === "string"){
if(func1(data123) > 131072){
const err321 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i7+"/path/" + i8,schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/path/items/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err322 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i7+"/path/" + i8,schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/path/items/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err322];
}
else {
vErrors.push(err322);
}
errors++;
}
}
var valid49 = _errs310 === errors;
if(!valid49){
break;
}
}
}
}
else {
const err323 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i7+"/path",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/path/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err323];
}
else {
vErrors.push(err323);
}
errors++;
}
}
var valid47 = _errs308 === errors;
}
else {
var valid47 = true;
}
if(valid47){
if(data118.relative !== undefined){
const _errs312 = errors;
if(typeof data118.relative !== "boolean"){
const err324 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i7+"/relative",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/relative/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err324];
}
else {
vErrors.push(err324);
}
errors++;
}
var valid47 = _errs312 === errors;
}
else {
var valid47 = true;
}
if(valid47){
if(data118.mode !== undefined){
let data125 = data118.mode;
const _errs314 = errors;
if(typeof data125 !== "string"){
const err325 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i7+"/mode",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/mode/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err325];
}
else {
vErrors.push(err325);
}
errors++;
}
if(!((((data125 === "scalar") || (data125 === "text")) || (data125 === "element_counter")) || (data125 === "element_replica"))){
const err326 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i7+"/mode",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/mode/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[1].properties.compiled.properties.source.properties.source.oneOf[2].properties.document.properties.projections.items.properties.mode.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err326];
}
else {
vErrors.push(err326);
}
errors++;
}
var valid47 = _errs314 === errors;
}
else {
var valid47 = true;
}
if(valid47){
if(data118.text_bytes !== undefined){
let data126 = data118.text_bytes;
const _errs316 = errors;
if(!(((typeof data126 == "number") && (!(data126 % 1) && !isNaN(data126))) && (isFinite(data126)))){
const err327 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i7+"/text_bytes",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/text_bytes/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err327];
}
else {
vErrors.push(err327);
}
errors++;
}
if(errors === _errs316){
if((typeof data126 == "number") && (isFinite(data126))){
if(data126 > 65535 || isNaN(data126)){
const err328 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i7+"/text_bytes",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/text_bytes/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
if(vErrors === null){
vErrors = [err328];
}
else {
vErrors.push(err328);
}
errors++;
}
else {
if(data126 < 0 || isNaN(data126)){
const err329 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i7+"/text_bytes",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/text_bytes/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid47 = _errs316 === errors;
}
else {
var valid47 = true;
}
if(valid47){
if(data118.text_steps !== undefined){
let data127 = data118.text_steps;
const _errs318 = errors;
if(!(((typeof data127 == "number") && (!(data127 % 1) && !isNaN(data127))) && (isFinite(data127)))){
const err330 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i7+"/text_steps",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/text_steps/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err330];
}
else {
vErrors.push(err330);
}
errors++;
}
if(errors === _errs318){
if((typeof data127 == "number") && (isFinite(data127))){
if(data127 > 65535 || isNaN(data127)){
const err331 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i7+"/text_steps",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/text_steps/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
if(vErrors === null){
vErrors = [err331];
}
else {
vErrors.push(err331);
}
errors++;
}
else {
if(data127 < 0 || isNaN(data127)){
const err332 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i7+"/text_steps",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/text_steps/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid47 = _errs318 === errors;
}
else {
var valid47 = true;
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
const err333 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i7,schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err333];
}
else {
vErrors.push(err333);
}
errors++;
}
}
var valid46 = _errs298 === errors;
if(!valid46){
break;
}
}
}
}
else {
const err334 = {instancePath:instancePath+"/compiled/source/source/document/projections",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err334];
}
else {
vErrors.push(err334);
}
errors++;
}
}
var valid42 = _errs296 === errors;
}
else {
var valid42 = true;
}
}
}
}
}
}
}
else {
const err335 = {instancePath:instancePath+"/compiled/source/source/document",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err336 = {instancePath:instancePath+"/compiled/source/source",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err336];
}
else {
vErrors.push(err336);
}
errors++;
}
}
var _valid4 = _errs267 === errors;
if(_valid4 && valid33){
valid33 = false;
passing2 = [passing2, 2];
}
else {
if(_valid4){
valid33 = true;
passing2 = 2;
if(props2 !== true){
props2 = true;
}
}
}
}
if(!valid33){
const err337 = {instancePath:instancePath+"/compiled/source/source",schemaPath:"#/oneOf/1/properties/compiled/properties/source/properties/source/oneOf",keyword:"oneOf",params:{passingSchemas: passing2},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err337];
}
else {
vErrors.push(err337);
}
errors++;
}
else {
errors = _errs230;
if(vErrors !== null){
if(_errs230){
vErrors.length = _errs230;
}
else {
vErrors = null;
}
}
}
var valid32 = _errs229 === errors;
}
else {
var valid32 = true;
}
}
}
}
}
}
else {
const err338 = {instancePath:instancePath+"/compiled/source",schemaPath:"#/oneOf/1/properties/compiled/properties/source/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err338];
}
else {
vErrors.push(err338);
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
if(data88.plan !== undefined){
let data128 = data88.plan;
const _errs320 = errors;
if(errors === _errs320){
if(data128 && typeof data128 == "object" && !Array.isArray(data128)){
let missing35;
if((((((data128.version === undefined) && (missing35 = "version")) || ((data128.projection === undefined) && (missing35 = "projection"))) || ((data128.limit === undefined) && (missing35 = "limit"))) || ((data128.aggregate === undefined) && (missing35 = "aggregate"))) || ((data128.predicate === undefined) && (missing35 = "predicate"))){
const err339 = {instancePath:instancePath+"/compiled/plan",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/required",keyword:"required",params:{missingProperty: missing35},message:"must have required property '"+missing35+"'"};
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
for(const key35 in data128){
if(!(((((key35 === "version") || (key35 === "projection")) || (key35 === "limit")) || (key35 === "aggregate")) || (key35 === "predicate"))){
const err340 = {instancePath:instancePath+"/compiled/plan",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key35},message:"must NOT have additional properties"};
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
if(data128.version !== undefined){
let data129 = data128.version;
const _errs323 = errors;
if(!(((typeof data129 == "number") && (!(data129 % 1) && !isNaN(data129))) && (isFinite(data129)))){
const err341 = {instancePath:instancePath+"/compiled/plan/version",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err341];
}
else {
vErrors.push(err341);
}
errors++;
}
if(errors === _errs323){
if((typeof data129 == "number") && (isFinite(data129))){
if(data129 > 255 || isNaN(data129)){
const err342 = {instancePath:instancePath+"/compiled/plan/version",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/version/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err342];
}
else {
vErrors.push(err342);
}
errors++;
}
else {
if(data129 < 0 || isNaN(data129)){
const err343 = {instancePath:instancePath+"/compiled/plan/version",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/version/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
if(data128.projection !== undefined){
let data130 = data128.projection;
const _errs325 = errors;
if(errors === _errs325){
if(Array.isArray(data130)){
if(data130.length > 8){
const err344 = {instancePath:instancePath+"/compiled/plan/projection",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/projection/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err344];
}
else {
vErrors.push(err344);
}
errors++;
}
else {
var valid51 = true;
const len9 = data130.length;
for(let i9=0; i9<len9; i9++){
let data131 = data130[i9];
const _errs327 = errors;
if(!(((typeof data131 == "number") && (!(data131 % 1) && !isNaN(data131))) && (isFinite(data131)))){
const err345 = {instancePath:instancePath+"/compiled/plan/projection/" + i9,schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/projection/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err345];
}
else {
vErrors.push(err345);
}
errors++;
}
if(errors === _errs327){
if((typeof data131 == "number") && (isFinite(data131))){
if(data131 > 4294967295 || isNaN(data131)){
const err346 = {instancePath:instancePath+"/compiled/plan/projection/" + i9,schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/projection/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err346];
}
else {
vErrors.push(err346);
}
errors++;
}
else {
if(data131 < 0 || isNaN(data131)){
const err347 = {instancePath:instancePath+"/compiled/plan/projection/" + i9,schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/projection/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid51 = _errs327 === errors;
if(!valid51){
break;
}
}
}
}
else {
const err348 = {instancePath:instancePath+"/compiled/plan/projection",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/projection/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err348];
}
else {
vErrors.push(err348);
}
errors++;
}
}
var valid50 = _errs325 === errors;
}
else {
var valid50 = true;
}
if(valid50){
if(data128.limit !== undefined){
let data132 = data128.limit;
const _errs329 = errors;
const _errs330 = errors;
let valid52 = false;
const _errs331 = errors;
if(errors === _errs331){
if(typeof data132 === "string"){
if(func1(data132) > 131072){
const err349 = {instancePath:instancePath+"/compiled/plan/limit",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/limit/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err349];
}
else {
vErrors.push(err349);
}
errors++;
}
}
else {
const err350 = {instancePath:instancePath+"/compiled/plan/limit",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/limit/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err350];
}
else {
vErrors.push(err350);
}
errors++;
}
}
var _valid6 = _errs331 === errors;
valid52 = valid52 || _valid6;
const _errs333 = errors;
if(data132 !== null){
const err351 = {instancePath:instancePath+"/compiled/plan/limit",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/limit/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err351];
}
else {
vErrors.push(err351);
}
errors++;
}
var _valid6 = _errs333 === errors;
valid52 = valid52 || _valid6;
if(!valid52){
const err352 = {instancePath:instancePath+"/compiled/plan/limit",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/limit/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err352];
}
else {
vErrors.push(err352);
}
errors++;
}
else {
errors = _errs330;
if(vErrors !== null){
if(_errs330){
vErrors.length = _errs330;
}
else {
vErrors = null;
}
}
}
var valid50 = _errs329 === errors;
}
else {
var valid50 = true;
}
if(valid50){
if(data128.aggregate !== undefined){
let data133 = data128.aggregate;
const _errs335 = errors;
if(typeof data133 !== "string"){
const err353 = {instancePath:instancePath+"/compiled/plan/aggregate",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/aggregate/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err353];
}
else {
vErrors.push(err353);
}
errors++;
}
if(!(((data133 === "rows") || (data133 === "count")) || (data133 === "sum"))){
const err354 = {instancePath:instancePath+"/compiled/plan/aggregate",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/aggregate/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[1].properties.compiled.properties.plan.properties.aggregate.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err354];
}
else {
vErrors.push(err354);
}
errors++;
}
var valid50 = _errs335 === errors;
}
else {
var valid50 = true;
}
if(valid50){
if(data128.predicate !== undefined){
let data134 = data128.predicate;
const _errs337 = errors;
const _errs338 = errors;
let valid53 = false;
let passing3 = null;
const _errs339 = errors;
if(errors === _errs339){
if(data134 && typeof data134 == "object" && !Array.isArray(data134)){
let missing36;
if((data134.all === undefined) && (missing36 = "all")){
const err355 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/0/required",keyword:"required",params:{missingProperty: missing36},message:"must have required property '"+missing36+"'"};
if(vErrors === null){
vErrors = [err355];
}
else {
vErrors.push(err355);
}
errors++;
}
else {
const _errs341 = errors;
for(const key36 in data134){
if(!(key36 === "all")){
const err356 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key36},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err356];
}
else {
vErrors.push(err356);
}
errors++;
break;
}
}
if(_errs341 === errors){
if(data134.all !== undefined){
let data135 = data134.all;
const _errs342 = errors;
if(errors === _errs342){
if(data135 && typeof data135 == "object" && !Array.isArray(data135)){
if(Object.keys(data135).length > 0){
const err357 = {instancePath:instancePath+"/compiled/plan/predicate/all",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/0/properties/all/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err357];
}
else {
vErrors.push(err357);
}
errors++;
}
}
else {
const err358 = {instancePath:instancePath+"/compiled/plan/predicate/all",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/0/properties/all/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err358];
}
else {
vErrors.push(err358);
}
errors++;
}
}
}
}
}
}
else {
const err359 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err359];
}
else {
vErrors.push(err359);
}
errors++;
}
}
var _valid7 = _errs339 === errors;
if(_valid7){
valid53 = true;
passing3 = 0;
var props3 = true;
}
const _errs344 = errors;
if(errors === _errs344){
if(data134 && typeof data134 == "object" && !Array.isArray(data134)){
let missing37;
if((data134.state === undefined) && (missing37 = "state")){
const err360 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/1/required",keyword:"required",params:{missingProperty: missing37},message:"must have required property '"+missing37+"'"};
if(vErrors === null){
vErrors = [err360];
}
else {
vErrors.push(err360);
}
errors++;
}
else {
const _errs346 = errors;
for(const key37 in data134){
if(!(key37 === "state")){
const err361 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key37},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err361];
}
else {
vErrors.push(err361);
}
errors++;
break;
}
}
if(_errs346 === errors){
if(data134.state !== undefined){
let data136 = data134.state;
const _errs347 = errors;
if(errors === _errs347){
if(data136 && typeof data136 == "object" && !Array.isArray(data136)){
let missing38;
if(((data136.column === undefined) && (missing38 = "column")) || ((data136.value === undefined) && (missing38 = "value"))){
const err362 = {instancePath:instancePath+"/compiled/plan/predicate/state",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/required",keyword:"required",params:{missingProperty: missing38},message:"must have required property '"+missing38+"'"};
if(vErrors === null){
vErrors = [err362];
}
else {
vErrors.push(err362);
}
errors++;
}
else {
const _errs349 = errors;
for(const key38 in data136){
if(!((key38 === "column") || (key38 === "value"))){
const err363 = {instancePath:instancePath+"/compiled/plan/predicate/state",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key38},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err363];
}
else {
vErrors.push(err363);
}
errors++;
break;
}
}
if(_errs349 === errors){
if(data136.column !== undefined){
let data137 = data136.column;
const _errs350 = errors;
if(!(((typeof data137 == "number") && (!(data137 % 1) && !isNaN(data137))) && (isFinite(data137)))){
const err364 = {instancePath:instancePath+"/compiled/plan/predicate/state/column",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/properties/column/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err364];
}
else {
vErrors.push(err364);
}
errors++;
}
if(errors === _errs350){
if((typeof data137 == "number") && (isFinite(data137))){
if(data137 > 255 || isNaN(data137)){
const err365 = {instancePath:instancePath+"/compiled/plan/predicate/state/column",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/properties/column/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err365];
}
else {
vErrors.push(err365);
}
errors++;
}
else {
if(data137 < 0 || isNaN(data137)){
const err366 = {instancePath:instancePath+"/compiled/plan/predicate/state/column",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/properties/column/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err366];
}
else {
vErrors.push(err366);
}
errors++;
}
}
}
}
var valid56 = _errs350 === errors;
}
else {
var valid56 = true;
}
if(valid56){
if(data136.value !== undefined){
let data138 = data136.value;
const _errs352 = errors;
if(typeof data138 !== "string"){
const err367 = {instancePath:instancePath+"/compiled/plan/predicate/state/value",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/properties/value/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err367];
}
else {
vErrors.push(err367);
}
errors++;
}
if(!(((((data138 === "missing") || (data138 === "null")) || (data138 === "type_error")) || (data138 === "value")) || (data138 === "conflict"))){
const err368 = {instancePath:instancePath+"/compiled/plan/predicate/state/value",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/properties/value/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[1].properties.compiled.properties.plan.properties.predicate.oneOf[1].properties.state.properties.value.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err368];
}
else {
vErrors.push(err368);
}
errors++;
}
var valid56 = _errs352 === errors;
}
else {
var valid56 = true;
}
}
}
}
}
else {
const err369 = {instancePath:instancePath+"/compiled/plan/predicate/state",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err369];
}
else {
vErrors.push(err369);
}
errors++;
}
}
}
}
}
}
else {
const err370 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err370];
}
else {
vErrors.push(err370);
}
errors++;
}
}
var _valid7 = _errs344 === errors;
if(_valid7 && valid53){
valid53 = false;
passing3 = [passing3, 1];
}
else {
if(_valid7){
valid53 = true;
passing3 = 1;
if(props3 !== true){
props3 = true;
}
}
const _errs354 = errors;
if(errors === _errs354){
if(data134 && typeof data134 == "object" && !Array.isArray(data134)){
let missing39;
if((data134.compare === undefined) && (missing39 = "compare")){
const err371 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/required",keyword:"required",params:{missingProperty: missing39},message:"must have required property '"+missing39+"'"};
if(vErrors === null){
vErrors = [err371];
}
else {
vErrors.push(err371);
}
errors++;
}
else {
const _errs356 = errors;
for(const key39 in data134){
if(!(key39 === "compare")){
const err372 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key39},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err372];
}
else {
vErrors.push(err372);
}
errors++;
break;
}
}
if(_errs356 === errors){
if(data134.compare !== undefined){
let data139 = data134.compare;
const _errs357 = errors;
if(errors === _errs357){
if(data139 && typeof data139 == "object" && !Array.isArray(data139)){
let missing40;
if((((data139.column === undefined) && (missing40 = "column")) || ((data139.op === undefined) && (missing40 = "op"))) || ((data139.value === undefined) && (missing40 = "value"))){
const err373 = {instancePath:instancePath+"/compiled/plan/predicate/compare",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/required",keyword:"required",params:{missingProperty: missing40},message:"must have required property '"+missing40+"'"};
if(vErrors === null){
vErrors = [err373];
}
else {
vErrors.push(err373);
}
errors++;
}
else {
const _errs359 = errors;
for(const key40 in data139){
if(!(((key40 === "column") || (key40 === "op")) || (key40 === "value"))){
const err374 = {instancePath:instancePath+"/compiled/plan/predicate/compare",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key40},message:"must NOT have additional properties"};
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
if(_errs359 === errors){
if(data139.column !== undefined){
let data140 = data139.column;
const _errs360 = errors;
if(!(((typeof data140 == "number") && (!(data140 % 1) && !isNaN(data140))) && (isFinite(data140)))){
const err375 = {instancePath:instancePath+"/compiled/plan/predicate/compare/column",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/column/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err375];
}
else {
vErrors.push(err375);
}
errors++;
}
if(errors === _errs360){
if((typeof data140 == "number") && (isFinite(data140))){
if(data140 > 255 || isNaN(data140)){
const err376 = {instancePath:instancePath+"/compiled/plan/predicate/compare/column",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/column/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err376];
}
else {
vErrors.push(err376);
}
errors++;
}
else {
if(data140 < 0 || isNaN(data140)){
const err377 = {instancePath:instancePath+"/compiled/plan/predicate/compare/column",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/column/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err377];
}
else {
vErrors.push(err377);
}
errors++;
}
}
}
}
var valid58 = _errs360 === errors;
}
else {
var valid58 = true;
}
if(valid58){
if(data139.op !== undefined){
let data141 = data139.op;
const _errs362 = errors;
if(typeof data141 !== "string"){
const err378 = {instancePath:instancePath+"/compiled/plan/predicate/compare/op",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/op/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err378];
}
else {
vErrors.push(err378);
}
errors++;
}
if(!((((((data141 === "eq") || (data141 === "ne")) || (data141 === "lt")) || (data141 === "le")) || (data141 === "gt")) || (data141 === "ge"))){
const err379 = {instancePath:instancePath+"/compiled/plan/predicate/compare/op",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/op/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[1].properties.compiled.properties.plan.properties.predicate.oneOf[2].properties.compare.properties.op.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err379];
}
else {
vErrors.push(err379);
}
errors++;
}
var valid58 = _errs362 === errors;
}
else {
var valid58 = true;
}
if(valid58){
if(data139.value !== undefined){
let data142 = data139.value;
const _errs364 = errors;
const _errs365 = errors;
let valid59 = false;
let passing4 = null;
const _errs366 = errors;
if(errors === _errs366){
if(data142 && typeof data142 == "object" && !Array.isArray(data142)){
let missing41;
if((data142.int64 === undefined) && (missing41 = "int64")){
const err380 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/0/required",keyword:"required",params:{missingProperty: missing41},message:"must have required property '"+missing41+"'"};
if(vErrors === null){
vErrors = [err380];
}
else {
vErrors.push(err380);
}
errors++;
}
else {
const _errs368 = errors;
for(const key41 in data142){
if(!(key41 === "int64")){
const err381 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key41},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err381];
}
else {
vErrors.push(err381);
}
errors++;
break;
}
}
if(_errs368 === errors){
if(data142.int64 !== undefined){
let data143 = data142.int64;
const _errs369 = errors;
if(errors === _errs369){
if(typeof data143 === "string"){
if(func1(data143) > 131072){
const err382 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/int64",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/0/properties/int64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err383 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/int64",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/0/properties/int64/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err383];
}
else {
vErrors.push(err383);
}
errors++;
}
}
}
}
}
}
else {
const err384 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err384];
}
else {
vErrors.push(err384);
}
errors++;
}
}
var _valid8 = _errs366 === errors;
if(_valid8){
valid59 = true;
passing4 = 0;
var props4 = true;
}
const _errs371 = errors;
if(errors === _errs371){
if(data142 && typeof data142 == "object" && !Array.isArray(data142)){
let missing42;
if((data142.uint64 === undefined) && (missing42 = "uint64")){
const err385 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/1/required",keyword:"required",params:{missingProperty: missing42},message:"must have required property '"+missing42+"'"};
if(vErrors === null){
vErrors = [err385];
}
else {
vErrors.push(err385);
}
errors++;
}
else {
const _errs373 = errors;
for(const key42 in data142){
if(!(key42 === "uint64")){
const err386 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key42},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err386];
}
else {
vErrors.push(err386);
}
errors++;
break;
}
}
if(_errs373 === errors){
if(data142.uint64 !== undefined){
let data144 = data142.uint64;
const _errs374 = errors;
if(errors === _errs374){
if(typeof data144 === "string"){
if(func1(data144) > 131072){
const err387 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/uint64",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/1/properties/uint64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err387];
}
else {
vErrors.push(err387);
}
errors++;
}
}
else {
const err388 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/uint64",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/1/properties/uint64/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
}
}
else {
const err389 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err389];
}
else {
vErrors.push(err389);
}
errors++;
}
}
var _valid8 = _errs371 === errors;
if(_valid8 && valid59){
valid59 = false;
passing4 = [passing4, 1];
}
else {
if(_valid8){
valid59 = true;
passing4 = 1;
if(props4 !== true){
props4 = true;
}
}
const _errs376 = errors;
if(errors === _errs376){
if(data142 && typeof data142 == "object" && !Array.isArray(data142)){
let missing43;
if((data142.float_bits === undefined) && (missing43 = "float_bits")){
const err390 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/2/required",keyword:"required",params:{missingProperty: missing43},message:"must have required property '"+missing43+"'"};
if(vErrors === null){
vErrors = [err390];
}
else {
vErrors.push(err390);
}
errors++;
}
else {
const _errs378 = errors;
for(const key43 in data142){
if(!(key43 === "float_bits")){
const err391 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key43},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err391];
}
else {
vErrors.push(err391);
}
errors++;
break;
}
}
if(_errs378 === errors){
if(data142.float_bits !== undefined){
let data145 = data142.float_bits;
const _errs379 = errors;
if(errors === _errs379){
if(typeof data145 === "string"){
if(func1(data145) > 131072){
const err392 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/float_bits",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/2/properties/float_bits/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err392];
}
else {
vErrors.push(err392);
}
errors++;
}
}
else {
const err393 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/float_bits",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/2/properties/float_bits/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err393];
}
else {
vErrors.push(err393);
}
errors++;
}
}
}
}
}
}
else {
const err394 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err394];
}
else {
vErrors.push(err394);
}
errors++;
}
}
var _valid8 = _errs376 === errors;
if(_valid8 && valid59){
valid59 = false;
passing4 = [passing4, 2];
}
else {
if(_valid8){
valid59 = true;
passing4 = 2;
if(props4 !== true){
props4 = true;
}
}
const _errs381 = errors;
if(errors === _errs381){
if(data142 && typeof data142 == "object" && !Array.isArray(data142)){
let missing44;
if((data142.boolean === undefined) && (missing44 = "boolean")){
const err395 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/3/required",keyword:"required",params:{missingProperty: missing44},message:"must have required property '"+missing44+"'"};
if(vErrors === null){
vErrors = [err395];
}
else {
vErrors.push(err395);
}
errors++;
}
else {
const _errs383 = errors;
for(const key44 in data142){
if(!(key44 === "boolean")){
const err396 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key44},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err396];
}
else {
vErrors.push(err396);
}
errors++;
break;
}
}
if(_errs383 === errors){
if(data142.boolean !== undefined){
if(typeof data142.boolean !== "boolean"){
const err397 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/boolean",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/3/properties/boolean/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err397];
}
else {
vErrors.push(err397);
}
errors++;
}
}
}
}
}
else {
const err398 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err398];
}
else {
vErrors.push(err398);
}
errors++;
}
}
var _valid8 = _errs381 === errors;
if(_valid8 && valid59){
valid59 = false;
passing4 = [passing4, 3];
}
else {
if(_valid8){
valid59 = true;
passing4 = 3;
if(props4 !== true){
props4 = true;
}
}
const _errs386 = errors;
if(errors === _errs386){
if(data142 && typeof data142 == "object" && !Array.isArray(data142)){
let missing45;
if((data142.utf8 === undefined) && (missing45 = "utf8")){
const err399 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/4/required",keyword:"required",params:{missingProperty: missing45},message:"must have required property '"+missing45+"'"};
if(vErrors === null){
vErrors = [err399];
}
else {
vErrors.push(err399);
}
errors++;
}
else {
const _errs388 = errors;
for(const key45 in data142){
if(!(key45 === "utf8")){
const err400 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key45},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err400];
}
else {
vErrors.push(err400);
}
errors++;
break;
}
}
if(_errs388 === errors){
if(data142.utf8 !== undefined){
let data147 = data142.utf8;
const _errs389 = errors;
if(errors === _errs389){
if(typeof data147 === "string"){
if(func1(data147) > 131072){
const err401 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/utf8",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/4/properties/utf8/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err401];
}
else {
vErrors.push(err401);
}
errors++;
}
}
else {
const err402 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/utf8",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/4/properties/utf8/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err402];
}
else {
vErrors.push(err402);
}
errors++;
}
}
}
}
}
}
else {
const err403 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err403];
}
else {
vErrors.push(err403);
}
errors++;
}
}
var _valid8 = _errs386 === errors;
if(_valid8 && valid59){
valid59 = false;
passing4 = [passing4, 4];
}
else {
if(_valid8){
valid59 = true;
passing4 = 4;
if(props4 !== true){
props4 = true;
}
}
const _errs391 = errors;
if(errors === _errs391){
if(data142 && typeof data142 == "object" && !Array.isArray(data142)){
let missing46;
if((data142.binary === undefined) && (missing46 = "binary")){
const err404 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/5/required",keyword:"required",params:{missingProperty: missing46},message:"must have required property '"+missing46+"'"};
if(vErrors === null){
vErrors = [err404];
}
else {
vErrors.push(err404);
}
errors++;
}
else {
const _errs393 = errors;
for(const key46 in data142){
if(!(key46 === "binary")){
const err405 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key46},message:"must NOT have additional properties"};
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
if(_errs393 === errors){
if(data142.binary !== undefined){
let data148 = data142.binary;
const _errs394 = errors;
if(errors === _errs394){
if(typeof data148 === "string"){
if(func1(data148) > 131072){
const err406 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/binary",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/5/properties/binary/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err407 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/binary",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/5/properties/binary/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
}
}
else {
const err408 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err408];
}
else {
vErrors.push(err408);
}
errors++;
}
}
var _valid8 = _errs391 === errors;
if(_valid8 && valid59){
valid59 = false;
passing4 = [passing4, 5];
}
else {
if(_valid8){
valid59 = true;
passing4 = 5;
if(props4 !== true){
props4 = true;
}
}
}
}
}
}
}
if(!valid59){
const err409 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf",keyword:"oneOf",params:{passingSchemas: passing4},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err409];
}
else {
vErrors.push(err409);
}
errors++;
}
else {
errors = _errs365;
if(vErrors !== null){
if(_errs365){
vErrors.length = _errs365;
}
else {
vErrors = null;
}
}
}
var valid58 = _errs364 === errors;
}
else {
var valid58 = true;
}
}
}
}
}
}
else {
const err410 = {instancePath:instancePath+"/compiled/plan/predicate/compare",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err411 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err411];
}
else {
vErrors.push(err411);
}
errors++;
}
}
var _valid7 = _errs354 === errors;
if(_valid7 && valid53){
valid53 = false;
passing3 = [passing3, 2];
}
else {
if(_valid7){
valid53 = true;
passing3 = 2;
if(props3 !== true){
props3 = true;
}
}
}
}
if(!valid53){
const err412 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/properties/predicate/oneOf",keyword:"oneOf",params:{passingSchemas: passing3},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err412];
}
else {
vErrors.push(err412);
}
errors++;
}
else {
errors = _errs338;
if(vErrors !== null){
if(_errs338){
vErrors.length = _errs338;
}
else {
vErrors = null;
}
}
}
var valid50 = _errs337 === errors;
}
else {
var valid50 = true;
}
}
}
}
}
}
}
}
else {
const err413 = {instancePath:instancePath+"/compiled/plan",schemaPath:"#/oneOf/1/properties/compiled/properties/plan/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err413];
}
else {
vErrors.push(err413);
}
errors++;
}
}
var valid31 = _errs320 === errors;
}
else {
var valid31 = true;
}
if(valid31){
if(data88.limits !== undefined){
let data149 = data88.limits;
const _errs396 = errors;
if(errors === _errs396){
if(data149 && typeof data149 == "object" && !Array.isArray(data149)){
let missing47;
if((((data149.pages === undefined) && (missing47 = "pages")) || ((data149.segments === undefined) && (missing47 = "segments"))) || ((data149.result_bytes === undefined) && (missing47 = "result_bytes"))){
const err414 = {instancePath:instancePath+"/compiled/limits",schemaPath:"#/oneOf/1/properties/compiled/properties/limits/required",keyword:"required",params:{missingProperty: missing47},message:"must have required property '"+missing47+"'"};
if(vErrors === null){
vErrors = [err414];
}
else {
vErrors.push(err414);
}
errors++;
}
else {
const _errs398 = errors;
for(const key47 in data149){
if(!(((key47 === "pages") || (key47 === "segments")) || (key47 === "result_bytes"))){
const err415 = {instancePath:instancePath+"/compiled/limits",schemaPath:"#/oneOf/1/properties/compiled/properties/limits/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key47},message:"must NOT have additional properties"};
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
if(_errs398 === errors){
if(data149.pages !== undefined){
let data150 = data149.pages;
const _errs399 = errors;
if(errors === _errs399){
if(typeof data150 === "string"){
if(func1(data150) > 131072){
const err416 = {instancePath:instancePath+"/compiled/limits/pages",schemaPath:"#/oneOf/1/properties/compiled/properties/limits/properties/pages/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err416];
}
else {
vErrors.push(err416);
}
errors++;
}
}
else {
const err417 = {instancePath:instancePath+"/compiled/limits/pages",schemaPath:"#/oneOf/1/properties/compiled/properties/limits/properties/pages/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err417];
}
else {
vErrors.push(err417);
}
errors++;
}
}
var valid66 = _errs399 === errors;
}
else {
var valid66 = true;
}
if(valid66){
if(data149.segments !== undefined){
let data151 = data149.segments;
const _errs401 = errors;
if(errors === _errs401){
if(typeof data151 === "string"){
if(func1(data151) > 131072){
const err418 = {instancePath:instancePath+"/compiled/limits/segments",schemaPath:"#/oneOf/1/properties/compiled/properties/limits/properties/segments/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err418];
}
else {
vErrors.push(err418);
}
errors++;
}
}
else {
const err419 = {instancePath:instancePath+"/compiled/limits/segments",schemaPath:"#/oneOf/1/properties/compiled/properties/limits/properties/segments/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err419];
}
else {
vErrors.push(err419);
}
errors++;
}
}
var valid66 = _errs401 === errors;
}
else {
var valid66 = true;
}
if(valid66){
if(data149.result_bytes !== undefined){
let data152 = data149.result_bytes;
const _errs403 = errors;
if(errors === _errs403){
if(typeof data152 === "string"){
if(func1(data152) > 131072){
const err420 = {instancePath:instancePath+"/compiled/limits/result_bytes",schemaPath:"#/oneOf/1/properties/compiled/properties/limits/properties/result_bytes/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err420];
}
else {
vErrors.push(err420);
}
errors++;
}
}
else {
const err421 = {instancePath:instancePath+"/compiled/limits/result_bytes",schemaPath:"#/oneOf/1/properties/compiled/properties/limits/properties/result_bytes/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err421];
}
else {
vErrors.push(err421);
}
errors++;
}
}
var valid66 = _errs403 === errors;
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
const err422 = {instancePath:instancePath+"/compiled/limits",schemaPath:"#/oneOf/1/properties/compiled/properties/limits/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err422];
}
else {
vErrors.push(err422);
}
errors++;
}
}
var valid31 = _errs396 === errors;
}
else {
var valid31 = true;
}
if(valid31){
if(data88.contract !== undefined){
let data153 = data88.contract;
const _errs405 = errors;
if(errors === _errs405){
if(Array.isArray(data153)){
if(data153.length > 32){
const err423 = {instancePath:instancePath+"/compiled/contract",schemaPath:"#/oneOf/1/properties/compiled/properties/contract/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err423];
}
else {
vErrors.push(err423);
}
errors++;
}
else {
if(data153.length < 32){
const err424 = {instancePath:instancePath+"/compiled/contract",schemaPath:"#/oneOf/1/properties/compiled/properties/contract/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err424];
}
else {
vErrors.push(err424);
}
errors++;
}
else {
var valid67 = true;
const len10 = data153.length;
for(let i10=0; i10<len10; i10++){
let data154 = data153[i10];
const _errs407 = errors;
if(!(((typeof data154 == "number") && (!(data154 % 1) && !isNaN(data154))) && (isFinite(data154)))){
const err425 = {instancePath:instancePath+"/compiled/contract/" + i10,schemaPath:"#/oneOf/1/properties/compiled/properties/contract/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err425];
}
else {
vErrors.push(err425);
}
errors++;
}
if(errors === _errs407){
if((typeof data154 == "number") && (isFinite(data154))){
if(data154 > 255 || isNaN(data154)){
const err426 = {instancePath:instancePath+"/compiled/contract/" + i10,schemaPath:"#/oneOf/1/properties/compiled/properties/contract/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err426];
}
else {
vErrors.push(err426);
}
errors++;
}
else {
if(data154 < 0 || isNaN(data154)){
const err427 = {instancePath:instancePath+"/compiled/contract/" + i10,schemaPath:"#/oneOf/1/properties/compiled/properties/contract/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err427];
}
else {
vErrors.push(err427);
}
errors++;
}
}
}
}
var valid67 = _errs407 === errors;
if(!valid67){
break;
}
}
}
}
}
else {
const err428 = {instancePath:instancePath+"/compiled/contract",schemaPath:"#/oneOf/1/properties/compiled/properties/contract/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err428];
}
else {
vErrors.push(err428);
}
errors++;
}
}
var valid31 = _errs405 === errors;
}
else {
var valid31 = true;
}
if(valid31){
if(data88.schema !== undefined){
let data155 = data88.schema;
const _errs409 = errors;
if(errors === _errs409){
if(Array.isArray(data155)){
if(data155.length > 32){
const err429 = {instancePath:instancePath+"/compiled/schema",schemaPath:"#/oneOf/1/properties/compiled/properties/schema/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err429];
}
else {
vErrors.push(err429);
}
errors++;
}
else {
if(data155.length < 32){
const err430 = {instancePath:instancePath+"/compiled/schema",schemaPath:"#/oneOf/1/properties/compiled/properties/schema/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err430];
}
else {
vErrors.push(err430);
}
errors++;
}
else {
var valid68 = true;
const len11 = data155.length;
for(let i11=0; i11<len11; i11++){
let data156 = data155[i11];
const _errs411 = errors;
if(!(((typeof data156 == "number") && (!(data156 % 1) && !isNaN(data156))) && (isFinite(data156)))){
const err431 = {instancePath:instancePath+"/compiled/schema/" + i11,schemaPath:"#/oneOf/1/properties/compiled/properties/schema/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err431];
}
else {
vErrors.push(err431);
}
errors++;
}
if(errors === _errs411){
if((typeof data156 == "number") && (isFinite(data156))){
if(data156 > 255 || isNaN(data156)){
const err432 = {instancePath:instancePath+"/compiled/schema/" + i11,schemaPath:"#/oneOf/1/properties/compiled/properties/schema/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err432];
}
else {
vErrors.push(err432);
}
errors++;
}
else {
if(data156 < 0 || isNaN(data156)){
const err433 = {instancePath:instancePath+"/compiled/schema/" + i11,schemaPath:"#/oneOf/1/properties/compiled/properties/schema/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid68 = _errs411 === errors;
if(!valid68){
break;
}
}
}
}
}
else {
const err434 = {instancePath:instancePath+"/compiled/schema",schemaPath:"#/oneOf/1/properties/compiled/properties/schema/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err434];
}
else {
vErrors.push(err434);
}
errors++;
}
}
var valid31 = _errs409 === errors;
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
}
}
else {
const err435 = {instancePath:instancePath+"/compiled",schemaPath:"#/oneOf/1/properties/compiled/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err435];
}
else {
vErrors.push(err435);
}
errors++;
}
}
}
}
}
}
else {
const err436 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err436];
}
else {
vErrors.push(err436);
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
const _errs413 = errors;
if(errors === _errs413){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing48;
if((data.prepared === undefined) && (missing48 = "prepared")){
const err437 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing48},message:"must have required property '"+missing48+"'"};
if(vErrors === null){
vErrors = [err437];
}
else {
vErrors.push(err437);
}
errors++;
}
else {
const _errs415 = errors;
for(const key48 in data){
if(!(key48 === "prepared")){
const err438 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key48},message:"must NOT have additional properties"};
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
if(_errs415 === errors){
if(data.prepared !== undefined){
let data157 = data.prepared;
const _errs417 = errors;
let valid70 = false;
const _errs418 = errors;
if(errors === _errs418){
if(data157 && typeof data157 == "object" && !Array.isArray(data157)){
let missing49;
if((data157.token === undefined) && (missing49 = "token")){
const err439 = {instancePath:instancePath+"/prepared",schemaPath:"#/oneOf/2/properties/prepared/anyOf/0/required",keyword:"required",params:{missingProperty: missing49},message:"must have required property '"+missing49+"'"};
if(vErrors === null){
vErrors = [err439];
}
else {
vErrors.push(err439);
}
errors++;
}
else {
const _errs420 = errors;
for(const key49 in data157){
if(!(key49 === "token")){
const err440 = {instancePath:instancePath+"/prepared",schemaPath:"#/oneOf/2/properties/prepared/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key49},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err440];
}
else {
vErrors.push(err440);
}
errors++;
break;
}
}
if(_errs420 === errors){
if(data157.token !== undefined){
let data158 = data157.token;
const _errs421 = errors;
if(errors === _errs421){
if(typeof data158 === "string"){
if(func1(data158) > 131072){
const err441 = {instancePath:instancePath+"/prepared/token",schemaPath:"#/oneOf/2/properties/prepared/anyOf/0/properties/token/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err442 = {instancePath:instancePath+"/prepared/token",schemaPath:"#/oneOf/2/properties/prepared/anyOf/0/properties/token/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err442];
}
else {
vErrors.push(err442);
}
errors++;
}
}
}
}
}
}
else {
const err443 = {instancePath:instancePath+"/prepared",schemaPath:"#/oneOf/2/properties/prepared/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err443];
}
else {
vErrors.push(err443);
}
errors++;
}
}
var _valid9 = _errs418 === errors;
valid70 = valid70 || _valid9;
const _errs423 = errors;
if(data157 !== null){
const err444 = {instancePath:instancePath+"/prepared",schemaPath:"#/oneOf/2/properties/prepared/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err444];
}
else {
vErrors.push(err444);
}
errors++;
}
var _valid9 = _errs423 === errors;
valid70 = valid70 || _valid9;
if(!valid70){
const err445 = {instancePath:instancePath+"/prepared",schemaPath:"#/oneOf/2/properties/prepared/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err445];
}
else {
vErrors.push(err445);
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
}
}
}
}
else {
const err446 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err446];
}
else {
vErrors.push(err446);
}
errors++;
}
}
var _valid0 = _errs413 === errors;
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
const _errs425 = errors;
if(errors === _errs425){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing50;
if((data.receipt === undefined) && (missing50 = "receipt")){
const err447 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing50},message:"must have required property '"+missing50+"'"};
if(vErrors === null){
vErrors = [err447];
}
else {
vErrors.push(err447);
}
errors++;
}
else {
const _errs427 = errors;
for(const key50 in data){
if(!(key50 === "receipt")){
const err448 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key50},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err448];
}
else {
vErrors.push(err448);
}
errors++;
break;
}
}
if(_errs427 === errors){
if(data.receipt !== undefined){
let data159 = data.receipt;
const _errs428 = errors;
if(errors === _errs428){
if(data159 && typeof data159 == "object" && !Array.isArray(data159)){
let missing51;
if((data159.position === undefined) && (missing51 = "position")){
const err449 = {instancePath:instancePath+"/receipt",schemaPath:"#/oneOf/3/properties/receipt/required",keyword:"required",params:{missingProperty: missing51},message:"must have required property '"+missing51+"'"};
if(vErrors === null){
vErrors = [err449];
}
else {
vErrors.push(err449);
}
errors++;
}
else {
const _errs430 = errors;
for(const key51 in data159){
if(!(key51 === "position")){
const err450 = {instancePath:instancePath+"/receipt",schemaPath:"#/oneOf/3/properties/receipt/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key51},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err450];
}
else {
vErrors.push(err450);
}
errors++;
break;
}
}
if(_errs430 === errors){
if(data159.position !== undefined){
let data160 = data159.position;
const _errs431 = errors;
if(!(((typeof data160 == "number") && (!(data160 % 1) && !isNaN(data160))) && (isFinite(data160)))){
const err451 = {instancePath:instancePath+"/receipt/position",schemaPath:"#/oneOf/3/properties/receipt/properties/position/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err451];
}
else {
vErrors.push(err451);
}
errors++;
}
if(errors === _errs431){
if((typeof data160 == "number") && (isFinite(data160))){
if(data160 > 9007199254740991 || isNaN(data160)){
const err452 = {instancePath:instancePath+"/receipt/position",schemaPath:"#/oneOf/3/properties/receipt/properties/position/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err452];
}
else {
vErrors.push(err452);
}
errors++;
}
else {
if(data160 < 0 || isNaN(data160)){
const err453 = {instancePath:instancePath+"/receipt/position",schemaPath:"#/oneOf/3/properties/receipt/properties/position/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err453];
}
else {
vErrors.push(err453);
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
const err454 = {instancePath:instancePath+"/receipt",schemaPath:"#/oneOf/3/properties/receipt/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err454];
}
else {
vErrors.push(err454);
}
errors++;
}
}
}
}
}
}
else {
const err455 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err455];
}
else {
vErrors.push(err455);
}
errors++;
}
}
var _valid0 = _errs425 === errors;
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
const _errs433 = errors;
if(errors === _errs433){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing52;
if((data.observation === undefined) && (missing52 = "observation")){
const err456 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing52},message:"must have required property '"+missing52+"'"};
if(vErrors === null){
vErrors = [err456];
}
else {
vErrors.push(err456);
}
errors++;
}
else {
const _errs435 = errors;
for(const key52 in data){
if(!(key52 === "observation")){
const err457 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key52},message:"must NOT have additional properties"};
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
if(_errs435 === errors){
if(data.observation !== undefined){
let data161 = data.observation;
const _errs437 = errors;
let valid75 = false;
let passing5 = null;
const _errs438 = errors;
if(errors === _errs438){
if(data161 && typeof data161 == "object" && !Array.isArray(data161)){
let missing53;
if((data161.pending === undefined) && (missing53 = "pending")){
const err458 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/4/properties/observation/oneOf/0/required",keyword:"required",params:{missingProperty: missing53},message:"must have required property '"+missing53+"'"};
if(vErrors === null){
vErrors = [err458];
}
else {
vErrors.push(err458);
}
errors++;
}
else {
const _errs440 = errors;
for(const key53 in data161){
if(!(key53 === "pending")){
const err459 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/4/properties/observation/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key53},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err459];
}
else {
vErrors.push(err459);
}
errors++;
break;
}
}
if(_errs440 === errors){
if(data161.pending !== undefined){
let data162 = data161.pending;
const _errs441 = errors;
if(errors === _errs441){
if(data162 && typeof data162 == "object" && !Array.isArray(data162)){
if(Object.keys(data162).length > 0){
const err460 = {instancePath:instancePath+"/observation/pending",schemaPath:"#/oneOf/4/properties/observation/oneOf/0/properties/pending/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err460];
}
else {
vErrors.push(err460);
}
errors++;
}
}
else {
const err461 = {instancePath:instancePath+"/observation/pending",schemaPath:"#/oneOf/4/properties/observation/oneOf/0/properties/pending/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err461];
}
else {
vErrors.push(err461);
}
errors++;
}
}
}
}
}
}
else {
const err462 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/4/properties/observation/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err462];
}
else {
vErrors.push(err462);
}
errors++;
}
}
var _valid10 = _errs438 === errors;
if(_valid10){
valid75 = true;
passing5 = 0;
var props6 = true;
}
const _errs443 = errors;
if(errors === _errs443){
if(data161 && typeof data161 == "object" && !Array.isArray(data161)){
let missing54;
if((data161.committed === undefined) && (missing54 = "committed")){
const err463 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/4/properties/observation/oneOf/1/required",keyword:"required",params:{missingProperty: missing54},message:"must have required property '"+missing54+"'"};
if(vErrors === null){
vErrors = [err463];
}
else {
vErrors.push(err463);
}
errors++;
}
else {
const _errs445 = errors;
for(const key54 in data161){
if(!(key54 === "committed")){
const err464 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/4/properties/observation/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key54},message:"must NOT have additional properties"};
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
if(_errs445 === errors){
if(data161.committed !== undefined){
let data163 = data161.committed;
const _errs446 = errors;
if(errors === _errs446){
if(data163 && typeof data163 == "object" && !Array.isArray(data163)){
if(Object.keys(data163).length > 0){
const err465 = {instancePath:instancePath+"/observation/committed",schemaPath:"#/oneOf/4/properties/observation/oneOf/1/properties/committed/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
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
const err466 = {instancePath:instancePath+"/observation/committed",schemaPath:"#/oneOf/4/properties/observation/oneOf/1/properties/committed/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err467 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/4/properties/observation/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err467];
}
else {
vErrors.push(err467);
}
errors++;
}
}
var _valid10 = _errs443 === errors;
if(_valid10 && valid75){
valid75 = false;
passing5 = [passing5, 1];
}
else {
if(_valid10){
valid75 = true;
passing5 = 1;
if(props6 !== true){
props6 = true;
}
}
const _errs448 = errors;
if(errors === _errs448){
if(data161 && typeof data161 == "object" && !Array.isArray(data161)){
let missing55;
if((data161.rejected === undefined) && (missing55 = "rejected")){
const err468 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/4/properties/observation/oneOf/2/required",keyword:"required",params:{missingProperty: missing55},message:"must have required property '"+missing55+"'"};
if(vErrors === null){
vErrors = [err468];
}
else {
vErrors.push(err468);
}
errors++;
}
else {
const _errs450 = errors;
for(const key55 in data161){
if(!(key55 === "rejected")){
const err469 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/4/properties/observation/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key55},message:"must NOT have additional properties"};
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
if(_errs450 === errors){
if(data161.rejected !== undefined){
let data164 = data161.rejected;
const _errs451 = errors;
if(errors === _errs451){
if(typeof data164 === "string"){
if(func1(data164) > 512){
const err470 = {instancePath:instancePath+"/observation/rejected",schemaPath:"#/oneOf/4/properties/observation/oneOf/2/properties/rejected/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err470];
}
else {
vErrors.push(err470);
}
errors++;
}
else {
if(!pattern4.test(data164)){
const err471 = {instancePath:instancePath+"/observation/rejected",schemaPath:"#/oneOf/4/properties/observation/oneOf/2/properties/rejected/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
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
else {
const err472 = {instancePath:instancePath+"/observation/rejected",schemaPath:"#/oneOf/4/properties/observation/oneOf/2/properties/rejected/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
}
else {
const err473 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/4/properties/observation/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err473];
}
else {
vErrors.push(err473);
}
errors++;
}
}
var _valid10 = _errs448 === errors;
if(_valid10 && valid75){
valid75 = false;
passing5 = [passing5, 2];
}
else {
if(_valid10){
valid75 = true;
passing5 = 2;
if(props6 !== true){
props6 = true;
}
}
}
}
if(!valid75){
const err474 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/4/properties/observation/oneOf",keyword:"oneOf",params:{passingSchemas: passing5},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err474];
}
else {
vErrors.push(err474);
}
errors++;
}
else {
errors = _errs437;
if(vErrors !== null){
if(_errs437){
vErrors.length = _errs437;
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
const err475 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err475];
}
else {
vErrors.push(err475);
}
errors++;
}
}
var _valid0 = _errs433 === errors;
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
const _errs453 = errors;
if(errors === _errs453){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing56;
if((data.status === undefined) && (missing56 = "status")){
const err476 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing56},message:"must have required property '"+missing56+"'"};
if(vErrors === null){
vErrors = [err476];
}
else {
vErrors.push(err476);
}
errors++;
}
else {
const _errs455 = errors;
for(const key56 in data){
if(!(key56 === "status")){
const err477 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key56},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err477];
}
else {
vErrors.push(err477);
}
errors++;
break;
}
}
if(_errs455 === errors){
if(data.status !== undefined){
let data165 = data.status;
const _errs457 = errors;
let valid80 = false;
const _errs458 = errors;
if(errors === _errs458){
if(data165 && typeof data165 == "object" && !Array.isArray(data165)){
let missing57;
if((((((data165.reference === undefined) && (missing57 = "reference")) || ((data165.phase === undefined) && (missing57 = "phase"))) || ((data165.correlation === undefined) && (missing57 = "correlation"))) || ((data165.manifest === undefined) && (missing57 = "manifest"))) || ((data165.collected === undefined) && (missing57 = "collected"))){
const err478 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/5/properties/status/anyOf/0/required",keyword:"required",params:{missingProperty: missing57},message:"must have required property '"+missing57+"'"};
if(vErrors === null){
vErrors = [err478];
}
else {
vErrors.push(err478);
}
errors++;
}
else {
const _errs460 = errors;
for(const key57 in data165){
if(!(((((key57 === "reference") || (key57 === "phase")) || (key57 === "correlation")) || (key57 === "manifest")) || (key57 === "collected"))){
const err479 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/5/properties/status/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key57},message:"must NOT have additional properties"};
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
if(_errs460 === errors){
if(data165.reference !== undefined){
let data166 = data165.reference;
const _errs461 = errors;
if(errors === _errs461){
if(typeof data166 === "string"){
if(func1(data166) > 512){
const err480 = {instancePath:instancePath+"/status/reference",schemaPath:"#/oneOf/5/properties/status/anyOf/0/properties/reference/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err480];
}
else {
vErrors.push(err480);
}
errors++;
}
else {
if(!pattern4.test(data166)){
const err481 = {instancePath:instancePath+"/status/reference",schemaPath:"#/oneOf/5/properties/status/anyOf/0/properties/reference/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
if(vErrors === null){
vErrors = [err481];
}
else {
vErrors.push(err481);
}
errors++;
}
}
}
else {
const err482 = {instancePath:instancePath+"/status/reference",schemaPath:"#/oneOf/5/properties/status/anyOf/0/properties/reference/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err482];
}
else {
vErrors.push(err482);
}
errors++;
}
}
var valid81 = _errs461 === errors;
}
else {
var valid81 = true;
}
if(valid81){
if(data165.phase !== undefined){
let data167 = data165.phase;
const _errs463 = errors;
if(typeof data167 !== "string"){
const err483 = {instancePath:instancePath+"/status/phase",schemaPath:"#/oneOf/5/properties/status/anyOf/0/properties/phase/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err483];
}
else {
vErrors.push(err483);
}
errors++;
}
if(!((((((((data167 === "uploading") || (data167 === "sealed")) || (data167 === "admitted")) || (data167 === "complete")) || (data167 === "cancelled")) || (data167 === "denied")) || (data167 === "rejected")) || (data167 === "retired"))){
const err484 = {instancePath:instancePath+"/status/phase",schemaPath:"#/oneOf/5/properties/status/anyOf/0/properties/phase/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[5].properties.status.anyOf[0].properties.phase.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err484];
}
else {
vErrors.push(err484);
}
errors++;
}
var valid81 = _errs463 === errors;
}
else {
var valid81 = true;
}
if(valid81){
if(data165.correlation !== undefined){
let data168 = data165.correlation;
const _errs465 = errors;
if(errors === _errs465){
if(typeof data168 === "string"){
if(func1(data168) > 131072){
const err485 = {instancePath:instancePath+"/status/correlation",schemaPath:"#/oneOf/5/properties/status/anyOf/0/properties/correlation/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err485];
}
else {
vErrors.push(err485);
}
errors++;
}
}
else {
const err486 = {instancePath:instancePath+"/status/correlation",schemaPath:"#/oneOf/5/properties/status/anyOf/0/properties/correlation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err486];
}
else {
vErrors.push(err486);
}
errors++;
}
}
var valid81 = _errs465 === errors;
}
else {
var valid81 = true;
}
if(valid81){
if(data165.manifest !== undefined){
let data169 = data165.manifest;
const _errs467 = errors;
const _errs468 = errors;
let valid82 = false;
const _errs469 = errors;
if(errors === _errs469){
if(typeof data169 === "string"){
if(func1(data169) > 512){
const err487 = {instancePath:instancePath+"/status/manifest",schemaPath:"#/oneOf/5/properties/status/anyOf/0/properties/manifest/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err487];
}
else {
vErrors.push(err487);
}
errors++;
}
else {
if(!pattern4.test(data169)){
const err488 = {instancePath:instancePath+"/status/manifest",schemaPath:"#/oneOf/5/properties/status/anyOf/0/properties/manifest/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
if(vErrors === null){
vErrors = [err488];
}
else {
vErrors.push(err488);
}
errors++;
}
}
}
else {
const err489 = {instancePath:instancePath+"/status/manifest",schemaPath:"#/oneOf/5/properties/status/anyOf/0/properties/manifest/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err489];
}
else {
vErrors.push(err489);
}
errors++;
}
}
var _valid12 = _errs469 === errors;
valid82 = valid82 || _valid12;
const _errs471 = errors;
if(data169 !== null){
const err490 = {instancePath:instancePath+"/status/manifest",schemaPath:"#/oneOf/5/properties/status/anyOf/0/properties/manifest/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err490];
}
else {
vErrors.push(err490);
}
errors++;
}
var _valid12 = _errs471 === errors;
valid82 = valid82 || _valid12;
if(!valid82){
const err491 = {instancePath:instancePath+"/status/manifest",schemaPath:"#/oneOf/5/properties/status/anyOf/0/properties/manifest/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err491];
}
else {
vErrors.push(err491);
}
errors++;
}
else {
errors = _errs468;
if(vErrors !== null){
if(_errs468){
vErrors.length = _errs468;
}
else {
vErrors = null;
}
}
}
var valid81 = _errs467 === errors;
}
else {
var valid81 = true;
}
if(valid81){
if(data165.collected !== undefined){
const _errs473 = errors;
if(typeof data165.collected !== "boolean"){
const err492 = {instancePath:instancePath+"/status/collected",schemaPath:"#/oneOf/5/properties/status/anyOf/0/properties/collected/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err492];
}
else {
vErrors.push(err492);
}
errors++;
}
var valid81 = _errs473 === errors;
}
else {
var valid81 = true;
}
}
}
}
}
}
}
}
else {
const err493 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/5/properties/status/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err493];
}
else {
vErrors.push(err493);
}
errors++;
}
}
var _valid11 = _errs458 === errors;
valid80 = valid80 || _valid11;
const _errs475 = errors;
if(data165 !== null){
const err494 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/5/properties/status/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err494];
}
else {
vErrors.push(err494);
}
errors++;
}
var _valid11 = _errs475 === errors;
valid80 = valid80 || _valid11;
if(!valid80){
const err495 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/5/properties/status/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err495];
}
else {
vErrors.push(err495);
}
errors++;
}
else {
errors = _errs457;
if(vErrors !== null){
if(_errs457){
vErrors.length = _errs457;
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
const err496 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err496];
}
else {
vErrors.push(err496);
}
errors++;
}
}
var _valid0 = _errs453 === errors;
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
const _errs477 = errors;
if(errors === _errs477){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing58;
if((data.page === undefined) && (missing58 = "page")){
const err497 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing58},message:"must have required property '"+missing58+"'"};
if(vErrors === null){
vErrors = [err497];
}
else {
vErrors.push(err497);
}
errors++;
}
else {
const _errs479 = errors;
for(const key58 in data){
if(!(key58 === "page")){
const err498 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key58},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err498];
}
else {
vErrors.push(err498);
}
errors++;
break;
}
}
if(_errs479 === errors){
if(data.page !== undefined){
let data171 = data.page;
const _errs480 = errors;
if(errors === _errs480){
if(data171 && typeof data171 == "object" && !Array.isArray(data171)){
let missing59;
if(((data171.evidence === undefined) && (missing59 = "evidence")) || ((data171.cells === undefined) && (missing59 = "cells"))){
const err499 = {instancePath:instancePath+"/page",schemaPath:"#/oneOf/6/properties/page/required",keyword:"required",params:{missingProperty: missing59},message:"must have required property '"+missing59+"'"};
if(vErrors === null){
vErrors = [err499];
}
else {
vErrors.push(err499);
}
errors++;
}
else {
const _errs482 = errors;
for(const key59 in data171){
if(!((key59 === "evidence") || (key59 === "cells"))){
const err500 = {instancePath:instancePath+"/page",schemaPath:"#/oneOf/6/properties/page/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key59},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err500];
}
else {
vErrors.push(err500);
}
errors++;
break;
}
}
if(_errs482 === errors){
if(data171.evidence !== undefined){
let data172 = data171.evidence;
const _errs483 = errors;
if(errors === _errs483){
if(data172 && typeof data172 == "object" && !Array.isArray(data172)){
let missing60;
if(((((((data172.manifest === undefined) && (missing60 = "manifest")) || ((data172.columns === undefined) && (missing60 = "columns"))) || ((data172.ordinal === undefined) && (missing60 = "ordinal"))) || ((data172.rows === undefined) && (missing60 = "rows"))) || ((data172.ipc === undefined) && (missing60 = "ipc"))) || ((data172.next === undefined) && (missing60 = "next"))){
const err501 = {instancePath:instancePath+"/page/evidence",schemaPath:"#/oneOf/6/properties/page/properties/evidence/required",keyword:"required",params:{missingProperty: missing60},message:"must have required property '"+missing60+"'"};
if(vErrors === null){
vErrors = [err501];
}
else {
vErrors.push(err501);
}
errors++;
}
else {
const _errs485 = errors;
for(const key60 in data172){
if(!((((((key60 === "manifest") || (key60 === "columns")) || (key60 === "ordinal")) || (key60 === "rows")) || (key60 === "ipc")) || (key60 === "next"))){
const err502 = {instancePath:instancePath+"/page/evidence",schemaPath:"#/oneOf/6/properties/page/properties/evidence/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key60},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err502];
}
else {
vErrors.push(err502);
}
errors++;
break;
}
}
if(_errs485 === errors){
if(data172.manifest !== undefined){
let data173 = data172.manifest;
const _errs486 = errors;
if(errors === _errs486){
if(data173 && typeof data173 == "object" && !Array.isArray(data173)){
let missing61;
if((((((((((((((((((data173.job === undefined) && (missing61 = "job")) || ((data173.source === undefined) && (missing61 = "source"))) || ((data173.requester === undefined) && (missing61 = "requester"))) || ((data173.correlation === undefined) && (missing61 = "correlation"))) || ((data173.policy_revision === undefined) && (missing61 = "policy_revision"))) || ((data173.request === undefined) && (missing61 = "request"))) || ((data173.basis === undefined) && (missing61 = "basis"))) || ((data173.plan === undefined) && (missing61 = "plan"))) || ((data173.pages === undefined) && (missing61 = "pages"))) || ((data173.scanned === undefined) && (missing61 = "scanned"))) || ((data173.selected === undefined) && (missing61 = "selected"))) || ((data173.segments === undefined) && (missing61 = "segments"))) || ((data173.rows === undefined) && (missing61 = "rows"))) || ((data173.bytes === undefined) && (missing61 = "bytes"))) || ((data173.sum === undefined) && (missing61 = "sum"))) || ((data173.finished === undefined) && (missing61 = "finished"))) || ((data173.chain === undefined) && (missing61 = "chain"))){
const err503 = {instancePath:instancePath+"/page/evidence/manifest",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/required",keyword:"required",params:{missingProperty: missing61},message:"must have required property '"+missing61+"'"};
if(vErrors === null){
vErrors = [err503];
}
else {
vErrors.push(err503);
}
errors++;
}
else {
const _errs488 = errors;
for(const key61 in data173){
if(!(func16.call(schema33.oneOf[6].properties.page.properties.evidence.properties.manifest.properties, key61))){
const err504 = {instancePath:instancePath+"/page/evidence/manifest",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key61},message:"must NOT have additional properties"};
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
if(_errs488 === errors){
if(data173.job !== undefined){
let data174 = data173.job;
const _errs489 = errors;
if(!(((typeof data174 == "number") && (!(data174 % 1) && !isNaN(data174))) && (isFinite(data174)))){
const err505 = {instancePath:instancePath+"/page/evidence/manifest/job",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/job/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err505];
}
else {
vErrors.push(err505);
}
errors++;
}
if(errors === _errs489){
if((typeof data174 == "number") && (isFinite(data174))){
if(data174 > 9007199254740991 || isNaN(data174)){
const err506 = {instancePath:instancePath+"/page/evidence/manifest/job",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/job/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err506];
}
else {
vErrors.push(err506);
}
errors++;
}
else {
if(data174 < 0 || isNaN(data174)){
const err507 = {instancePath:instancePath+"/page/evidence/manifest/job",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/job/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err507];
}
else {
vErrors.push(err507);
}
errors++;
}
}
}
}
var valid86 = _errs489 === errors;
}
else {
var valid86 = true;
}
if(valid86){
if(data173.source !== undefined){
let data175 = data173.source;
const _errs491 = errors;
if(errors === _errs491){
if(data175 && typeof data175 == "object" && !Array.isArray(data175)){
let missing62;
if((((data175.pid === undefined) && (missing62 = "pid")) || ((data175.input === undefined) && (missing62 = "input"))) || ((data175.index === undefined) && (missing62 = "index"))){
const err508 = {instancePath:instancePath+"/page/evidence/manifest/source",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/source/required",keyword:"required",params:{missingProperty: missing62},message:"must have required property '"+missing62+"'"};
if(vErrors === null){
vErrors = [err508];
}
else {
vErrors.push(err508);
}
errors++;
}
else {
const _errs493 = errors;
for(const key62 in data175){
if(!(((key62 === "pid") || (key62 === "input")) || (key62 === "index"))){
const err509 = {instancePath:instancePath+"/page/evidence/manifest/source",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/source/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key62},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err509];
}
else {
vErrors.push(err509);
}
errors++;
break;
}
}
if(_errs493 === errors){
if(data175.pid !== undefined){
let data176 = data175.pid;
const _errs494 = errors;
if(!(((typeof data176 == "number") && (!(data176 % 1) && !isNaN(data176))) && (isFinite(data176)))){
const err510 = {instancePath:instancePath+"/page/evidence/manifest/source/pid",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/source/properties/pid/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err510];
}
else {
vErrors.push(err510);
}
errors++;
}
if(errors === _errs494){
if((typeof data176 == "number") && (isFinite(data176))){
if(data176 > 9007199254740991 || isNaN(data176)){
const err511 = {instancePath:instancePath+"/page/evidence/manifest/source/pid",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/source/properties/pid/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err511];
}
else {
vErrors.push(err511);
}
errors++;
}
else {
if(data176 < 0 || isNaN(data176)){
const err512 = {instancePath:instancePath+"/page/evidence/manifest/source/pid",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/source/properties/pid/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err512];
}
else {
vErrors.push(err512);
}
errors++;
}
}
}
}
var valid87 = _errs494 === errors;
}
else {
var valid87 = true;
}
if(valid87){
if(data175.input !== undefined){
let data177 = data175.input;
const _errs496 = errors;
if(!(((typeof data177 == "number") && (!(data177 % 1) && !isNaN(data177))) && (isFinite(data177)))){
const err513 = {instancePath:instancePath+"/page/evidence/manifest/source/input",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/source/properties/input/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err513];
}
else {
vErrors.push(err513);
}
errors++;
}
if(errors === _errs496){
if((typeof data177 == "number") && (isFinite(data177))){
if(data177 > 9007199254740991 || isNaN(data177)){
const err514 = {instancePath:instancePath+"/page/evidence/manifest/source/input",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/source/properties/input/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err514];
}
else {
vErrors.push(err514);
}
errors++;
}
else {
if(data177 < 0 || isNaN(data177)){
const err515 = {instancePath:instancePath+"/page/evidence/manifest/source/input",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/source/properties/input/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err515];
}
else {
vErrors.push(err515);
}
errors++;
}
}
}
}
var valid87 = _errs496 === errors;
}
else {
var valid87 = true;
}
if(valid87){
if(data175.index !== undefined){
let data178 = data175.index;
const _errs498 = errors;
if(!(((typeof data178 == "number") && (!(data178 % 1) && !isNaN(data178))) && (isFinite(data178)))){
const err516 = {instancePath:instancePath+"/page/evidence/manifest/source/index",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/source/properties/index/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err516];
}
else {
vErrors.push(err516);
}
errors++;
}
if(errors === _errs498){
if((typeof data178 == "number") && (isFinite(data178))){
if(data178 > 255 || isNaN(data178)){
const err517 = {instancePath:instancePath+"/page/evidence/manifest/source/index",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/source/properties/index/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err517];
}
else {
vErrors.push(err517);
}
errors++;
}
else {
if(data178 < 0 || isNaN(data178)){
const err518 = {instancePath:instancePath+"/page/evidence/manifest/source/index",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/source/properties/index/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid87 = _errs498 === errors;
}
else {
var valid87 = true;
}
}
}
}
}
}
else {
const err519 = {instancePath:instancePath+"/page/evidence/manifest/source",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/source/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err519];
}
else {
vErrors.push(err519);
}
errors++;
}
}
var valid86 = _errs491 === errors;
}
else {
var valid86 = true;
}
if(valid86){
if(data173.requester !== undefined){
let data179 = data173.requester;
const _errs500 = errors;
if(!(((typeof data179 == "number") && (!(data179 % 1) && !isNaN(data179))) && (isFinite(data179)))){
const err520 = {instancePath:instancePath+"/page/evidence/manifest/requester",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/requester/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err520];
}
else {
vErrors.push(err520);
}
errors++;
}
if(errors === _errs500){
if((typeof data179 == "number") && (isFinite(data179))){
if(data179 > 9007199254740991 || isNaN(data179)){
const err521 = {instancePath:instancePath+"/page/evidence/manifest/requester",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/requester/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err521];
}
else {
vErrors.push(err521);
}
errors++;
}
else {
if(data179 < 0 || isNaN(data179)){
const err522 = {instancePath:instancePath+"/page/evidence/manifest/requester",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/requester/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid86 = _errs500 === errors;
}
else {
var valid86 = true;
}
if(valid86){
if(data173.correlation !== undefined){
let data180 = data173.correlation;
const _errs502 = errors;
if(errors === _errs502){
if(typeof data180 === "string"){
if(func1(data180) > 131072){
const err523 = {instancePath:instancePath+"/page/evidence/manifest/correlation",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/correlation/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err523];
}
else {
vErrors.push(err523);
}
errors++;
}
}
else {
const err524 = {instancePath:instancePath+"/page/evidence/manifest/correlation",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/correlation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err524];
}
else {
vErrors.push(err524);
}
errors++;
}
}
var valid86 = _errs502 === errors;
}
else {
var valid86 = true;
}
if(valid86){
if(data173.policy_revision !== undefined){
let data181 = data173.policy_revision;
const _errs504 = errors;
if(errors === _errs504){
if(typeof data181 === "string"){
if(func1(data181) > 131072){
const err525 = {instancePath:instancePath+"/page/evidence/manifest/policy_revision",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/policy_revision/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err525];
}
else {
vErrors.push(err525);
}
errors++;
}
}
else {
const err526 = {instancePath:instancePath+"/page/evidence/manifest/policy_revision",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/policy_revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err526];
}
else {
vErrors.push(err526);
}
errors++;
}
}
var valid86 = _errs504 === errors;
}
else {
var valid86 = true;
}
if(valid86){
if(data173.request !== undefined){
let data182 = data173.request;
const _errs506 = errors;
if(errors === _errs506){
if(typeof data182 === "string"){
if(func1(data182) > 512){
const err527 = {instancePath:instancePath+"/page/evidence/manifest/request",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/request/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err527];
}
else {
vErrors.push(err527);
}
errors++;
}
else {
if(!pattern4.test(data182)){
const err528 = {instancePath:instancePath+"/page/evidence/manifest/request",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/request/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
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
else {
const err529 = {instancePath:instancePath+"/page/evidence/manifest/request",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/request/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err529];
}
else {
vErrors.push(err529);
}
errors++;
}
}
var valid86 = _errs506 === errors;
}
else {
var valid86 = true;
}
if(valid86){
if(data173.basis !== undefined){
let data183 = data173.basis;
const _errs508 = errors;
if(errors === _errs508){
if(data183 && typeof data183 == "object" && !Array.isArray(data183)){
let missing63;
if((((((data183.kind === undefined) && (missing63 = "kind")) || ((data183.resource === undefined) && (missing63 = "resource"))) || ((data183.revision === undefined) && (missing63 = "revision"))) || ((data183.contract === undefined) && (missing63 = "contract"))) || ((data183.schema === undefined) && (missing63 = "schema"))){
const err530 = {instancePath:instancePath+"/page/evidence/manifest/basis",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/basis/required",keyword:"required",params:{missingProperty: missing63},message:"must have required property '"+missing63+"'"};
if(vErrors === null){
vErrors = [err530];
}
else {
vErrors.push(err530);
}
errors++;
}
else {
const _errs510 = errors;
for(const key63 in data183){
if(!(((((key63 === "kind") || (key63 === "resource")) || (key63 === "revision")) || (key63 === "contract")) || (key63 === "schema"))){
const err531 = {instancePath:instancePath+"/page/evidence/manifest/basis",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/basis/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key63},message:"must NOT have additional properties"};
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
if(_errs510 === errors){
if(data183.kind !== undefined){
let data184 = data183.kind;
const _errs511 = errors;
if(typeof data184 !== "string"){
const err532 = {instancePath:instancePath+"/page/evidence/manifest/basis/kind",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/basis/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err532];
}
else {
vErrors.push(err532);
}
errors++;
}
if(!(((data184 === "kv") || (data184 === "table")) || (data184 === "document"))){
const err533 = {instancePath:instancePath+"/page/evidence/manifest/basis/kind",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/basis/properties/kind/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[6].properties.page.properties.evidence.properties.manifest.properties.basis.properties.kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err533];
}
else {
vErrors.push(err533);
}
errors++;
}
var valid88 = _errs511 === errors;
}
else {
var valid88 = true;
}
if(valid88){
if(data183.resource !== undefined){
let data185 = data183.resource;
const _errs513 = errors;
if(!(((typeof data185 == "number") && (!(data185 % 1) && !isNaN(data185))) && (isFinite(data185)))){
const err534 = {instancePath:instancePath+"/page/evidence/manifest/basis/resource",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/basis/properties/resource/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err534];
}
else {
vErrors.push(err534);
}
errors++;
}
if(errors === _errs513){
if((typeof data185 == "number") && (isFinite(data185))){
if(data185 > 9007199254740991 || isNaN(data185)){
const err535 = {instancePath:instancePath+"/page/evidence/manifest/basis/resource",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/basis/properties/resource/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err535];
}
else {
vErrors.push(err535);
}
errors++;
}
else {
if(data185 < 0 || isNaN(data185)){
const err536 = {instancePath:instancePath+"/page/evidence/manifest/basis/resource",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/basis/properties/resource/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err536];
}
else {
vErrors.push(err536);
}
errors++;
}
}
}
}
var valid88 = _errs513 === errors;
}
else {
var valid88 = true;
}
if(valid88){
if(data183.revision !== undefined){
let data186 = data183.revision;
const _errs515 = errors;
if(!(((typeof data186 == "number") && (!(data186 % 1) && !isNaN(data186))) && (isFinite(data186)))){
const err537 = {instancePath:instancePath+"/page/evidence/manifest/basis/revision",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/basis/properties/revision/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err537];
}
else {
vErrors.push(err537);
}
errors++;
}
if(errors === _errs515){
if((typeof data186 == "number") && (isFinite(data186))){
if(data186 > 9007199254740991 || isNaN(data186)){
const err538 = {instancePath:instancePath+"/page/evidence/manifest/basis/revision",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/basis/properties/revision/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err538];
}
else {
vErrors.push(err538);
}
errors++;
}
else {
if(data186 < 0 || isNaN(data186)){
const err539 = {instancePath:instancePath+"/page/evidence/manifest/basis/revision",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/basis/properties/revision/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err539];
}
else {
vErrors.push(err539);
}
errors++;
}
}
}
}
var valid88 = _errs515 === errors;
}
else {
var valid88 = true;
}
if(valid88){
if(data183.contract !== undefined){
let data187 = data183.contract;
const _errs517 = errors;
if(errors === _errs517){
if(Array.isArray(data187)){
if(data187.length > 32){
const err540 = {instancePath:instancePath+"/page/evidence/manifest/basis/contract",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/basis/properties/contract/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err540];
}
else {
vErrors.push(err540);
}
errors++;
}
else {
if(data187.length < 32){
const err541 = {instancePath:instancePath+"/page/evidence/manifest/basis/contract",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/basis/properties/contract/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err541];
}
else {
vErrors.push(err541);
}
errors++;
}
else {
var valid89 = true;
const len12 = data187.length;
for(let i12=0; i12<len12; i12++){
let data188 = data187[i12];
const _errs519 = errors;
if(!(((typeof data188 == "number") && (!(data188 % 1) && !isNaN(data188))) && (isFinite(data188)))){
const err542 = {instancePath:instancePath+"/page/evidence/manifest/basis/contract/" + i12,schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/basis/properties/contract/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err542];
}
else {
vErrors.push(err542);
}
errors++;
}
if(errors === _errs519){
if((typeof data188 == "number") && (isFinite(data188))){
if(data188 > 255 || isNaN(data188)){
const err543 = {instancePath:instancePath+"/page/evidence/manifest/basis/contract/" + i12,schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/basis/properties/contract/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err543];
}
else {
vErrors.push(err543);
}
errors++;
}
else {
if(data188 < 0 || isNaN(data188)){
const err544 = {instancePath:instancePath+"/page/evidence/manifest/basis/contract/" + i12,schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/basis/properties/contract/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid89 = _errs519 === errors;
if(!valid89){
break;
}
}
}
}
}
else {
const err545 = {instancePath:instancePath+"/page/evidence/manifest/basis/contract",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/basis/properties/contract/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err545];
}
else {
vErrors.push(err545);
}
errors++;
}
}
var valid88 = _errs517 === errors;
}
else {
var valid88 = true;
}
if(valid88){
if(data183.schema !== undefined){
let data189 = data183.schema;
const _errs521 = errors;
if(errors === _errs521){
if(Array.isArray(data189)){
if(data189.length > 32){
const err546 = {instancePath:instancePath+"/page/evidence/manifest/basis/schema",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/basis/properties/schema/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err546];
}
else {
vErrors.push(err546);
}
errors++;
}
else {
if(data189.length < 32){
const err547 = {instancePath:instancePath+"/page/evidence/manifest/basis/schema",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/basis/properties/schema/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err547];
}
else {
vErrors.push(err547);
}
errors++;
}
else {
var valid90 = true;
const len13 = data189.length;
for(let i13=0; i13<len13; i13++){
let data190 = data189[i13];
const _errs523 = errors;
if(!(((typeof data190 == "number") && (!(data190 % 1) && !isNaN(data190))) && (isFinite(data190)))){
const err548 = {instancePath:instancePath+"/page/evidence/manifest/basis/schema/" + i13,schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/basis/properties/schema/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err548];
}
else {
vErrors.push(err548);
}
errors++;
}
if(errors === _errs523){
if((typeof data190 == "number") && (isFinite(data190))){
if(data190 > 255 || isNaN(data190)){
const err549 = {instancePath:instancePath+"/page/evidence/manifest/basis/schema/" + i13,schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/basis/properties/schema/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err549];
}
else {
vErrors.push(err549);
}
errors++;
}
else {
if(data190 < 0 || isNaN(data190)){
const err550 = {instancePath:instancePath+"/page/evidence/manifest/basis/schema/" + i13,schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/basis/properties/schema/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err550];
}
else {
vErrors.push(err550);
}
errors++;
}
}
}
}
var valid90 = _errs523 === errors;
if(!valid90){
break;
}
}
}
}
}
else {
const err551 = {instancePath:instancePath+"/page/evidence/manifest/basis/schema",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/basis/properties/schema/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err551];
}
else {
vErrors.push(err551);
}
errors++;
}
}
var valid88 = _errs521 === errors;
}
else {
var valid88 = true;
}
}
}
}
}
}
}
}
else {
const err552 = {instancePath:instancePath+"/page/evidence/manifest/basis",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/basis/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err552];
}
else {
vErrors.push(err552);
}
errors++;
}
}
var valid86 = _errs508 === errors;
}
else {
var valid86 = true;
}
if(valid86){
if(data173.plan !== undefined){
let data191 = data173.plan;
const _errs525 = errors;
if(errors === _errs525){
if(Array.isArray(data191)){
if(data191.length > 32){
const err553 = {instancePath:instancePath+"/page/evidence/manifest/plan",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/plan/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err553];
}
else {
vErrors.push(err553);
}
errors++;
}
else {
if(data191.length < 32){
const err554 = {instancePath:instancePath+"/page/evidence/manifest/plan",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/plan/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err554];
}
else {
vErrors.push(err554);
}
errors++;
}
else {
var valid91 = true;
const len14 = data191.length;
for(let i14=0; i14<len14; i14++){
let data192 = data191[i14];
const _errs527 = errors;
if(!(((typeof data192 == "number") && (!(data192 % 1) && !isNaN(data192))) && (isFinite(data192)))){
const err555 = {instancePath:instancePath+"/page/evidence/manifest/plan/" + i14,schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/plan/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err555];
}
else {
vErrors.push(err555);
}
errors++;
}
if(errors === _errs527){
if((typeof data192 == "number") && (isFinite(data192))){
if(data192 > 255 || isNaN(data192)){
const err556 = {instancePath:instancePath+"/page/evidence/manifest/plan/" + i14,schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/plan/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err556];
}
else {
vErrors.push(err556);
}
errors++;
}
else {
if(data192 < 0 || isNaN(data192)){
const err557 = {instancePath:instancePath+"/page/evidence/manifest/plan/" + i14,schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/plan/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid91 = _errs527 === errors;
if(!valid91){
break;
}
}
}
}
}
else {
const err558 = {instancePath:instancePath+"/page/evidence/manifest/plan",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/plan/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err558];
}
else {
vErrors.push(err558);
}
errors++;
}
}
var valid86 = _errs525 === errors;
}
else {
var valid86 = true;
}
if(valid86){
if(data173.pages !== undefined){
let data193 = data173.pages;
const _errs529 = errors;
if(errors === _errs529){
if(typeof data193 === "string"){
if(func1(data193) > 131072){
const err559 = {instancePath:instancePath+"/page/evidence/manifest/pages",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/pages/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err559];
}
else {
vErrors.push(err559);
}
errors++;
}
}
else {
const err560 = {instancePath:instancePath+"/page/evidence/manifest/pages",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/pages/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err560];
}
else {
vErrors.push(err560);
}
errors++;
}
}
var valid86 = _errs529 === errors;
}
else {
var valid86 = true;
}
if(valid86){
if(data173.scanned !== undefined){
let data194 = data173.scanned;
const _errs531 = errors;
if(errors === _errs531){
if(typeof data194 === "string"){
if(func1(data194) > 131072){
const err561 = {instancePath:instancePath+"/page/evidence/manifest/scanned",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/scanned/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err562 = {instancePath:instancePath+"/page/evidence/manifest/scanned",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/scanned/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err562];
}
else {
vErrors.push(err562);
}
errors++;
}
}
var valid86 = _errs531 === errors;
}
else {
var valid86 = true;
}
if(valid86){
if(data173.selected !== undefined){
let data195 = data173.selected;
const _errs533 = errors;
if(errors === _errs533){
if(typeof data195 === "string"){
if(func1(data195) > 131072){
const err563 = {instancePath:instancePath+"/page/evidence/manifest/selected",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/selected/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err564 = {instancePath:instancePath+"/page/evidence/manifest/selected",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/selected/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err564];
}
else {
vErrors.push(err564);
}
errors++;
}
}
var valid86 = _errs533 === errors;
}
else {
var valid86 = true;
}
if(valid86){
if(data173.segments !== undefined){
let data196 = data173.segments;
const _errs535 = errors;
if(errors === _errs535){
if(typeof data196 === "string"){
if(func1(data196) > 131072){
const err565 = {instancePath:instancePath+"/page/evidence/manifest/segments",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/segments/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err565];
}
else {
vErrors.push(err565);
}
errors++;
}
}
else {
const err566 = {instancePath:instancePath+"/page/evidence/manifest/segments",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/segments/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err566];
}
else {
vErrors.push(err566);
}
errors++;
}
}
var valid86 = _errs535 === errors;
}
else {
var valid86 = true;
}
if(valid86){
if(data173.rows !== undefined){
let data197 = data173.rows;
const _errs537 = errors;
if(errors === _errs537){
if(typeof data197 === "string"){
if(func1(data197) > 131072){
const err567 = {instancePath:instancePath+"/page/evidence/manifest/rows",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/rows/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err568 = {instancePath:instancePath+"/page/evidence/manifest/rows",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/rows/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err568];
}
else {
vErrors.push(err568);
}
errors++;
}
}
var valid86 = _errs537 === errors;
}
else {
var valid86 = true;
}
if(valid86){
if(data173.bytes !== undefined){
let data198 = data173.bytes;
const _errs539 = errors;
if(errors === _errs539){
if(typeof data198 === "string"){
if(func1(data198) > 131072){
const err569 = {instancePath:instancePath+"/page/evidence/manifest/bytes",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/bytes/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err569];
}
else {
vErrors.push(err569);
}
errors++;
}
}
else {
const err570 = {instancePath:instancePath+"/page/evidence/manifest/bytes",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/bytes/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err570];
}
else {
vErrors.push(err570);
}
errors++;
}
}
var valid86 = _errs539 === errors;
}
else {
var valid86 = true;
}
if(valid86){
if(data173.sum !== undefined){
let data199 = data173.sum;
const _errs541 = errors;
const _errs542 = errors;
let valid92 = false;
const _errs543 = errors;
if(errors === _errs543){
if(typeof data199 === "string"){
if(func1(data199) > 131072){
const err571 = {instancePath:instancePath+"/page/evidence/manifest/sum",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/sum/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err572 = {instancePath:instancePath+"/page/evidence/manifest/sum",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/sum/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err572];
}
else {
vErrors.push(err572);
}
errors++;
}
}
var _valid13 = _errs543 === errors;
valid92 = valid92 || _valid13;
const _errs545 = errors;
if(data199 !== null){
const err573 = {instancePath:instancePath+"/page/evidence/manifest/sum",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/sum/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err573];
}
else {
vErrors.push(err573);
}
errors++;
}
var _valid13 = _errs545 === errors;
valid92 = valid92 || _valid13;
if(!valid92){
const err574 = {instancePath:instancePath+"/page/evidence/manifest/sum",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/sum/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err574];
}
else {
vErrors.push(err574);
}
errors++;
}
else {
errors = _errs542;
if(vErrors !== null){
if(_errs542){
vErrors.length = _errs542;
}
else {
vErrors = null;
}
}
}
var valid86 = _errs541 === errors;
}
else {
var valid86 = true;
}
if(valid86){
if(data173.finished !== undefined){
let data200 = data173.finished;
const _errs547 = errors;
const _errs548 = errors;
let valid93 = false;
const _errs549 = errors;
if(typeof data200 !== "string"){
const err575 = {instancePath:instancePath+"/page/evidence/manifest/finished",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/finished/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err575];
}
else {
vErrors.push(err575);
}
errors++;
}
if(!((data200 === "source_end") || (data200 === "limit"))){
const err576 = {instancePath:instancePath+"/page/evidence/manifest/finished",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/finished/anyOf/0/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[6].properties.page.properties.evidence.properties.manifest.properties.finished.anyOf[0].enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err576];
}
else {
vErrors.push(err576);
}
errors++;
}
var _valid14 = _errs549 === errors;
valid93 = valid93 || _valid14;
const _errs551 = errors;
if(data200 !== null){
const err577 = {instancePath:instancePath+"/page/evidence/manifest/finished",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/finished/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err577];
}
else {
vErrors.push(err577);
}
errors++;
}
var _valid14 = _errs551 === errors;
valid93 = valid93 || _valid14;
if(!valid93){
const err578 = {instancePath:instancePath+"/page/evidence/manifest/finished",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/finished/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err578];
}
else {
vErrors.push(err578);
}
errors++;
}
else {
errors = _errs548;
if(vErrors !== null){
if(_errs548){
vErrors.length = _errs548;
}
else {
vErrors = null;
}
}
}
var valid86 = _errs547 === errors;
}
else {
var valid86 = true;
}
if(valid86){
if(data173.chain !== undefined){
let data201 = data173.chain;
const _errs553 = errors;
if(errors === _errs553){
if(Array.isArray(data201)){
if(data201.length > 32){
const err579 = {instancePath:instancePath+"/page/evidence/manifest/chain",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/chain/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err579];
}
else {
vErrors.push(err579);
}
errors++;
}
else {
if(data201.length < 32){
const err580 = {instancePath:instancePath+"/page/evidence/manifest/chain",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/chain/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err580];
}
else {
vErrors.push(err580);
}
errors++;
}
else {
var valid94 = true;
const len15 = data201.length;
for(let i15=0; i15<len15; i15++){
let data202 = data201[i15];
const _errs555 = errors;
if(!(((typeof data202 == "number") && (!(data202 % 1) && !isNaN(data202))) && (isFinite(data202)))){
const err581 = {instancePath:instancePath+"/page/evidence/manifest/chain/" + i15,schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/chain/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err581];
}
else {
vErrors.push(err581);
}
errors++;
}
if(errors === _errs555){
if((typeof data202 == "number") && (isFinite(data202))){
if(data202 > 255 || isNaN(data202)){
const err582 = {instancePath:instancePath+"/page/evidence/manifest/chain/" + i15,schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/chain/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err582];
}
else {
vErrors.push(err582);
}
errors++;
}
else {
if(data202 < 0 || isNaN(data202)){
const err583 = {instancePath:instancePath+"/page/evidence/manifest/chain/" + i15,schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/chain/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid94 = _errs555 === errors;
if(!valid94){
break;
}
}
}
}
}
else {
const err584 = {instancePath:instancePath+"/page/evidence/manifest/chain",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/properties/chain/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err584];
}
else {
vErrors.push(err584);
}
errors++;
}
}
var valid86 = _errs553 === errors;
}
else {
var valid86 = true;
}
}
}
}
}
}
}
}
}
}
}
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
const err585 = {instancePath:instancePath+"/page/evidence/manifest",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/manifest/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err585];
}
else {
vErrors.push(err585);
}
errors++;
}
}
var valid85 = _errs486 === errors;
}
else {
var valid85 = true;
}
if(valid85){
if(data172.columns !== undefined){
let data203 = data172.columns;
const _errs557 = errors;
if(errors === _errs557){
if(Array.isArray(data203)){
if(data203.length > 8){
const err586 = {instancePath:instancePath+"/page/evidence/columns",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/columns/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err586];
}
else {
vErrors.push(err586);
}
errors++;
}
else {
var valid95 = true;
const len16 = data203.length;
for(let i16=0; i16<len16; i16++){
let data204 = data203[i16];
const _errs559 = errors;
if(errors === _errs559){
if(data204 && typeof data204 == "object" && !Array.isArray(data204)){
let missing64;
if(((data204.name === undefined) && (missing64 = "name")) || ((data204.type === undefined) && (missing64 = "type"))){
const err587 = {instancePath:instancePath+"/page/evidence/columns/" + i16,schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/columns/items/required",keyword:"required",params:{missingProperty: missing64},message:"must have required property '"+missing64+"'"};
if(vErrors === null){
vErrors = [err587];
}
else {
vErrors.push(err587);
}
errors++;
}
else {
const _errs561 = errors;
for(const key64 in data204){
if(!((key64 === "name") || (key64 === "type"))){
const err588 = {instancePath:instancePath+"/page/evidence/columns/" + i16,schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/columns/items/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key64},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err588];
}
else {
vErrors.push(err588);
}
errors++;
break;
}
}
if(_errs561 === errors){
if(data204.name !== undefined){
let data205 = data204.name;
const _errs562 = errors;
if(errors === _errs562){
if(typeof data205 === "string"){
if(func1(data205) > 131072){
const err589 = {instancePath:instancePath+"/page/evidence/columns/" + i16+"/name",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/columns/items/properties/name/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err589];
}
else {
vErrors.push(err589);
}
errors++;
}
}
else {
const err590 = {instancePath:instancePath+"/page/evidence/columns/" + i16+"/name",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/columns/items/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err590];
}
else {
vErrors.push(err590);
}
errors++;
}
}
var valid96 = _errs562 === errors;
}
else {
var valid96 = true;
}
if(valid96){
if(data204.type !== undefined){
let data206 = data204.type;
const _errs564 = errors;
if(typeof data206 !== "string"){
const err591 = {instancePath:instancePath+"/page/evidence/columns/" + i16+"/type",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/columns/items/properties/type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err591];
}
else {
vErrors.push(err591);
}
errors++;
}
if(!((((((data206 === "int64") || (data206 === "uint64")) || (data206 === "float64")) || (data206 === "boolean")) || (data206 === "utf8")) || (data206 === "binary"))){
const err592 = {instancePath:instancePath+"/page/evidence/columns/" + i16+"/type",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/columns/items/properties/type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[6].properties.page.properties.evidence.properties.columns.items.properties.type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err592];
}
else {
vErrors.push(err592);
}
errors++;
}
var valid96 = _errs564 === errors;
}
else {
var valid96 = true;
}
}
}
}
}
else {
const err593 = {instancePath:instancePath+"/page/evidence/columns/" + i16,schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/columns/items/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err593];
}
else {
vErrors.push(err593);
}
errors++;
}
}
var valid95 = _errs559 === errors;
if(!valid95){
break;
}
}
}
}
else {
const err594 = {instancePath:instancePath+"/page/evidence/columns",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/columns/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err594];
}
else {
vErrors.push(err594);
}
errors++;
}
}
var valid85 = _errs557 === errors;
}
else {
var valid85 = true;
}
if(valid85){
if(data172.ordinal !== undefined){
let data207 = data172.ordinal;
const _errs566 = errors;
if(errors === _errs566){
if(typeof data207 === "string"){
if(func1(data207) > 131072){
const err595 = {instancePath:instancePath+"/page/evidence/ordinal",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/ordinal/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err595];
}
else {
vErrors.push(err595);
}
errors++;
}
}
else {
const err596 = {instancePath:instancePath+"/page/evidence/ordinal",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/ordinal/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err596];
}
else {
vErrors.push(err596);
}
errors++;
}
}
var valid85 = _errs566 === errors;
}
else {
var valid85 = true;
}
if(valid85){
if(data172.rows !== undefined){
let data208 = data172.rows;
const _errs568 = errors;
if(!(((typeof data208 == "number") && (!(data208 % 1) && !isNaN(data208))) && (isFinite(data208)))){
const err597 = {instancePath:instancePath+"/page/evidence/rows",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/rows/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err597];
}
else {
vErrors.push(err597);
}
errors++;
}
if(errors === _errs568){
if((typeof data208 == "number") && (isFinite(data208))){
if(data208 > 255 || isNaN(data208)){
const err598 = {instancePath:instancePath+"/page/evidence/rows",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/rows/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err598];
}
else {
vErrors.push(err598);
}
errors++;
}
else {
if(data208 < 0 || isNaN(data208)){
const err599 = {instancePath:instancePath+"/page/evidence/rows",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/rows/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err599];
}
else {
vErrors.push(err599);
}
errors++;
}
}
}
}
var valid85 = _errs568 === errors;
}
else {
var valid85 = true;
}
if(valid85){
if(data172.ipc !== undefined){
let data209 = data172.ipc;
const _errs570 = errors;
if(errors === _errs570){
if(typeof data209 === "string"){
if(func1(data209) > 131072){
const err600 = {instancePath:instancePath+"/page/evidence/ipc",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/ipc/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err600];
}
else {
vErrors.push(err600);
}
errors++;
}
}
else {
const err601 = {instancePath:instancePath+"/page/evidence/ipc",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/ipc/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err601];
}
else {
vErrors.push(err601);
}
errors++;
}
}
var valid85 = _errs570 === errors;
}
else {
var valid85 = true;
}
if(valid85){
if(data172.next !== undefined){
let data210 = data172.next;
const _errs572 = errors;
const _errs573 = errors;
let valid97 = false;
const _errs574 = errors;
if(errors === _errs574){
if(typeof data210 === "string"){
if(func1(data210) > 131072){
const err602 = {instancePath:instancePath+"/page/evidence/next",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/next/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err602];
}
else {
vErrors.push(err602);
}
errors++;
}
}
else {
const err603 = {instancePath:instancePath+"/page/evidence/next",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/next/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err603];
}
else {
vErrors.push(err603);
}
errors++;
}
}
var _valid15 = _errs574 === errors;
valid97 = valid97 || _valid15;
const _errs576 = errors;
if(data210 !== null){
const err604 = {instancePath:instancePath+"/page/evidence/next",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/next/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err604];
}
else {
vErrors.push(err604);
}
errors++;
}
var _valid15 = _errs576 === errors;
valid97 = valid97 || _valid15;
if(!valid97){
const err605 = {instancePath:instancePath+"/page/evidence/next",schemaPath:"#/oneOf/6/properties/page/properties/evidence/properties/next/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err605];
}
else {
vErrors.push(err605);
}
errors++;
}
else {
errors = _errs573;
if(vErrors !== null){
if(_errs573){
vErrors.length = _errs573;
}
else {
vErrors = null;
}
}
}
var valid85 = _errs572 === errors;
}
else {
var valid85 = true;
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
const err606 = {instancePath:instancePath+"/page/evidence",schemaPath:"#/oneOf/6/properties/page/properties/evidence/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err606];
}
else {
vErrors.push(err606);
}
errors++;
}
}
var valid84 = _errs483 === errors;
}
else {
var valid84 = true;
}
if(valid84){
if(data171.cells !== undefined){
let data211 = data171.cells;
const _errs578 = errors;
if(errors === _errs578){
if(Array.isArray(data211)){
if(data211.length > 8){
const err607 = {instancePath:instancePath+"/page/cells",schemaPath:"#/oneOf/6/properties/page/properties/cells/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err607];
}
else {
vErrors.push(err607);
}
errors++;
}
else {
var valid98 = true;
const len17 = data211.length;
for(let i17=0; i17<len17; i17++){
let data212 = data211[i17];
const _errs580 = errors;
if(errors === _errs580){
if(Array.isArray(data212)){
if(data212.length > 8){
const err608 = {instancePath:instancePath+"/page/cells/" + i17,schemaPath:"#/oneOf/6/properties/page/properties/cells/items/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err608];
}
else {
vErrors.push(err608);
}
errors++;
}
else {
var valid99 = true;
const len18 = data212.length;
for(let i18=0; i18<len18; i18++){
let data213 = data212[i18];
const _errs582 = errors;
const _errs583 = errors;
let valid100 = false;
let passing6 = null;
const _errs584 = errors;
if(errors === _errs584){
if(data213 && typeof data213 == "object" && !Array.isArray(data213)){
let missing65;
if((data213.missing === undefined) && (missing65 = "missing")){
const err609 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18,schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/0/required",keyword:"required",params:{missingProperty: missing65},message:"must have required property '"+missing65+"'"};
if(vErrors === null){
vErrors = [err609];
}
else {
vErrors.push(err609);
}
errors++;
}
else {
const _errs586 = errors;
for(const key65 in data213){
if(!(key65 === "missing")){
const err610 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18,schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key65},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err610];
}
else {
vErrors.push(err610);
}
errors++;
break;
}
}
if(_errs586 === errors){
if(data213.missing !== undefined){
let data214 = data213.missing;
const _errs587 = errors;
if(errors === _errs587){
if(data214 && typeof data214 == "object" && !Array.isArray(data214)){
if(Object.keys(data214).length > 0){
const err611 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/missing",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/0/properties/missing/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
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
const err612 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/missing",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/0/properties/missing/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err612];
}
else {
vErrors.push(err612);
}
errors++;
}
}
}
}
}
}
else {
const err613 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18,schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err613];
}
else {
vErrors.push(err613);
}
errors++;
}
}
var _valid16 = _errs584 === errors;
if(_valid16){
valid100 = true;
passing6 = 0;
var props8 = true;
}
const _errs589 = errors;
if(errors === _errs589){
if(data213 && typeof data213 == "object" && !Array.isArray(data213)){
let missing66;
if((data213.null === undefined) && (missing66 = "null")){
const err614 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18,schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/1/required",keyword:"required",params:{missingProperty: missing66},message:"must have required property '"+missing66+"'"};
if(vErrors === null){
vErrors = [err614];
}
else {
vErrors.push(err614);
}
errors++;
}
else {
const _errs591 = errors;
for(const key66 in data213){
if(!(key66 === "null")){
const err615 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18,schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key66},message:"must NOT have additional properties"};
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
if(_errs591 === errors){
if(data213.null !== undefined){
let data215 = data213.null;
const _errs592 = errors;
if(errors === _errs592){
if(data215 && typeof data215 == "object" && !Array.isArray(data215)){
if(Object.keys(data215).length > 0){
const err616 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/null",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/1/properties/null/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
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
const err617 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/null",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/1/properties/null/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err617];
}
else {
vErrors.push(err617);
}
errors++;
}
}
}
}
}
}
else {
const err618 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18,schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err618];
}
else {
vErrors.push(err618);
}
errors++;
}
}
var _valid16 = _errs589 === errors;
if(_valid16 && valid100){
valid100 = false;
passing6 = [passing6, 1];
}
else {
if(_valid16){
valid100 = true;
passing6 = 1;
if(props8 !== true){
props8 = true;
}
}
const _errs594 = errors;
if(errors === _errs594){
if(data213 && typeof data213 == "object" && !Array.isArray(data213)){
let missing67;
if((data213.type_error === undefined) && (missing67 = "type_error")){
const err619 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18,schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/2/required",keyword:"required",params:{missingProperty: missing67},message:"must have required property '"+missing67+"'"};
if(vErrors === null){
vErrors = [err619];
}
else {
vErrors.push(err619);
}
errors++;
}
else {
const _errs596 = errors;
for(const key67 in data213){
if(!(key67 === "type_error")){
const err620 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18,schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key67},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err620];
}
else {
vErrors.push(err620);
}
errors++;
break;
}
}
if(_errs596 === errors){
if(data213.type_error !== undefined){
let data216 = data213.type_error;
if(typeof data216 !== "string"){
const err621 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/type_error",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/2/properties/type_error/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err621];
}
else {
vErrors.push(err621);
}
errors++;
}
if(!((((((((((((data216 === "unknown") || (data216 === "int64")) || (data216 === "uint64")) || (data216 === "float64")) || (data216 === "boolean")) || (data216 === "utf8")) || (data216 === "binary")) || (data216 === "null_value")) || (data216 === "map")) || (data216 === "list")) || (data216 === "text")) || (data216 === "character"))){
const err622 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/type_error",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/2/properties/type_error/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[6].properties.page.properties.cells.items.items.oneOf[2].properties.type_error.enum},message:"must be equal to one of the allowed values"};
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
}
else {
const err623 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18,schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err623];
}
else {
vErrors.push(err623);
}
errors++;
}
}
var _valid16 = _errs594 === errors;
if(_valid16 && valid100){
valid100 = false;
passing6 = [passing6, 2];
}
else {
if(_valid16){
valid100 = true;
passing6 = 2;
if(props8 !== true){
props8 = true;
}
}
const _errs599 = errors;
if(errors === _errs599){
if(data213 && typeof data213 == "object" && !Array.isArray(data213)){
let missing68;
if((data213.value === undefined) && (missing68 = "value")){
const err624 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18,schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/required",keyword:"required",params:{missingProperty: missing68},message:"must have required property '"+missing68+"'"};
if(vErrors === null){
vErrors = [err624];
}
else {
vErrors.push(err624);
}
errors++;
}
else {
const _errs601 = errors;
for(const key68 in data213){
if(!(key68 === "value")){
const err625 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18,schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key68},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err625];
}
else {
vErrors.push(err625);
}
errors++;
break;
}
}
if(_errs601 === errors){
if(data213.value !== undefined){
let data217 = data213.value;
const _errs603 = errors;
let valid105 = false;
let passing7 = null;
const _errs604 = errors;
if(errors === _errs604){
if(data217 && typeof data217 == "object" && !Array.isArray(data217)){
let missing69;
if((data217.int64 === undefined) && (missing69 = "int64")){
const err626 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/0/required",keyword:"required",params:{missingProperty: missing69},message:"must have required property '"+missing69+"'"};
if(vErrors === null){
vErrors = [err626];
}
else {
vErrors.push(err626);
}
errors++;
}
else {
const _errs606 = errors;
for(const key69 in data217){
if(!(key69 === "int64")){
const err627 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key69},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err627];
}
else {
vErrors.push(err627);
}
errors++;
break;
}
}
if(_errs606 === errors){
if(data217.int64 !== undefined){
let data218 = data217.int64;
const _errs607 = errors;
if(errors === _errs607){
if(typeof data218 === "string"){
if(func1(data218) > 131072){
const err628 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/value/int64",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/0/properties/int64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err629 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/value/int64",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/0/properties/int64/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err629];
}
else {
vErrors.push(err629);
}
errors++;
}
}
}
}
}
}
else {
const err630 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err630];
}
else {
vErrors.push(err630);
}
errors++;
}
}
var _valid17 = _errs604 === errors;
if(_valid17){
valid105 = true;
passing7 = 0;
var props9 = true;
}
const _errs609 = errors;
if(errors === _errs609){
if(data217 && typeof data217 == "object" && !Array.isArray(data217)){
let missing70;
if((data217.uint64 === undefined) && (missing70 = "uint64")){
const err631 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/1/required",keyword:"required",params:{missingProperty: missing70},message:"must have required property '"+missing70+"'"};
if(vErrors === null){
vErrors = [err631];
}
else {
vErrors.push(err631);
}
errors++;
}
else {
const _errs611 = errors;
for(const key70 in data217){
if(!(key70 === "uint64")){
const err632 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key70},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err632];
}
else {
vErrors.push(err632);
}
errors++;
break;
}
}
if(_errs611 === errors){
if(data217.uint64 !== undefined){
let data219 = data217.uint64;
const _errs612 = errors;
if(errors === _errs612){
if(typeof data219 === "string"){
if(func1(data219) > 131072){
const err633 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/value/uint64",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/1/properties/uint64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err634 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/value/uint64",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/1/properties/uint64/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
const err635 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err635];
}
else {
vErrors.push(err635);
}
errors++;
}
}
var _valid17 = _errs609 === errors;
if(_valid17 && valid105){
valid105 = false;
passing7 = [passing7, 1];
}
else {
if(_valid17){
valid105 = true;
passing7 = 1;
if(props9 !== true){
props9 = true;
}
}
const _errs614 = errors;
if(errors === _errs614){
if(data217 && typeof data217 == "object" && !Array.isArray(data217)){
let missing71;
if((data217.float_bits === undefined) && (missing71 = "float_bits")){
const err636 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/2/required",keyword:"required",params:{missingProperty: missing71},message:"must have required property '"+missing71+"'"};
if(vErrors === null){
vErrors = [err636];
}
else {
vErrors.push(err636);
}
errors++;
}
else {
const _errs616 = errors;
for(const key71 in data217){
if(!(key71 === "float_bits")){
const err637 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key71},message:"must NOT have additional properties"};
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
if(_errs616 === errors){
if(data217.float_bits !== undefined){
let data220 = data217.float_bits;
const _errs617 = errors;
if(errors === _errs617){
if(typeof data220 === "string"){
if(func1(data220) > 131072){
const err638 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/value/float_bits",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/2/properties/float_bits/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err638];
}
else {
vErrors.push(err638);
}
errors++;
}
}
else {
const err639 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/value/float_bits",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/2/properties/float_bits/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err639];
}
else {
vErrors.push(err639);
}
errors++;
}
}
}
}
}
}
else {
const err640 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err640];
}
else {
vErrors.push(err640);
}
errors++;
}
}
var _valid17 = _errs614 === errors;
if(_valid17 && valid105){
valid105 = false;
passing7 = [passing7, 2];
}
else {
if(_valid17){
valid105 = true;
passing7 = 2;
if(props9 !== true){
props9 = true;
}
}
const _errs619 = errors;
if(errors === _errs619){
if(data217 && typeof data217 == "object" && !Array.isArray(data217)){
let missing72;
if((data217.boolean === undefined) && (missing72 = "boolean")){
const err641 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/3/required",keyword:"required",params:{missingProperty: missing72},message:"must have required property '"+missing72+"'"};
if(vErrors === null){
vErrors = [err641];
}
else {
vErrors.push(err641);
}
errors++;
}
else {
const _errs621 = errors;
for(const key72 in data217){
if(!(key72 === "boolean")){
const err642 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key72},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err642];
}
else {
vErrors.push(err642);
}
errors++;
break;
}
}
if(_errs621 === errors){
if(data217.boolean !== undefined){
if(typeof data217.boolean !== "boolean"){
const err643 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/value/boolean",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/3/properties/boolean/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err643];
}
else {
vErrors.push(err643);
}
errors++;
}
}
}
}
}
else {
const err644 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err644];
}
else {
vErrors.push(err644);
}
errors++;
}
}
var _valid17 = _errs619 === errors;
if(_valid17 && valid105){
valid105 = false;
passing7 = [passing7, 3];
}
else {
if(_valid17){
valid105 = true;
passing7 = 3;
if(props9 !== true){
props9 = true;
}
}
const _errs624 = errors;
if(errors === _errs624){
if(data217 && typeof data217 == "object" && !Array.isArray(data217)){
let missing73;
if((data217.utf8 === undefined) && (missing73 = "utf8")){
const err645 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/4/required",keyword:"required",params:{missingProperty: missing73},message:"must have required property '"+missing73+"'"};
if(vErrors === null){
vErrors = [err645];
}
else {
vErrors.push(err645);
}
errors++;
}
else {
const _errs626 = errors;
for(const key73 in data217){
if(!(key73 === "utf8")){
const err646 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key73},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err646];
}
else {
vErrors.push(err646);
}
errors++;
break;
}
}
if(_errs626 === errors){
if(data217.utf8 !== undefined){
let data222 = data217.utf8;
const _errs627 = errors;
if(errors === _errs627){
if(typeof data222 === "string"){
if(func1(data222) > 131072){
const err647 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/value/utf8",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/4/properties/utf8/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err647];
}
else {
vErrors.push(err647);
}
errors++;
}
}
else {
const err648 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/value/utf8",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/4/properties/utf8/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
const err649 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err649];
}
else {
vErrors.push(err649);
}
errors++;
}
}
var _valid17 = _errs624 === errors;
if(_valid17 && valid105){
valid105 = false;
passing7 = [passing7, 4];
}
else {
if(_valid17){
valid105 = true;
passing7 = 4;
if(props9 !== true){
props9 = true;
}
}
const _errs629 = errors;
if(errors === _errs629){
if(data217 && typeof data217 == "object" && !Array.isArray(data217)){
let missing74;
if((data217.binary === undefined) && (missing74 = "binary")){
const err650 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/5/required",keyword:"required",params:{missingProperty: missing74},message:"must have required property '"+missing74+"'"};
if(vErrors === null){
vErrors = [err650];
}
else {
vErrors.push(err650);
}
errors++;
}
else {
const _errs631 = errors;
for(const key74 in data217){
if(!(key74 === "binary")){
const err651 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key74},message:"must NOT have additional properties"};
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
if(_errs631 === errors){
if(data217.binary !== undefined){
let data223 = data217.binary;
const _errs632 = errors;
if(errors === _errs632){
if(typeof data223 === "string"){
if(func1(data223) > 131072){
const err652 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/value/binary",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/5/properties/binary/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err652];
}
else {
vErrors.push(err652);
}
errors++;
}
}
else {
const err653 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/value/binary",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/5/properties/binary/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
const err654 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err654];
}
else {
vErrors.push(err654);
}
errors++;
}
}
var _valid17 = _errs629 === errors;
if(_valid17 && valid105){
valid105 = false;
passing7 = [passing7, 5];
}
else {
if(_valid17){
valid105 = true;
passing7 = 5;
if(props9 !== true){
props9 = true;
}
}
}
}
}
}
}
if(!valid105){
const err655 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf",keyword:"oneOf",params:{passingSchemas: passing7},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err655];
}
else {
vErrors.push(err655);
}
errors++;
}
else {
errors = _errs603;
if(vErrors !== null){
if(_errs603){
vErrors.length = _errs603;
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
const err656 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18,schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err656];
}
else {
vErrors.push(err656);
}
errors++;
}
}
var _valid16 = _errs599 === errors;
if(_valid16 && valid100){
valid100 = false;
passing6 = [passing6, 3];
}
else {
if(_valid16){
valid100 = true;
passing6 = 3;
if(props8 !== true){
props8 = true;
}
}
const _errs634 = errors;
if(errors === _errs634){
if(data213 && typeof data213 == "object" && !Array.isArray(data213)){
let missing75;
if((data213.conflict === undefined) && (missing75 = "conflict")){
const err657 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18,schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/required",keyword:"required",params:{missingProperty: missing75},message:"must have required property '"+missing75+"'"};
if(vErrors === null){
vErrors = [err657];
}
else {
vErrors.push(err657);
}
errors++;
}
else {
const _errs636 = errors;
for(const key75 in data213){
if(!(key75 === "conflict")){
const err658 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18,schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key75},message:"must NOT have additional properties"};
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
if(_errs636 === errors){
if(data213.conflict !== undefined){
let data224 = data213.conflict;
const _errs637 = errors;
if(errors === _errs637){
if(Array.isArray(data224)){
if(data224.length > 8){
const err659 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err659];
}
else {
vErrors.push(err659);
}
errors++;
}
else {
var valid113 = true;
const len19 = data224.length;
for(let i19=0; i19<len19; i19++){
let data225 = data224[i19];
const _errs639 = errors;
if(errors === _errs639){
if(data225 && typeof data225 == "object" && !Array.isArray(data225)){
let missing76;
if((((data225.counter === undefined) && (missing76 = "counter")) || ((data225.replica === undefined) && (missing76 = "replica"))) || ((data225.value === undefined) && (missing76 = "value"))){
const err660 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19,schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/required",keyword:"required",params:{missingProperty: missing76},message:"must have required property '"+missing76+"'"};
if(vErrors === null){
vErrors = [err660];
}
else {
vErrors.push(err660);
}
errors++;
}
else {
const _errs641 = errors;
for(const key76 in data225){
if(!(((key76 === "counter") || (key76 === "replica")) || (key76 === "value"))){
const err661 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19,schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key76},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err661];
}
else {
vErrors.push(err661);
}
errors++;
break;
}
}
if(_errs641 === errors){
if(data225.counter !== undefined){
let data226 = data225.counter;
const _errs642 = errors;
if(errors === _errs642){
if(typeof data226 === "string"){
if(func1(data226) > 131072){
const err662 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/counter",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/counter/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err662];
}
else {
vErrors.push(err662);
}
errors++;
}
}
else {
const err663 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/counter",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/counter/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err663];
}
else {
vErrors.push(err663);
}
errors++;
}
}
var valid114 = _errs642 === errors;
}
else {
var valid114 = true;
}
if(valid114){
if(data225.replica !== undefined){
let data227 = data225.replica;
const _errs644 = errors;
if(errors === _errs644){
if(typeof data227 === "string"){
if(func1(data227) > 131072){
const err664 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/replica",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/replica/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err665 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/replica",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/replica/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err665];
}
else {
vErrors.push(err665);
}
errors++;
}
}
var valid114 = _errs644 === errors;
}
else {
var valid114 = true;
}
if(valid114){
if(data225.value !== undefined){
let data228 = data225.value;
const _errs646 = errors;
const _errs647 = errors;
let valid115 = false;
let passing8 = null;
const _errs648 = errors;
if(errors === _errs648){
if(data228 && typeof data228 == "object" && !Array.isArray(data228)){
let missing77;
if((data228.null === undefined) && (missing77 = "null")){
const err666 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/0/required",keyword:"required",params:{missingProperty: missing77},message:"must have required property '"+missing77+"'"};
if(vErrors === null){
vErrors = [err666];
}
else {
vErrors.push(err666);
}
errors++;
}
else {
const _errs650 = errors;
for(const key77 in data228){
if(!(key77 === "null")){
const err667 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key77},message:"must NOT have additional properties"};
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
if(_errs650 === errors){
if(data228.null !== undefined){
let data229 = data228.null;
const _errs651 = errors;
if(errors === _errs651){
if(data229 && typeof data229 == "object" && !Array.isArray(data229)){
if(Object.keys(data229).length > 0){
const err668 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/null",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/0/properties/null/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err668];
}
else {
vErrors.push(err668);
}
errors++;
}
}
else {
const err669 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/null",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/0/properties/null/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err669];
}
else {
vErrors.push(err669);
}
errors++;
}
}
}
}
}
}
else {
const err670 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err670];
}
else {
vErrors.push(err670);
}
errors++;
}
}
var _valid18 = _errs648 === errors;
if(_valid18){
valid115 = true;
passing8 = 0;
var props10 = true;
}
const _errs653 = errors;
if(errors === _errs653){
if(data228 && typeof data228 == "object" && !Array.isArray(data228)){
let missing78;
if((data228.type_error === undefined) && (missing78 = "type_error")){
const err671 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/1/required",keyword:"required",params:{missingProperty: missing78},message:"must have required property '"+missing78+"'"};
if(vErrors === null){
vErrors = [err671];
}
else {
vErrors.push(err671);
}
errors++;
}
else {
const _errs655 = errors;
for(const key78 in data228){
if(!(key78 === "type_error")){
const err672 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key78},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err672];
}
else {
vErrors.push(err672);
}
errors++;
break;
}
}
if(_errs655 === errors){
if(data228.type_error !== undefined){
let data230 = data228.type_error;
if(typeof data230 !== "string"){
const err673 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/type_error",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/1/properties/type_error/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err673];
}
else {
vErrors.push(err673);
}
errors++;
}
if(!((((((((((((data230 === "unknown") || (data230 === "int64")) || (data230 === "uint64")) || (data230 === "float64")) || (data230 === "boolean")) || (data230 === "utf8")) || (data230 === "binary")) || (data230 === "null_value")) || (data230 === "map")) || (data230 === "list")) || (data230 === "text")) || (data230 === "character"))){
const err674 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/type_error",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/1/properties/type_error/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[6].properties.page.properties.cells.items.items.oneOf[4].properties.conflict.items.properties.value.oneOf[1].properties.type_error.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err674];
}
else {
vErrors.push(err674);
}
errors++;
}
}
}
}
}
else {
const err675 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err675];
}
else {
vErrors.push(err675);
}
errors++;
}
}
var _valid18 = _errs653 === errors;
if(_valid18 && valid115){
valid115 = false;
passing8 = [passing8, 1];
}
else {
if(_valid18){
valid115 = true;
passing8 = 1;
if(props10 !== true){
props10 = true;
}
}
const _errs658 = errors;
if(errors === _errs658){
if(data228 && typeof data228 == "object" && !Array.isArray(data228)){
let missing79;
if((data228.value === undefined) && (missing79 = "value")){
const err676 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/required",keyword:"required",params:{missingProperty: missing79},message:"must have required property '"+missing79+"'"};
if(vErrors === null){
vErrors = [err676];
}
else {
vErrors.push(err676);
}
errors++;
}
else {
const _errs660 = errors;
for(const key79 in data228){
if(!(key79 === "value")){
const err677 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key79},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err677];
}
else {
vErrors.push(err677);
}
errors++;
break;
}
}
if(_errs660 === errors){
if(data228.value !== undefined){
let data231 = data228.value;
const _errs662 = errors;
let valid119 = false;
let passing9 = null;
const _errs663 = errors;
if(errors === _errs663){
if(data231 && typeof data231 == "object" && !Array.isArray(data231)){
let missing80;
if((data231.int64 === undefined) && (missing80 = "int64")){
const err678 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/0/required",keyword:"required",params:{missingProperty: missing80},message:"must have required property '"+missing80+"'"};
if(vErrors === null){
vErrors = [err678];
}
else {
vErrors.push(err678);
}
errors++;
}
else {
const _errs665 = errors;
for(const key80 in data231){
if(!(key80 === "int64")){
const err679 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key80},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err679];
}
else {
vErrors.push(err679);
}
errors++;
break;
}
}
if(_errs665 === errors){
if(data231.int64 !== undefined){
let data232 = data231.int64;
const _errs666 = errors;
if(errors === _errs666){
if(typeof data232 === "string"){
if(func1(data232) > 131072){
const err680 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/value/int64",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/0/properties/int64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err680];
}
else {
vErrors.push(err680);
}
errors++;
}
}
else {
const err681 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/value/int64",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/0/properties/int64/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err681];
}
else {
vErrors.push(err681);
}
errors++;
}
}
}
}
}
}
else {
const err682 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err682];
}
else {
vErrors.push(err682);
}
errors++;
}
}
var _valid19 = _errs663 === errors;
if(_valid19){
valid119 = true;
passing9 = 0;
var props11 = true;
}
const _errs668 = errors;
if(errors === _errs668){
if(data231 && typeof data231 == "object" && !Array.isArray(data231)){
let missing81;
if((data231.uint64 === undefined) && (missing81 = "uint64")){
const err683 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/1/required",keyword:"required",params:{missingProperty: missing81},message:"must have required property '"+missing81+"'"};
if(vErrors === null){
vErrors = [err683];
}
else {
vErrors.push(err683);
}
errors++;
}
else {
const _errs670 = errors;
for(const key81 in data231){
if(!(key81 === "uint64")){
const err684 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key81},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err684];
}
else {
vErrors.push(err684);
}
errors++;
break;
}
}
if(_errs670 === errors){
if(data231.uint64 !== undefined){
let data233 = data231.uint64;
const _errs671 = errors;
if(errors === _errs671){
if(typeof data233 === "string"){
if(func1(data233) > 131072){
const err685 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/value/uint64",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/1/properties/uint64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err685];
}
else {
vErrors.push(err685);
}
errors++;
}
}
else {
const err686 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/value/uint64",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/1/properties/uint64/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err686];
}
else {
vErrors.push(err686);
}
errors++;
}
}
}
}
}
}
else {
const err687 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err687];
}
else {
vErrors.push(err687);
}
errors++;
}
}
var _valid19 = _errs668 === errors;
if(_valid19 && valid119){
valid119 = false;
passing9 = [passing9, 1];
}
else {
if(_valid19){
valid119 = true;
passing9 = 1;
if(props11 !== true){
props11 = true;
}
}
const _errs673 = errors;
if(errors === _errs673){
if(data231 && typeof data231 == "object" && !Array.isArray(data231)){
let missing82;
if((data231.float_bits === undefined) && (missing82 = "float_bits")){
const err688 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/2/required",keyword:"required",params:{missingProperty: missing82},message:"must have required property '"+missing82+"'"};
if(vErrors === null){
vErrors = [err688];
}
else {
vErrors.push(err688);
}
errors++;
}
else {
const _errs675 = errors;
for(const key82 in data231){
if(!(key82 === "float_bits")){
const err689 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key82},message:"must NOT have additional properties"};
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
if(_errs675 === errors){
if(data231.float_bits !== undefined){
let data234 = data231.float_bits;
const _errs676 = errors;
if(errors === _errs676){
if(typeof data234 === "string"){
if(func1(data234) > 131072){
const err690 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/value/float_bits",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/2/properties/float_bits/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err691 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/value/float_bits",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/2/properties/float_bits/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err691];
}
else {
vErrors.push(err691);
}
errors++;
}
}
}
}
}
}
else {
const err692 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err692];
}
else {
vErrors.push(err692);
}
errors++;
}
}
var _valid19 = _errs673 === errors;
if(_valid19 && valid119){
valid119 = false;
passing9 = [passing9, 2];
}
else {
if(_valid19){
valid119 = true;
passing9 = 2;
if(props11 !== true){
props11 = true;
}
}
const _errs678 = errors;
if(errors === _errs678){
if(data231 && typeof data231 == "object" && !Array.isArray(data231)){
let missing83;
if((data231.boolean === undefined) && (missing83 = "boolean")){
const err693 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/3/required",keyword:"required",params:{missingProperty: missing83},message:"must have required property '"+missing83+"'"};
if(vErrors === null){
vErrors = [err693];
}
else {
vErrors.push(err693);
}
errors++;
}
else {
const _errs680 = errors;
for(const key83 in data231){
if(!(key83 === "boolean")){
const err694 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key83},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err694];
}
else {
vErrors.push(err694);
}
errors++;
break;
}
}
if(_errs680 === errors){
if(data231.boolean !== undefined){
if(typeof data231.boolean !== "boolean"){
const err695 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/value/boolean",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/3/properties/boolean/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err695];
}
else {
vErrors.push(err695);
}
errors++;
}
}
}
}
}
else {
const err696 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err696];
}
else {
vErrors.push(err696);
}
errors++;
}
}
var _valid19 = _errs678 === errors;
if(_valid19 && valid119){
valid119 = false;
passing9 = [passing9, 3];
}
else {
if(_valid19){
valid119 = true;
passing9 = 3;
if(props11 !== true){
props11 = true;
}
}
const _errs683 = errors;
if(errors === _errs683){
if(data231 && typeof data231 == "object" && !Array.isArray(data231)){
let missing84;
if((data231.utf8 === undefined) && (missing84 = "utf8")){
const err697 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/4/required",keyword:"required",params:{missingProperty: missing84},message:"must have required property '"+missing84+"'"};
if(vErrors === null){
vErrors = [err697];
}
else {
vErrors.push(err697);
}
errors++;
}
else {
const _errs685 = errors;
for(const key84 in data231){
if(!(key84 === "utf8")){
const err698 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key84},message:"must NOT have additional properties"};
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
if(_errs685 === errors){
if(data231.utf8 !== undefined){
let data236 = data231.utf8;
const _errs686 = errors;
if(errors === _errs686){
if(typeof data236 === "string"){
if(func1(data236) > 131072){
const err699 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/value/utf8",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/4/properties/utf8/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err700 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/value/utf8",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/4/properties/utf8/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
const err701 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err701];
}
else {
vErrors.push(err701);
}
errors++;
}
}
var _valid19 = _errs683 === errors;
if(_valid19 && valid119){
valid119 = false;
passing9 = [passing9, 4];
}
else {
if(_valid19){
valid119 = true;
passing9 = 4;
if(props11 !== true){
props11 = true;
}
}
const _errs688 = errors;
if(errors === _errs688){
if(data231 && typeof data231 == "object" && !Array.isArray(data231)){
let missing85;
if((data231.binary === undefined) && (missing85 = "binary")){
const err702 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/5/required",keyword:"required",params:{missingProperty: missing85},message:"must have required property '"+missing85+"'"};
if(vErrors === null){
vErrors = [err702];
}
else {
vErrors.push(err702);
}
errors++;
}
else {
const _errs690 = errors;
for(const key85 in data231){
if(!(key85 === "binary")){
const err703 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key85},message:"must NOT have additional properties"};
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
if(_errs690 === errors){
if(data231.binary !== undefined){
let data237 = data231.binary;
const _errs691 = errors;
if(errors === _errs691){
if(typeof data237 === "string"){
if(func1(data237) > 131072){
const err704 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/value/binary",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/5/properties/binary/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err704];
}
else {
vErrors.push(err704);
}
errors++;
}
}
else {
const err705 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/value/binary",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/5/properties/binary/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err705];
}
else {
vErrors.push(err705);
}
errors++;
}
}
}
}
}
}
else {
const err706 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err706];
}
else {
vErrors.push(err706);
}
errors++;
}
}
var _valid19 = _errs688 === errors;
if(_valid19 && valid119){
valid119 = false;
passing9 = [passing9, 5];
}
else {
if(_valid19){
valid119 = true;
passing9 = 5;
if(props11 !== true){
props11 = true;
}
}
}
}
}
}
}
if(!valid119){
const err707 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf",keyword:"oneOf",params:{passingSchemas: passing9},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err707];
}
else {
vErrors.push(err707);
}
errors++;
}
else {
errors = _errs662;
if(vErrors !== null){
if(_errs662){
vErrors.length = _errs662;
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
const err708 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err708];
}
else {
vErrors.push(err708);
}
errors++;
}
}
var _valid18 = _errs658 === errors;
if(_valid18 && valid115){
valid115 = false;
passing8 = [passing8, 2];
}
else {
if(_valid18){
valid115 = true;
passing8 = 2;
if(props10 !== true){
props10 = true;
}
}
}
}
if(!valid115){
const err709 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19+"/value",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf",keyword:"oneOf",params:{passingSchemas: passing8},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err709];
}
else {
vErrors.push(err709);
}
errors++;
}
else {
errors = _errs647;
if(vErrors !== null){
if(_errs647){
vErrors.length = _errs647;
}
else {
vErrors = null;
}
}
}
var valid114 = _errs646 === errors;
}
else {
var valid114 = true;
}
}
}
}
}
}
else {
const err710 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict/" + i19,schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err710];
}
else {
vErrors.push(err710);
}
errors++;
}
}
var valid113 = _errs639 === errors;
if(!valid113){
break;
}
}
}
}
else {
const err711 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18+"/conflict",schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/type",keyword:"type",params:{type: "array"},message:"must be array"};
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
}
}
else {
const err712 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18,schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err712];
}
else {
vErrors.push(err712);
}
errors++;
}
}
var _valid16 = _errs634 === errors;
if(_valid16 && valid100){
valid100 = false;
passing6 = [passing6, 4];
}
else {
if(_valid16){
valid100 = true;
passing6 = 4;
if(props8 !== true){
props8 = true;
}
}
}
}
}
}
if(!valid100){
const err713 = {instancePath:instancePath+"/page/cells/" + i17+"/" + i18,schemaPath:"#/oneOf/6/properties/page/properties/cells/items/items/oneOf",keyword:"oneOf",params:{passingSchemas: passing6},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err713];
}
else {
vErrors.push(err713);
}
errors++;
}
else {
errors = _errs583;
if(vErrors !== null){
if(_errs583){
vErrors.length = _errs583;
}
else {
vErrors = null;
}
}
}
var valid99 = _errs582 === errors;
if(!valid99){
break;
}
}
}
}
else {
const err714 = {instancePath:instancePath+"/page/cells/" + i17,schemaPath:"#/oneOf/6/properties/page/properties/cells/items/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err714];
}
else {
vErrors.push(err714);
}
errors++;
}
}
var valid98 = _errs580 === errors;
if(!valid98){
break;
}
}
}
}
else {
const err715 = {instancePath:instancePath+"/page/cells",schemaPath:"#/oneOf/6/properties/page/properties/cells/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err715];
}
else {
vErrors.push(err715);
}
errors++;
}
}
var valid84 = _errs578 === errors;
}
else {
var valid84 = true;
}
}
}
}
}
else {
const err716 = {instancePath:instancePath+"/page",schemaPath:"#/oneOf/6/properties/page/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err717 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err717];
}
else {
vErrors.push(err717);
}
errors++;
}
}
var _valid0 = _errs477 === errors;
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
const _errs693 = errors;
if(errors === _errs693){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing86;
if((data.draft === undefined) && (missing86 = "draft")){
const err718 = {instancePath,schemaPath:"#/oneOf/7/required",keyword:"required",params:{missingProperty: missing86},message:"must have required property '"+missing86+"'"};
if(vErrors === null){
vErrors = [err718];
}
else {
vErrors.push(err718);
}
errors++;
}
else {
const _errs695 = errors;
for(const key86 in data){
if(!(key86 === "draft")){
const err719 = {instancePath,schemaPath:"#/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key86},message:"must NOT have additional properties"};
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
if(_errs695 === errors){
if(data.draft !== undefined){
let data238 = data.draft;
const _errs697 = errors;
let valid127 = false;
const _errs698 = errors;
if(errors === _errs698){
if(data238 && typeof data238 == "object" && !Array.isArray(data238)){
let missing87;
if((((((((data238.generation === undefined) && (missing87 = "generation")) || ((data238.limit === undefined) && (missing87 = "limit"))) || ((data238.starts === undefined) && (missing87 = "starts"))) || ((data238.enabled === undefined) && (missing87 = "enabled"))) || ((data238.contract === undefined) && (missing87 = "contract"))) || ((data238.budgets === undefined) && (missing87 = "budgets"))) || ((data238.namespaces === undefined) && (missing87 = "namespaces"))){
const err720 = {instancePath:instancePath+"/draft",schemaPath:"#/oneOf/7/properties/draft/anyOf/0/required",keyword:"required",params:{missingProperty: missing87},message:"must have required property '"+missing87+"'"};
if(vErrors === null){
vErrors = [err720];
}
else {
vErrors.push(err720);
}
errors++;
}
else {
const _errs700 = errors;
for(const key87 in data238){
if(!(((((((key87 === "generation") || (key87 === "limit")) || (key87 === "starts")) || (key87 === "enabled")) || (key87 === "contract")) || (key87 === "budgets")) || (key87 === "namespaces"))){
const err721 = {instancePath:instancePath+"/draft",schemaPath:"#/oneOf/7/properties/draft/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key87},message:"must NOT have additional properties"};
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
if(_errs700 === errors){
if(data238.generation !== undefined){
let data239 = data238.generation;
const _errs701 = errors;
if(errors === _errs701){
if(typeof data239 === "string"){
if(func1(data239) > 131072){
const err722 = {instancePath:instancePath+"/draft/generation",schemaPath:"#/oneOf/7/properties/draft/anyOf/0/properties/generation/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err723 = {instancePath:instancePath+"/draft/generation",schemaPath:"#/oneOf/7/properties/draft/anyOf/0/properties/generation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err723];
}
else {
vErrors.push(err723);
}
errors++;
}
}
var valid128 = _errs701 === errors;
}
else {
var valid128 = true;
}
if(valid128){
if(data238.limit !== undefined){
let data240 = data238.limit;
const _errs703 = errors;
if(!(((typeof data240 == "number") && (!(data240 % 1) && !isNaN(data240))) && (isFinite(data240)))){
const err724 = {instancePath:instancePath+"/draft/limit",schemaPath:"#/oneOf/7/properties/draft/anyOf/0/properties/limit/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err724];
}
else {
vErrors.push(err724);
}
errors++;
}
if(errors === _errs703){
if((typeof data240 == "number") && (isFinite(data240))){
if(data240 > 255 || isNaN(data240)){
const err725 = {instancePath:instancePath+"/draft/limit",schemaPath:"#/oneOf/7/properties/draft/anyOf/0/properties/limit/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err725];
}
else {
vErrors.push(err725);
}
errors++;
}
else {
if(data240 < 0 || isNaN(data240)){
const err726 = {instancePath:instancePath+"/draft/limit",schemaPath:"#/oneOf/7/properties/draft/anyOf/0/properties/limit/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid128 = _errs703 === errors;
}
else {
var valid128 = true;
}
if(valid128){
if(data238.starts !== undefined){
let data241 = data238.starts;
const _errs705 = errors;
if(!(((typeof data241 == "number") && (!(data241 % 1) && !isNaN(data241))) && (isFinite(data241)))){
const err727 = {instancePath:instancePath+"/draft/starts",schemaPath:"#/oneOf/7/properties/draft/anyOf/0/properties/starts/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err727];
}
else {
vErrors.push(err727);
}
errors++;
}
if(errors === _errs705){
if((typeof data241 == "number") && (isFinite(data241))){
if(data241 > 255 || isNaN(data241)){
const err728 = {instancePath:instancePath+"/draft/starts",schemaPath:"#/oneOf/7/properties/draft/anyOf/0/properties/starts/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err728];
}
else {
vErrors.push(err728);
}
errors++;
}
else {
if(data241 < 0 || isNaN(data241)){
const err729 = {instancePath:instancePath+"/draft/starts",schemaPath:"#/oneOf/7/properties/draft/anyOf/0/properties/starts/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid128 = _errs705 === errors;
}
else {
var valid128 = true;
}
if(valid128){
if(data238.enabled !== undefined){
const _errs707 = errors;
if(typeof data238.enabled !== "boolean"){
const err730 = {instancePath:instancePath+"/draft/enabled",schemaPath:"#/oneOf/7/properties/draft/anyOf/0/properties/enabled/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err730];
}
else {
vErrors.push(err730);
}
errors++;
}
var valid128 = _errs707 === errors;
}
else {
var valid128 = true;
}
if(valid128){
if(data238.contract !== undefined){
let data243 = data238.contract;
const _errs709 = errors;
if(errors === _errs709){
if(Array.isArray(data243)){
if(data243.length > 32){
const err731 = {instancePath:instancePath+"/draft/contract",schemaPath:"#/oneOf/7/properties/draft/anyOf/0/properties/contract/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err731];
}
else {
vErrors.push(err731);
}
errors++;
}
else {
if(data243.length < 32){
const err732 = {instancePath:instancePath+"/draft/contract",schemaPath:"#/oneOf/7/properties/draft/anyOf/0/properties/contract/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err732];
}
else {
vErrors.push(err732);
}
errors++;
}
else {
var valid129 = true;
const len20 = data243.length;
for(let i20=0; i20<len20; i20++){
let data244 = data243[i20];
const _errs711 = errors;
if(!(((typeof data244 == "number") && (!(data244 % 1) && !isNaN(data244))) && (isFinite(data244)))){
const err733 = {instancePath:instancePath+"/draft/contract/" + i20,schemaPath:"#/oneOf/7/properties/draft/anyOf/0/properties/contract/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err733];
}
else {
vErrors.push(err733);
}
errors++;
}
if(errors === _errs711){
if((typeof data244 == "number") && (isFinite(data244))){
if(data244 > 255 || isNaN(data244)){
const err734 = {instancePath:instancePath+"/draft/contract/" + i20,schemaPath:"#/oneOf/7/properties/draft/anyOf/0/properties/contract/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err734];
}
else {
vErrors.push(err734);
}
errors++;
}
else {
if(data244 < 0 || isNaN(data244)){
const err735 = {instancePath:instancePath+"/draft/contract/" + i20,schemaPath:"#/oneOf/7/properties/draft/anyOf/0/properties/contract/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid129 = _errs711 === errors;
if(!valid129){
break;
}
}
}
}
}
else {
const err736 = {instancePath:instancePath+"/draft/contract",schemaPath:"#/oneOf/7/properties/draft/anyOf/0/properties/contract/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err736];
}
else {
vErrors.push(err736);
}
errors++;
}
}
var valid128 = _errs709 === errors;
}
else {
var valid128 = true;
}
if(valid128){
if(data238.budgets !== undefined){
let data245 = data238.budgets;
const _errs713 = errors;
if(errors === _errs713){
if(data245 && typeof data245 == "object" && !Array.isArray(data245)){
let missing88;
if((((data245.pages === undefined) && (missing88 = "pages")) || ((data245.segments === undefined) && (missing88 = "segments"))) || ((data245.result_bytes === undefined) && (missing88 = "result_bytes"))){
const err737 = {instancePath:instancePath+"/draft/budgets",schemaPath:"#/oneOf/7/properties/draft/anyOf/0/properties/budgets/required",keyword:"required",params:{missingProperty: missing88},message:"must have required property '"+missing88+"'"};
if(vErrors === null){
vErrors = [err737];
}
else {
vErrors.push(err737);
}
errors++;
}
else {
const _errs715 = errors;
for(const key88 in data245){
if(!(((key88 === "pages") || (key88 === "segments")) || (key88 === "result_bytes"))){
const err738 = {instancePath:instancePath+"/draft/budgets",schemaPath:"#/oneOf/7/properties/draft/anyOf/0/properties/budgets/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key88},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err738];
}
else {
vErrors.push(err738);
}
errors++;
break;
}
}
if(_errs715 === errors){
if(data245.pages !== undefined){
let data246 = data245.pages;
const _errs716 = errors;
if(errors === _errs716){
if(typeof data246 === "string"){
if(func1(data246) > 131072){
const err739 = {instancePath:instancePath+"/draft/budgets/pages",schemaPath:"#/oneOf/7/properties/draft/anyOf/0/properties/budgets/properties/pages/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err739];
}
else {
vErrors.push(err739);
}
errors++;
}
}
else {
const err740 = {instancePath:instancePath+"/draft/budgets/pages",schemaPath:"#/oneOf/7/properties/draft/anyOf/0/properties/budgets/properties/pages/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err740];
}
else {
vErrors.push(err740);
}
errors++;
}
}
var valid130 = _errs716 === errors;
}
else {
var valid130 = true;
}
if(valid130){
if(data245.segments !== undefined){
let data247 = data245.segments;
const _errs718 = errors;
if(errors === _errs718){
if(typeof data247 === "string"){
if(func1(data247) > 131072){
const err741 = {instancePath:instancePath+"/draft/budgets/segments",schemaPath:"#/oneOf/7/properties/draft/anyOf/0/properties/budgets/properties/segments/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err741];
}
else {
vErrors.push(err741);
}
errors++;
}
}
else {
const err742 = {instancePath:instancePath+"/draft/budgets/segments",schemaPath:"#/oneOf/7/properties/draft/anyOf/0/properties/budgets/properties/segments/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err742];
}
else {
vErrors.push(err742);
}
errors++;
}
}
var valid130 = _errs718 === errors;
}
else {
var valid130 = true;
}
if(valid130){
if(data245.result_bytes !== undefined){
let data248 = data245.result_bytes;
const _errs720 = errors;
if(errors === _errs720){
if(typeof data248 === "string"){
if(func1(data248) > 131072){
const err743 = {instancePath:instancePath+"/draft/budgets/result_bytes",schemaPath:"#/oneOf/7/properties/draft/anyOf/0/properties/budgets/properties/result_bytes/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err743];
}
else {
vErrors.push(err743);
}
errors++;
}
}
else {
const err744 = {instancePath:instancePath+"/draft/budgets/result_bytes",schemaPath:"#/oneOf/7/properties/draft/anyOf/0/properties/budgets/properties/result_bytes/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err744];
}
else {
vErrors.push(err744);
}
errors++;
}
}
var valid130 = _errs720 === errors;
}
else {
var valid130 = true;
}
}
}
}
}
}
else {
const err745 = {instancePath:instancePath+"/draft/budgets",schemaPath:"#/oneOf/7/properties/draft/anyOf/0/properties/budgets/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err745];
}
else {
vErrors.push(err745);
}
errors++;
}
}
var valid128 = _errs713 === errors;
}
else {
var valid128 = true;
}
if(valid128){
if(data238.namespaces !== undefined){
let data249 = data238.namespaces;
const _errs722 = errors;
if(errors === _errs722){
if(Array.isArray(data249)){
if(data249.length > 8){
const err746 = {instancePath:instancePath+"/draft/namespaces",schemaPath:"#/oneOf/7/properties/draft/anyOf/0/properties/namespaces/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err746];
}
else {
vErrors.push(err746);
}
errors++;
}
else {
if(data249.length < 8){
const err747 = {instancePath:instancePath+"/draft/namespaces",schemaPath:"#/oneOf/7/properties/draft/anyOf/0/properties/namespaces/minItems",keyword:"minItems",params:{limit: 8},message:"must NOT have fewer than 8 items"};
if(vErrors === null){
vErrors = [err747];
}
else {
vErrors.push(err747);
}
errors++;
}
else {
var valid131 = true;
const len21 = data249.length;
for(let i21=0; i21<len21; i21++){
let data250 = data249[i21];
const _errs724 = errors;
if(errors === _errs724){
if(typeof data250 === "string"){
if(func1(data250) > 131072){
const err748 = {instancePath:instancePath+"/draft/namespaces/" + i21,schemaPath:"#/oneOf/7/properties/draft/anyOf/0/properties/namespaces/items/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err748];
}
else {
vErrors.push(err748);
}
errors++;
}
}
else {
const err749 = {instancePath:instancePath+"/draft/namespaces/" + i21,schemaPath:"#/oneOf/7/properties/draft/anyOf/0/properties/namespaces/items/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err749];
}
else {
vErrors.push(err749);
}
errors++;
}
}
var valid131 = _errs724 === errors;
if(!valid131){
break;
}
}
}
}
}
else {
const err750 = {instancePath:instancePath+"/draft/namespaces",schemaPath:"#/oneOf/7/properties/draft/anyOf/0/properties/namespaces/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err750];
}
else {
vErrors.push(err750);
}
errors++;
}
}
var valid128 = _errs722 === errors;
}
else {
var valid128 = true;
}
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
const err751 = {instancePath:instancePath+"/draft",schemaPath:"#/oneOf/7/properties/draft/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err751];
}
else {
vErrors.push(err751);
}
errors++;
}
}
var _valid20 = _errs698 === errors;
valid127 = valid127 || _valid20;
const _errs726 = errors;
if(data238 !== null){
const err752 = {instancePath:instancePath+"/draft",schemaPath:"#/oneOf/7/properties/draft/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err752];
}
else {
vErrors.push(err752);
}
errors++;
}
var _valid20 = _errs726 === errors;
valid127 = valid127 || _valid20;
if(!valid127){
const err753 = {instancePath:instancePath+"/draft",schemaPath:"#/oneOf/7/properties/draft/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err753];
}
else {
vErrors.push(err753);
}
errors++;
}
else {
errors = _errs697;
if(vErrors !== null){
if(_errs697){
vErrors.length = _errs697;
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
const err754 = {instancePath,schemaPath:"#/oneOf/7/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err754];
}
else {
vErrors.push(err754);
}
errors++;
}
}
var _valid0 = _errs693 === errors;
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
}
}
}
}
}
}
}
if(!valid0){
const err755 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err755];
}
else {
vErrors.push(err755);
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
