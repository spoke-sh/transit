// Generated; no runtime code generation or eval.
import lengthModule from "ajv/dist/runtime/ucs2length.js";
const ucs2length = lengthModule.default ?? lengthModule;
"use strict";
export const Definition = validate23;
const schema32 = {"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","const":1},"name":{"type":"string","minLength":1,"maxLength":64,"pattern":"^[A-Za-z_][A-Za-z_0-9]*$"},"realm":{"type":"integer","minimum":0,"maximum":9007199254740991},"revision":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"components":{"type":"integer","minimum":0,"maximum":65535},"entry":{"type":"string","minLength":1,"maxLength":64,"pattern":"^[A-Za-z_][A-Za-z_0-9]*$"},"theme":{"type":"string","minLength":1,"maxLength":64,"pattern":"^[A-Za-z_][A-Za-z_0-9]*$"},"themes":{"type":"array","maxItems":2,"items":{"$ref":"#/$defs/Theme"}},"screens":{"type":"array","maxItems":16,"items":{"$ref":"#/$defs/Screen"}},"bindings":{"type":"array","maxItems":16,"items":{"$ref":"#/$defs/Binding"}},"actions":{"type":"array","maxItems":16,"items":{"$ref":"#/$defs/Action"}}},"required":["name","realm","revision","entry","theme","themes","screens","bindings","actions"]};
const schema33 = {"type":"object","additionalProperties":false,"properties":{"name":{"type":"string","minLength":1,"maxLength":64,"pattern":"^[A-Za-z_][A-Za-z_0-9]*$"},"density":{"type":"string","enum":["comfortable","compact"]}},"required":["name","density"]};
const schema34 = {"type":"object","additionalProperties":false,"properties":{"name":{"type":"string","minLength":1,"maxLength":64,"pattern":"^[A-Za-z_][A-Za-z_0-9]*$"},"path":{"type":"string","minLength":1,"maxLength":128,"pattern":"^/[A-Za-z_0-9/-]*$"},"label":{"type":"string","minLength":1,"maxLength":128},"area":{"type":"string","enum":["workspace","operations"]},"renderer":{"type":"string","enum":["atlas","worksheet","records","activity","definition","operations","work_items"]},"binding":{"type":"string","minLength":1,"maxLength":64,"pattern":"^[A-Za-z_][A-Za-z_0-9]*$"}},"required":["name","path","label","area","renderer","binding"]};
const schema35 = {"type":"object","additionalProperties":false,"properties":{"name":{"type":"string","minLength":1,"maxLength":64,"pattern":"^[A-Za-z_][A-Za-z_0-9]*$"},"source":{"oneOf":[{"type":"object","additionalProperties":false,"required":["inspection"],"properties":{"inspection":{"type":"object","additionalProperties":false,"properties":{"projection":{"type":"string","enum":["atlas","resources","processes","records","capabilities","activity"]},"page_budget":{"type":"integer","minimum":0,"maximum":255}},"required":["projection"]}}},{"type":"object","additionalProperties":false,"required":["query"],"properties":{"query":{"type":"object","additionalProperties":false,"properties":{"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"name":{"type":"string","minLength":1,"maxLength":64,"pattern":"^[A-Za-z_][A-Za-z_0-9]*$"},"source_kind":{"type":"string","enum":["table","kv","document"]},"schema":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"profile":{"type":"string","enum":["table_v1","unified_v2"]},"sql":{"type":"string","minLength":1,"maxLength":4096},"refresh":{"type":"string","enum":["snapshot","follow"]},"starts":{"type":"integer","minimum":0,"maximum":255}},"required":["resource","name","source_kind","schema","profile","sql"]}}},{"type":"object","additionalProperties":false,"required":["command"],"properties":{"command":{"type":"object","additionalProperties":false,"properties":{"service":{"type":"integer","minimum":0,"maximum":9007199254740991},"target":{"type":"integer","minimum":0,"maximum":9007199254740991},"revision":{"type":"integer","minimum":0,"maximum":9007199254740991},"codec":{"type":"integer","minimum":0,"maximum":65535}},"required":["service","target","revision","codec"]}}}]}},"required":["name","source"]};
const schema36 = {"type":"object","additionalProperties":false,"properties":{"name":{"type":"string","minLength":1,"maxLength":64,"pattern":"^[A-Za-z_][A-Za-z_0-9]*$"},"label":{"type":"string","minLength":1,"maxLength":128},"target":{"oneOf":[{"type":"object","additionalProperties":false,"required":["navigate"],"properties":{"navigate":{"type":"string","maxLength":256}}},{"type":"object","additionalProperties":false,"required":["command"],"properties":{"command":{"type":"string","maxLength":256}}},{"type":"object","additionalProperties":false,"required":["follow"],"properties":{"follow":{"type":"string","maxLength":256}}}]}},"required":["name","label","target"]};
const func1 = Object.prototype.hasOwnProperty;
const func2 = ucs2length;
const pattern4 = new RegExp("^[A-Za-z_][A-Za-z_0-9]*$", "u");
const pattern5 = new RegExp("^(0|[1-9][0-9]*)$", "u");
const pattern10 = new RegExp("^/[A-Za-z_0-9/-]*$", "u");

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
if((((((((((data.name === undefined) && (missing0 = "name")) || ((data.realm === undefined) && (missing0 = "realm"))) || ((data.revision === undefined) && (missing0 = "revision"))) || ((data.entry === undefined) && (missing0 = "entry"))) || ((data.theme === undefined) && (missing0 = "theme"))) || ((data.themes === undefined) && (missing0 = "themes"))) || ((data.screens === undefined) && (missing0 = "screens"))) || ((data.bindings === undefined) && (missing0 = "bindings"))) || ((data.actions === undefined) && (missing0 = "actions"))){
validate23.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema32.properties, key0))){
validate23.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
let data0 = data.version;
const _errs2 = errors;
if(!(((typeof data0 == "number") && (!(data0 % 1) && !isNaN(data0))) && (isFinite(data0)))){
validate23.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(1 !== data0){
validate23.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"}];
return false;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.name !== undefined){
let data1 = data.name;
const _errs4 = errors;
if(errors === _errs4){
if(typeof data1 === "string"){
if(func2(data1) > 64){
validate23.errors = [{instancePath:instancePath+"/name",schemaPath:"#/properties/name/maxLength",keyword:"maxLength",params:{limit: 64},message:"must NOT have more than 64 characters"}];
return false;
}
else {
if(func2(data1) < 1){
validate23.errors = [{instancePath:instancePath+"/name",schemaPath:"#/properties/name/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"}];
return false;
}
else {
if(!pattern4.test(data1)){
validate23.errors = [{instancePath:instancePath+"/name",schemaPath:"#/properties/name/pattern",keyword:"pattern",params:{pattern: "^[A-Za-z_][A-Za-z_0-9]*$"},message:"must match pattern \""+"^[A-Za-z_][A-Za-z_0-9]*$"+"\""}];
return false;
}
}
}
}
else {
validate23.errors = [{instancePath:instancePath+"/name",schemaPath:"#/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.realm !== undefined){
let data2 = data.realm;
const _errs6 = errors;
if(!(((typeof data2 == "number") && (!(data2 % 1) && !isNaN(data2))) && (isFinite(data2)))){
validate23.errors = [{instancePath:instancePath+"/realm",schemaPath:"#/properties/realm/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs6){
if((typeof data2 == "number") && (isFinite(data2))){
if(data2 > 9007199254740991 || isNaN(data2)){
validate23.errors = [{instancePath:instancePath+"/realm",schemaPath:"#/properties/realm/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data2 < 0 || isNaN(data2)){
validate23.errors = [{instancePath:instancePath+"/realm",schemaPath:"#/properties/realm/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
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
if(data.revision !== undefined){
let data3 = data.revision;
const _errs8 = errors;
if(errors === _errs8){
if(typeof data3 === "string"){
if(func2(data3) > 20){
validate23.errors = [{instancePath:instancePath+"/revision",schemaPath:"#/properties/revision/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern5.test(data3)){
validate23.errors = [{instancePath:instancePath+"/revision",schemaPath:"#/properties/revision/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate23.errors = [{instancePath:instancePath+"/revision",schemaPath:"#/properties/revision/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.components !== undefined){
let data4 = data.components;
const _errs10 = errors;
if(!(((typeof data4 == "number") && (!(data4 % 1) && !isNaN(data4))) && (isFinite(data4)))){
validate23.errors = [{instancePath:instancePath+"/components",schemaPath:"#/properties/components/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs10){
if((typeof data4 == "number") && (isFinite(data4))){
if(data4 > 65535 || isNaN(data4)){
validate23.errors = [{instancePath:instancePath+"/components",schemaPath:"#/properties/components/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"}];
return false;
}
else {
if(data4 < 0 || isNaN(data4)){
validate23.errors = [{instancePath:instancePath+"/components",schemaPath:"#/properties/components/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid0 = _errs10 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.entry !== undefined){
let data5 = data.entry;
const _errs12 = errors;
if(errors === _errs12){
if(typeof data5 === "string"){
if(func2(data5) > 64){
validate23.errors = [{instancePath:instancePath+"/entry",schemaPath:"#/properties/entry/maxLength",keyword:"maxLength",params:{limit: 64},message:"must NOT have more than 64 characters"}];
return false;
}
else {
if(func2(data5) < 1){
validate23.errors = [{instancePath:instancePath+"/entry",schemaPath:"#/properties/entry/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"}];
return false;
}
else {
if(!pattern4.test(data5)){
validate23.errors = [{instancePath:instancePath+"/entry",schemaPath:"#/properties/entry/pattern",keyword:"pattern",params:{pattern: "^[A-Za-z_][A-Za-z_0-9]*$"},message:"must match pattern \""+"^[A-Za-z_][A-Za-z_0-9]*$"+"\""}];
return false;
}
}
}
}
else {
validate23.errors = [{instancePath:instancePath+"/entry",schemaPath:"#/properties/entry/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs12 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.theme !== undefined){
let data6 = data.theme;
const _errs14 = errors;
if(errors === _errs14){
if(typeof data6 === "string"){
if(func2(data6) > 64){
validate23.errors = [{instancePath:instancePath+"/theme",schemaPath:"#/properties/theme/maxLength",keyword:"maxLength",params:{limit: 64},message:"must NOT have more than 64 characters"}];
return false;
}
else {
if(func2(data6) < 1){
validate23.errors = [{instancePath:instancePath+"/theme",schemaPath:"#/properties/theme/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"}];
return false;
}
else {
if(!pattern4.test(data6)){
validate23.errors = [{instancePath:instancePath+"/theme",schemaPath:"#/properties/theme/pattern",keyword:"pattern",params:{pattern: "^[A-Za-z_][A-Za-z_0-9]*$"},message:"must match pattern \""+"^[A-Za-z_][A-Za-z_0-9]*$"+"\""}];
return false;
}
}
}
}
else {
validate23.errors = [{instancePath:instancePath+"/theme",schemaPath:"#/properties/theme/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs14 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.themes !== undefined){
let data7 = data.themes;
const _errs16 = errors;
if(errors === _errs16){
if(Array.isArray(data7)){
if(data7.length > 2){
validate23.errors = [{instancePath:instancePath+"/themes",schemaPath:"#/properties/themes/maxItems",keyword:"maxItems",params:{limit: 2},message:"must NOT have more than 2 items"}];
return false;
}
else {
var valid1 = true;
const len0 = data7.length;
for(let i0=0; i0<len0; i0++){
let data8 = data7[i0];
const _errs18 = errors;
const _errs19 = errors;
if(errors === _errs19){
if(data8 && typeof data8 == "object" && !Array.isArray(data8)){
let missing1;
if(((data8.name === undefined) && (missing1 = "name")) || ((data8.density === undefined) && (missing1 = "density"))){
validate23.errors = [{instancePath:instancePath+"/themes/" + i0,schemaPath:"#/$defs/Theme/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"}];
return false;
}
else {
const _errs21 = errors;
for(const key1 in data8){
if(!((key1 === "name") || (key1 === "density"))){
validate23.errors = [{instancePath:instancePath+"/themes/" + i0,schemaPath:"#/$defs/Theme/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs21 === errors){
if(data8.name !== undefined){
let data9 = data8.name;
const _errs22 = errors;
if(errors === _errs22){
if(typeof data9 === "string"){
if(func2(data9) > 64){
validate23.errors = [{instancePath:instancePath+"/themes/" + i0+"/name",schemaPath:"#/$defs/Theme/properties/name/maxLength",keyword:"maxLength",params:{limit: 64},message:"must NOT have more than 64 characters"}];
return false;
}
else {
if(func2(data9) < 1){
validate23.errors = [{instancePath:instancePath+"/themes/" + i0+"/name",schemaPath:"#/$defs/Theme/properties/name/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"}];
return false;
}
else {
if(!pattern4.test(data9)){
validate23.errors = [{instancePath:instancePath+"/themes/" + i0+"/name",schemaPath:"#/$defs/Theme/properties/name/pattern",keyword:"pattern",params:{pattern: "^[A-Za-z_][A-Za-z_0-9]*$"},message:"must match pattern \""+"^[A-Za-z_][A-Za-z_0-9]*$"+"\""}];
return false;
}
}
}
}
else {
validate23.errors = [{instancePath:instancePath+"/themes/" + i0+"/name",schemaPath:"#/$defs/Theme/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid3 = _errs22 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data8.density !== undefined){
let data10 = data8.density;
const _errs24 = errors;
if(typeof data10 !== "string"){
validate23.errors = [{instancePath:instancePath+"/themes/" + i0+"/density",schemaPath:"#/$defs/Theme/properties/density/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((data10 === "comfortable") || (data10 === "compact"))){
validate23.errors = [{instancePath:instancePath+"/themes/" + i0+"/density",schemaPath:"#/$defs/Theme/properties/density/enum",keyword:"enum",params:{allowedValues: schema33.properties.density.enum},message:"must be equal to one of the allowed values"}];
return false;
}
var valid3 = _errs24 === errors;
}
else {
var valid3 = true;
}
}
}
}
}
else {
validate23.errors = [{instancePath:instancePath+"/themes/" + i0,schemaPath:"#/$defs/Theme/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
var valid1 = _errs18 === errors;
if(!valid1){
break;
}
}
}
}
else {
validate23.errors = [{instancePath:instancePath+"/themes",schemaPath:"#/properties/themes/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid0 = _errs16 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.screens !== undefined){
let data11 = data.screens;
const _errs26 = errors;
if(errors === _errs26){
if(Array.isArray(data11)){
if(data11.length > 16){
validate23.errors = [{instancePath:instancePath+"/screens",schemaPath:"#/properties/screens/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
var valid4 = true;
const len1 = data11.length;
for(let i1=0; i1<len1; i1++){
let data12 = data11[i1];
const _errs28 = errors;
const _errs29 = errors;
if(errors === _errs29){
if(data12 && typeof data12 == "object" && !Array.isArray(data12)){
let missing2;
if(((((((data12.name === undefined) && (missing2 = "name")) || ((data12.path === undefined) && (missing2 = "path"))) || ((data12.label === undefined) && (missing2 = "label"))) || ((data12.area === undefined) && (missing2 = "area"))) || ((data12.renderer === undefined) && (missing2 = "renderer"))) || ((data12.binding === undefined) && (missing2 = "binding"))){
validate23.errors = [{instancePath:instancePath+"/screens/" + i1,schemaPath:"#/$defs/Screen/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"}];
return false;
}
else {
const _errs31 = errors;
for(const key2 in data12){
if(!((((((key2 === "name") || (key2 === "path")) || (key2 === "label")) || (key2 === "area")) || (key2 === "renderer")) || (key2 === "binding"))){
validate23.errors = [{instancePath:instancePath+"/screens/" + i1,schemaPath:"#/$defs/Screen/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs31 === errors){
if(data12.name !== undefined){
let data13 = data12.name;
const _errs32 = errors;
if(errors === _errs32){
if(typeof data13 === "string"){
if(func2(data13) > 64){
validate23.errors = [{instancePath:instancePath+"/screens/" + i1+"/name",schemaPath:"#/$defs/Screen/properties/name/maxLength",keyword:"maxLength",params:{limit: 64},message:"must NOT have more than 64 characters"}];
return false;
}
else {
if(func2(data13) < 1){
validate23.errors = [{instancePath:instancePath+"/screens/" + i1+"/name",schemaPath:"#/$defs/Screen/properties/name/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"}];
return false;
}
else {
if(!pattern4.test(data13)){
validate23.errors = [{instancePath:instancePath+"/screens/" + i1+"/name",schemaPath:"#/$defs/Screen/properties/name/pattern",keyword:"pattern",params:{pattern: "^[A-Za-z_][A-Za-z_0-9]*$"},message:"must match pattern \""+"^[A-Za-z_][A-Za-z_0-9]*$"+"\""}];
return false;
}
}
}
}
else {
validate23.errors = [{instancePath:instancePath+"/screens/" + i1+"/name",schemaPath:"#/$defs/Screen/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid6 = _errs32 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data12.path !== undefined){
let data14 = data12.path;
const _errs34 = errors;
if(errors === _errs34){
if(typeof data14 === "string"){
if(func2(data14) > 128){
validate23.errors = [{instancePath:instancePath+"/screens/" + i1+"/path",schemaPath:"#/$defs/Screen/properties/path/maxLength",keyword:"maxLength",params:{limit: 128},message:"must NOT have more than 128 characters"}];
return false;
}
else {
if(func2(data14) < 1){
validate23.errors = [{instancePath:instancePath+"/screens/" + i1+"/path",schemaPath:"#/$defs/Screen/properties/path/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"}];
return false;
}
else {
if(!pattern10.test(data14)){
validate23.errors = [{instancePath:instancePath+"/screens/" + i1+"/path",schemaPath:"#/$defs/Screen/properties/path/pattern",keyword:"pattern",params:{pattern: "^/[A-Za-z_0-9/-]*$"},message:"must match pattern \""+"^/[A-Za-z_0-9/-]*$"+"\""}];
return false;
}
}
}
}
else {
validate23.errors = [{instancePath:instancePath+"/screens/" + i1+"/path",schemaPath:"#/$defs/Screen/properties/path/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid6 = _errs34 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data12.label !== undefined){
let data15 = data12.label;
const _errs36 = errors;
if(errors === _errs36){
if(typeof data15 === "string"){
if(func2(data15) > 128){
validate23.errors = [{instancePath:instancePath+"/screens/" + i1+"/label",schemaPath:"#/$defs/Screen/properties/label/maxLength",keyword:"maxLength",params:{limit: 128},message:"must NOT have more than 128 characters"}];
return false;
}
else {
if(func2(data15) < 1){
validate23.errors = [{instancePath:instancePath+"/screens/" + i1+"/label",schemaPath:"#/$defs/Screen/properties/label/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"}];
return false;
}
}
}
else {
validate23.errors = [{instancePath:instancePath+"/screens/" + i1+"/label",schemaPath:"#/$defs/Screen/properties/label/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid6 = _errs36 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data12.area !== undefined){
let data16 = data12.area;
const _errs38 = errors;
if(typeof data16 !== "string"){
validate23.errors = [{instancePath:instancePath+"/screens/" + i1+"/area",schemaPath:"#/$defs/Screen/properties/area/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((data16 === "workspace") || (data16 === "operations"))){
validate23.errors = [{instancePath:instancePath+"/screens/" + i1+"/area",schemaPath:"#/$defs/Screen/properties/area/enum",keyword:"enum",params:{allowedValues: schema34.properties.area.enum},message:"must be equal to one of the allowed values"}];
return false;
}
var valid6 = _errs38 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data12.renderer !== undefined){
let data17 = data12.renderer;
const _errs40 = errors;
if(typeof data17 !== "string"){
validate23.errors = [{instancePath:instancePath+"/screens/" + i1+"/renderer",schemaPath:"#/$defs/Screen/properties/renderer/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((data17 === "atlas") || (data17 === "worksheet")) || (data17 === "records")) || (data17 === "activity")) || (data17 === "definition")) || (data17 === "operations")) || (data17 === "work_items"))){
validate23.errors = [{instancePath:instancePath+"/screens/" + i1+"/renderer",schemaPath:"#/$defs/Screen/properties/renderer/enum",keyword:"enum",params:{allowedValues: schema34.properties.renderer.enum},message:"must be equal to one of the allowed values"}];
return false;
}
var valid6 = _errs40 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data12.binding !== undefined){
let data18 = data12.binding;
const _errs42 = errors;
if(errors === _errs42){
if(typeof data18 === "string"){
if(func2(data18) > 64){
validate23.errors = [{instancePath:instancePath+"/screens/" + i1+"/binding",schemaPath:"#/$defs/Screen/properties/binding/maxLength",keyword:"maxLength",params:{limit: 64},message:"must NOT have more than 64 characters"}];
return false;
}
else {
if(func2(data18) < 1){
validate23.errors = [{instancePath:instancePath+"/screens/" + i1+"/binding",schemaPath:"#/$defs/Screen/properties/binding/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"}];
return false;
}
else {
if(!pattern4.test(data18)){
validate23.errors = [{instancePath:instancePath+"/screens/" + i1+"/binding",schemaPath:"#/$defs/Screen/properties/binding/pattern",keyword:"pattern",params:{pattern: "^[A-Za-z_][A-Za-z_0-9]*$"},message:"must match pattern \""+"^[A-Za-z_][A-Za-z_0-9]*$"+"\""}];
return false;
}
}
}
}
else {
validate23.errors = [{instancePath:instancePath+"/screens/" + i1+"/binding",schemaPath:"#/$defs/Screen/properties/binding/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid6 = _errs42 === errors;
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
else {
validate23.errors = [{instancePath:instancePath+"/screens/" + i1,schemaPath:"#/$defs/Screen/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
var valid4 = _errs28 === errors;
if(!valid4){
break;
}
}
}
}
else {
validate23.errors = [{instancePath:instancePath+"/screens",schemaPath:"#/properties/screens/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid0 = _errs26 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.bindings !== undefined){
let data19 = data.bindings;
const _errs44 = errors;
if(errors === _errs44){
if(Array.isArray(data19)){
if(data19.length > 16){
validate23.errors = [{instancePath:instancePath+"/bindings",schemaPath:"#/properties/bindings/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
var valid7 = true;
const len2 = data19.length;
for(let i2=0; i2<len2; i2++){
let data20 = data19[i2];
const _errs46 = errors;
const _errs47 = errors;
if(errors === _errs47){
if(data20 && typeof data20 == "object" && !Array.isArray(data20)){
let missing3;
if(((data20.name === undefined) && (missing3 = "name")) || ((data20.source === undefined) && (missing3 = "source"))){
validate23.errors = [{instancePath:instancePath+"/bindings/" + i2,schemaPath:"#/$defs/Binding/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"}];
return false;
}
else {
const _errs49 = errors;
for(const key3 in data20){
if(!((key3 === "name") || (key3 === "source"))){
validate23.errors = [{instancePath:instancePath+"/bindings/" + i2,schemaPath:"#/$defs/Binding/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs49 === errors){
if(data20.name !== undefined){
let data21 = data20.name;
const _errs50 = errors;
if(errors === _errs50){
if(typeof data21 === "string"){
if(func2(data21) > 64){
validate23.errors = [{instancePath:instancePath+"/bindings/" + i2+"/name",schemaPath:"#/$defs/Binding/properties/name/maxLength",keyword:"maxLength",params:{limit: 64},message:"must NOT have more than 64 characters"}];
return false;
}
else {
if(func2(data21) < 1){
validate23.errors = [{instancePath:instancePath+"/bindings/" + i2+"/name",schemaPath:"#/$defs/Binding/properties/name/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"}];
return false;
}
else {
if(!pattern4.test(data21)){
validate23.errors = [{instancePath:instancePath+"/bindings/" + i2+"/name",schemaPath:"#/$defs/Binding/properties/name/pattern",keyword:"pattern",params:{pattern: "^[A-Za-z_][A-Za-z_0-9]*$"},message:"must match pattern \""+"^[A-Za-z_][A-Za-z_0-9]*$"+"\""}];
return false;
}
}
}
}
else {
validate23.errors = [{instancePath:instancePath+"/bindings/" + i2+"/name",schemaPath:"#/$defs/Binding/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid9 = _errs50 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data20.source !== undefined){
let data22 = data20.source;
const _errs52 = errors;
const _errs53 = errors;
let valid10 = false;
let passing0 = null;
const _errs54 = errors;
if(errors === _errs54){
if(data22 && typeof data22 == "object" && !Array.isArray(data22)){
let missing4;
if((data22.inspection === undefined) && (missing4 = "inspection")){
const err0 = {instancePath:instancePath+"/bindings/" + i2+"/source",schemaPath:"#/$defs/Binding/properties/source/oneOf/0/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
}
else {
const _errs56 = errors;
for(const key4 in data22){
if(!(key4 === "inspection")){
const err1 = {instancePath:instancePath+"/bindings/" + i2+"/source",schemaPath:"#/$defs/Binding/properties/source/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(_errs56 === errors){
if(data22.inspection !== undefined){
let data23 = data22.inspection;
const _errs57 = errors;
if(errors === _errs57){
if(data23 && typeof data23 == "object" && !Array.isArray(data23)){
let missing5;
if((data23.projection === undefined) && (missing5 = "projection")){
const err2 = {instancePath:instancePath+"/bindings/" + i2+"/source/inspection",schemaPath:"#/$defs/Binding/properties/source/oneOf/0/properties/inspection/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
if(vErrors === null){
vErrors = [err2];
}
else {
vErrors.push(err2);
}
errors++;
}
else {
const _errs59 = errors;
for(const key5 in data23){
if(!((key5 === "projection") || (key5 === "page_budget"))){
const err3 = {instancePath:instancePath+"/bindings/" + i2+"/source/inspection",schemaPath:"#/$defs/Binding/properties/source/oneOf/0/properties/inspection/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(_errs59 === errors){
if(data23.projection !== undefined){
let data24 = data23.projection;
const _errs60 = errors;
if(typeof data24 !== "string"){
const err4 = {instancePath:instancePath+"/bindings/" + i2+"/source/inspection/projection",schemaPath:"#/$defs/Binding/properties/source/oneOf/0/properties/inspection/properties/projection/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
}
if(!((((((data24 === "atlas") || (data24 === "resources")) || (data24 === "processes")) || (data24 === "records")) || (data24 === "capabilities")) || (data24 === "activity"))){
const err5 = {instancePath:instancePath+"/bindings/" + i2+"/source/inspection/projection",schemaPath:"#/$defs/Binding/properties/source/oneOf/0/properties/inspection/properties/projection/enum",keyword:"enum",params:{allowedValues: schema35.properties.source.oneOf[0].properties.inspection.properties.projection.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err5];
}
else {
vErrors.push(err5);
}
errors++;
}
var valid12 = _errs60 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data23.page_budget !== undefined){
let data25 = data23.page_budget;
const _errs62 = errors;
if(!(((typeof data25 == "number") && (!(data25 % 1) && !isNaN(data25))) && (isFinite(data25)))){
const err6 = {instancePath:instancePath+"/bindings/" + i2+"/source/inspection/page_budget",schemaPath:"#/$defs/Binding/properties/source/oneOf/0/properties/inspection/properties/page_budget/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err6];
}
else {
vErrors.push(err6);
}
errors++;
}
if(errors === _errs62){
if((typeof data25 == "number") && (isFinite(data25))){
if(data25 > 255 || isNaN(data25)){
const err7 = {instancePath:instancePath+"/bindings/" + i2+"/source/inspection/page_budget",schemaPath:"#/$defs/Binding/properties/source/oneOf/0/properties/inspection/properties/page_budget/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err7];
}
else {
vErrors.push(err7);
}
errors++;
}
else {
if(data25 < 0 || isNaN(data25)){
const err8 = {instancePath:instancePath+"/bindings/" + i2+"/source/inspection/page_budget",schemaPath:"#/$defs/Binding/properties/source/oneOf/0/properties/inspection/properties/page_budget/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid12 = _errs62 === errors;
}
else {
var valid12 = true;
}
}
}
}
}
else {
const err9 = {instancePath:instancePath+"/bindings/" + i2+"/source/inspection",schemaPath:"#/$defs/Binding/properties/source/oneOf/0/properties/inspection/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
}
else {
const err10 = {instancePath:instancePath+"/bindings/" + i2+"/source",schemaPath:"#/$defs/Binding/properties/source/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
}
}
var _valid0 = _errs54 === errors;
if(_valid0){
valid10 = true;
passing0 = 0;
var props0 = true;
}
const _errs64 = errors;
if(errors === _errs64){
if(data22 && typeof data22 == "object" && !Array.isArray(data22)){
let missing6;
if((data22.query === undefined) && (missing6 = "query")){
const err11 = {instancePath:instancePath+"/bindings/" + i2+"/source",schemaPath:"#/$defs/Binding/properties/source/oneOf/1/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
if(vErrors === null){
vErrors = [err11];
}
else {
vErrors.push(err11);
}
errors++;
}
else {
const _errs66 = errors;
for(const key6 in data22){
if(!(key6 === "query")){
const err12 = {instancePath:instancePath+"/bindings/" + i2+"/source",schemaPath:"#/$defs/Binding/properties/source/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
if(_errs66 === errors){
if(data22.query !== undefined){
let data26 = data22.query;
const _errs67 = errors;
if(errors === _errs67){
if(data26 && typeof data26 == "object" && !Array.isArray(data26)){
let missing7;
if(((((((data26.resource === undefined) && (missing7 = "resource")) || ((data26.name === undefined) && (missing7 = "name"))) || ((data26.source_kind === undefined) && (missing7 = "source_kind"))) || ((data26.schema === undefined) && (missing7 = "schema"))) || ((data26.profile === undefined) && (missing7 = "profile"))) || ((data26.sql === undefined) && (missing7 = "sql"))){
const err13 = {instancePath:instancePath+"/bindings/" + i2+"/source/query",schemaPath:"#/$defs/Binding/properties/source/oneOf/1/properties/query/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
if(vErrors === null){
vErrors = [err13];
}
else {
vErrors.push(err13);
}
errors++;
}
else {
const _errs69 = errors;
for(const key7 in data26){
if(!((((((((key7 === "resource") || (key7 === "name")) || (key7 === "source_kind")) || (key7 === "schema")) || (key7 === "profile")) || (key7 === "sql")) || (key7 === "refresh")) || (key7 === "starts"))){
const err14 = {instancePath:instancePath+"/bindings/" + i2+"/source/query",schemaPath:"#/$defs/Binding/properties/source/oneOf/1/properties/query/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
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
if(_errs69 === errors){
if(data26.resource !== undefined){
let data27 = data26.resource;
const _errs70 = errors;
if(!(((typeof data27 == "number") && (!(data27 % 1) && !isNaN(data27))) && (isFinite(data27)))){
const err15 = {instancePath:instancePath+"/bindings/" + i2+"/source/query/resource",schemaPath:"#/$defs/Binding/properties/source/oneOf/1/properties/query/properties/resource/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
}
if(errors === _errs70){
if((typeof data27 == "number") && (isFinite(data27))){
if(data27 > 9007199254740991 || isNaN(data27)){
const err16 = {instancePath:instancePath+"/bindings/" + i2+"/source/query/resource",schemaPath:"#/$defs/Binding/properties/source/oneOf/1/properties/query/properties/resource/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err16];
}
else {
vErrors.push(err16);
}
errors++;
}
else {
if(data27 < 0 || isNaN(data27)){
const err17 = {instancePath:instancePath+"/bindings/" + i2+"/source/query/resource",schemaPath:"#/$defs/Binding/properties/source/oneOf/1/properties/query/properties/resource/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid14 = _errs70 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data26.name !== undefined){
let data28 = data26.name;
const _errs72 = errors;
if(errors === _errs72){
if(typeof data28 === "string"){
if(func2(data28) > 64){
const err18 = {instancePath:instancePath+"/bindings/" + i2+"/source/query/name",schemaPath:"#/$defs/Binding/properties/source/oneOf/1/properties/query/properties/name/maxLength",keyword:"maxLength",params:{limit: 64},message:"must NOT have more than 64 characters"};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
}
else {
if(func2(data28) < 1){
const err19 = {instancePath:instancePath+"/bindings/" + i2+"/source/query/name",schemaPath:"#/$defs/Binding/properties/source/oneOf/1/properties/query/properties/name/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
}
else {
if(!pattern4.test(data28)){
const err20 = {instancePath:instancePath+"/bindings/" + i2+"/source/query/name",schemaPath:"#/$defs/Binding/properties/source/oneOf/1/properties/query/properties/name/pattern",keyword:"pattern",params:{pattern: "^[A-Za-z_][A-Za-z_0-9]*$"},message:"must match pattern \""+"^[A-Za-z_][A-Za-z_0-9]*$"+"\""};
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
else {
const err21 = {instancePath:instancePath+"/bindings/" + i2+"/source/query/name",schemaPath:"#/$defs/Binding/properties/source/oneOf/1/properties/query/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
}
errors++;
}
}
var valid14 = _errs72 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data26.source_kind !== undefined){
let data29 = data26.source_kind;
const _errs74 = errors;
if(typeof data29 !== "string"){
const err22 = {instancePath:instancePath+"/bindings/" + i2+"/source/query/source_kind",schemaPath:"#/$defs/Binding/properties/source/oneOf/1/properties/query/properties/source_kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err22];
}
else {
vErrors.push(err22);
}
errors++;
}
if(!(((data29 === "table") || (data29 === "kv")) || (data29 === "document"))){
const err23 = {instancePath:instancePath+"/bindings/" + i2+"/source/query/source_kind",schemaPath:"#/$defs/Binding/properties/source/oneOf/1/properties/query/properties/source_kind/enum",keyword:"enum",params:{allowedValues: schema35.properties.source.oneOf[1].properties.query.properties.source_kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err23];
}
else {
vErrors.push(err23);
}
errors++;
}
var valid14 = _errs74 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data26.schema !== undefined){
let data30 = data26.schema;
const _errs76 = errors;
if(errors === _errs76){
if(Array.isArray(data30)){
if(data30.length > 32){
const err24 = {instancePath:instancePath+"/bindings/" + i2+"/source/query/schema",schemaPath:"#/$defs/Binding/properties/source/oneOf/1/properties/query/properties/schema/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
}
errors++;
}
else {
if(data30.length < 32){
const err25 = {instancePath:instancePath+"/bindings/" + i2+"/source/query/schema",schemaPath:"#/$defs/Binding/properties/source/oneOf/1/properties/query/properties/schema/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err25];
}
else {
vErrors.push(err25);
}
errors++;
}
else {
var valid15 = true;
const len3 = data30.length;
for(let i3=0; i3<len3; i3++){
let data31 = data30[i3];
const _errs78 = errors;
if(!(((typeof data31 == "number") && (!(data31 % 1) && !isNaN(data31))) && (isFinite(data31)))){
const err26 = {instancePath:instancePath+"/bindings/" + i2+"/source/query/schema/" + i3,schemaPath:"#/$defs/Binding/properties/source/oneOf/1/properties/query/properties/schema/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err26];
}
else {
vErrors.push(err26);
}
errors++;
}
if(errors === _errs78){
if((typeof data31 == "number") && (isFinite(data31))){
if(data31 > 255 || isNaN(data31)){
const err27 = {instancePath:instancePath+"/bindings/" + i2+"/source/query/schema/" + i3,schemaPath:"#/$defs/Binding/properties/source/oneOf/1/properties/query/properties/schema/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err27];
}
else {
vErrors.push(err27);
}
errors++;
}
else {
if(data31 < 0 || isNaN(data31)){
const err28 = {instancePath:instancePath+"/bindings/" + i2+"/source/query/schema/" + i3,schemaPath:"#/$defs/Binding/properties/source/oneOf/1/properties/query/properties/schema/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err28];
}
else {
vErrors.push(err28);
}
errors++;
}
}
}
}
var valid15 = _errs78 === errors;
if(!valid15){
break;
}
}
}
}
}
else {
const err29 = {instancePath:instancePath+"/bindings/" + i2+"/source/query/schema",schemaPath:"#/$defs/Binding/properties/source/oneOf/1/properties/query/properties/schema/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err29];
}
else {
vErrors.push(err29);
}
errors++;
}
}
var valid14 = _errs76 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data26.profile !== undefined){
let data32 = data26.profile;
const _errs80 = errors;
if(typeof data32 !== "string"){
const err30 = {instancePath:instancePath+"/bindings/" + i2+"/source/query/profile",schemaPath:"#/$defs/Binding/properties/source/oneOf/1/properties/query/properties/profile/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
}
errors++;
}
if(!((data32 === "table_v1") || (data32 === "unified_v2"))){
const err31 = {instancePath:instancePath+"/bindings/" + i2+"/source/query/profile",schemaPath:"#/$defs/Binding/properties/source/oneOf/1/properties/query/properties/profile/enum",keyword:"enum",params:{allowedValues: schema35.properties.source.oneOf[1].properties.query.properties.profile.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err31];
}
else {
vErrors.push(err31);
}
errors++;
}
var valid14 = _errs80 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data26.sql !== undefined){
let data33 = data26.sql;
const _errs82 = errors;
if(errors === _errs82){
if(typeof data33 === "string"){
if(func2(data33) > 4096){
const err32 = {instancePath:instancePath+"/bindings/" + i2+"/source/query/sql",schemaPath:"#/$defs/Binding/properties/source/oneOf/1/properties/query/properties/sql/maxLength",keyword:"maxLength",params:{limit: 4096},message:"must NOT have more than 4096 characters"};
if(vErrors === null){
vErrors = [err32];
}
else {
vErrors.push(err32);
}
errors++;
}
else {
if(func2(data33) < 1){
const err33 = {instancePath:instancePath+"/bindings/" + i2+"/source/query/sql",schemaPath:"#/$defs/Binding/properties/source/oneOf/1/properties/query/properties/sql/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"};
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
else {
const err34 = {instancePath:instancePath+"/bindings/" + i2+"/source/query/sql",schemaPath:"#/$defs/Binding/properties/source/oneOf/1/properties/query/properties/sql/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err34];
}
else {
vErrors.push(err34);
}
errors++;
}
}
var valid14 = _errs82 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data26.refresh !== undefined){
let data34 = data26.refresh;
const _errs84 = errors;
if(typeof data34 !== "string"){
const err35 = {instancePath:instancePath+"/bindings/" + i2+"/source/query/refresh",schemaPath:"#/$defs/Binding/properties/source/oneOf/1/properties/query/properties/refresh/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err35];
}
else {
vErrors.push(err35);
}
errors++;
}
if(!((data34 === "snapshot") || (data34 === "follow"))){
const err36 = {instancePath:instancePath+"/bindings/" + i2+"/source/query/refresh",schemaPath:"#/$defs/Binding/properties/source/oneOf/1/properties/query/properties/refresh/enum",keyword:"enum",params:{allowedValues: schema35.properties.source.oneOf[1].properties.query.properties.refresh.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
}
var valid14 = _errs84 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data26.starts !== undefined){
let data35 = data26.starts;
const _errs86 = errors;
if(!(((typeof data35 == "number") && (!(data35 % 1) && !isNaN(data35))) && (isFinite(data35)))){
const err37 = {instancePath:instancePath+"/bindings/" + i2+"/source/query/starts",schemaPath:"#/$defs/Binding/properties/source/oneOf/1/properties/query/properties/starts/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err37];
}
else {
vErrors.push(err37);
}
errors++;
}
if(errors === _errs86){
if((typeof data35 == "number") && (isFinite(data35))){
if(data35 > 255 || isNaN(data35)){
const err38 = {instancePath:instancePath+"/bindings/" + i2+"/source/query/starts",schemaPath:"#/$defs/Binding/properties/source/oneOf/1/properties/query/properties/starts/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err38];
}
else {
vErrors.push(err38);
}
errors++;
}
else {
if(data35 < 0 || isNaN(data35)){
const err39 = {instancePath:instancePath+"/bindings/" + i2+"/source/query/starts",schemaPath:"#/$defs/Binding/properties/source/oneOf/1/properties/query/properties/starts/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid14 = _errs86 === errors;
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
else {
const err40 = {instancePath:instancePath+"/bindings/" + i2+"/source/query",schemaPath:"#/$defs/Binding/properties/source/oneOf/1/properties/query/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err40];
}
else {
vErrors.push(err40);
}
errors++;
}
}
}
}
}
}
else {
const err41 = {instancePath:instancePath+"/bindings/" + i2+"/source",schemaPath:"#/$defs/Binding/properties/source/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err41];
}
else {
vErrors.push(err41);
}
errors++;
}
}
var _valid0 = _errs64 === errors;
if(_valid0 && valid10){
valid10 = false;
passing0 = [passing0, 1];
}
else {
if(_valid0){
valid10 = true;
passing0 = 1;
if(props0 !== true){
props0 = true;
}
}
const _errs88 = errors;
if(errors === _errs88){
if(data22 && typeof data22 == "object" && !Array.isArray(data22)){
let missing8;
if((data22.command === undefined) && (missing8 = "command")){
const err42 = {instancePath:instancePath+"/bindings/" + i2+"/source",schemaPath:"#/$defs/Binding/properties/source/oneOf/2/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
if(vErrors === null){
vErrors = [err42];
}
else {
vErrors.push(err42);
}
errors++;
}
else {
const _errs90 = errors;
for(const key8 in data22){
if(!(key8 === "command")){
const err43 = {instancePath:instancePath+"/bindings/" + i2+"/source",schemaPath:"#/$defs/Binding/properties/source/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
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
if(_errs90 === errors){
if(data22.command !== undefined){
let data36 = data22.command;
const _errs91 = errors;
if(errors === _errs91){
if(data36 && typeof data36 == "object" && !Array.isArray(data36)){
let missing9;
if(((((data36.service === undefined) && (missing9 = "service")) || ((data36.target === undefined) && (missing9 = "target"))) || ((data36.revision === undefined) && (missing9 = "revision"))) || ((data36.codec === undefined) && (missing9 = "codec"))){
const err44 = {instancePath:instancePath+"/bindings/" + i2+"/source/command",schemaPath:"#/$defs/Binding/properties/source/oneOf/2/properties/command/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
if(vErrors === null){
vErrors = [err44];
}
else {
vErrors.push(err44);
}
errors++;
}
else {
const _errs93 = errors;
for(const key9 in data36){
if(!((((key9 === "service") || (key9 === "target")) || (key9 === "revision")) || (key9 === "codec"))){
const err45 = {instancePath:instancePath+"/bindings/" + i2+"/source/command",schemaPath:"#/$defs/Binding/properties/source/oneOf/2/properties/command/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
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
if(_errs93 === errors){
if(data36.service !== undefined){
let data37 = data36.service;
const _errs94 = errors;
if(!(((typeof data37 == "number") && (!(data37 % 1) && !isNaN(data37))) && (isFinite(data37)))){
const err46 = {instancePath:instancePath+"/bindings/" + i2+"/source/command/service",schemaPath:"#/$defs/Binding/properties/source/oneOf/2/properties/command/properties/service/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err46];
}
else {
vErrors.push(err46);
}
errors++;
}
if(errors === _errs94){
if((typeof data37 == "number") && (isFinite(data37))){
if(data37 > 9007199254740991 || isNaN(data37)){
const err47 = {instancePath:instancePath+"/bindings/" + i2+"/source/command/service",schemaPath:"#/$defs/Binding/properties/source/oneOf/2/properties/command/properties/service/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err47];
}
else {
vErrors.push(err47);
}
errors++;
}
else {
if(data37 < 0 || isNaN(data37)){
const err48 = {instancePath:instancePath+"/bindings/" + i2+"/source/command/service",schemaPath:"#/$defs/Binding/properties/source/oneOf/2/properties/command/properties/service/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid17 = _errs94 === errors;
}
else {
var valid17 = true;
}
if(valid17){
if(data36.target !== undefined){
let data38 = data36.target;
const _errs96 = errors;
if(!(((typeof data38 == "number") && (!(data38 % 1) && !isNaN(data38))) && (isFinite(data38)))){
const err49 = {instancePath:instancePath+"/bindings/" + i2+"/source/command/target",schemaPath:"#/$defs/Binding/properties/source/oneOf/2/properties/command/properties/target/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err49];
}
else {
vErrors.push(err49);
}
errors++;
}
if(errors === _errs96){
if((typeof data38 == "number") && (isFinite(data38))){
if(data38 > 9007199254740991 || isNaN(data38)){
const err50 = {instancePath:instancePath+"/bindings/" + i2+"/source/command/target",schemaPath:"#/$defs/Binding/properties/source/oneOf/2/properties/command/properties/target/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err50];
}
else {
vErrors.push(err50);
}
errors++;
}
else {
if(data38 < 0 || isNaN(data38)){
const err51 = {instancePath:instancePath+"/bindings/" + i2+"/source/command/target",schemaPath:"#/$defs/Binding/properties/source/oneOf/2/properties/command/properties/target/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid17 = _errs96 === errors;
}
else {
var valid17 = true;
}
if(valid17){
if(data36.revision !== undefined){
let data39 = data36.revision;
const _errs98 = errors;
if(!(((typeof data39 == "number") && (!(data39 % 1) && !isNaN(data39))) && (isFinite(data39)))){
const err52 = {instancePath:instancePath+"/bindings/" + i2+"/source/command/revision",schemaPath:"#/$defs/Binding/properties/source/oneOf/2/properties/command/properties/revision/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err52];
}
else {
vErrors.push(err52);
}
errors++;
}
if(errors === _errs98){
if((typeof data39 == "number") && (isFinite(data39))){
if(data39 > 9007199254740991 || isNaN(data39)){
const err53 = {instancePath:instancePath+"/bindings/" + i2+"/source/command/revision",schemaPath:"#/$defs/Binding/properties/source/oneOf/2/properties/command/properties/revision/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err53];
}
else {
vErrors.push(err53);
}
errors++;
}
else {
if(data39 < 0 || isNaN(data39)){
const err54 = {instancePath:instancePath+"/bindings/" + i2+"/source/command/revision",schemaPath:"#/$defs/Binding/properties/source/oneOf/2/properties/command/properties/revision/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid17 = _errs98 === errors;
}
else {
var valid17 = true;
}
if(valid17){
if(data36.codec !== undefined){
let data40 = data36.codec;
const _errs100 = errors;
if(!(((typeof data40 == "number") && (!(data40 % 1) && !isNaN(data40))) && (isFinite(data40)))){
const err55 = {instancePath:instancePath+"/bindings/" + i2+"/source/command/codec",schemaPath:"#/$defs/Binding/properties/source/oneOf/2/properties/command/properties/codec/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err55];
}
else {
vErrors.push(err55);
}
errors++;
}
if(errors === _errs100){
if((typeof data40 == "number") && (isFinite(data40))){
if(data40 > 65535 || isNaN(data40)){
const err56 = {instancePath:instancePath+"/bindings/" + i2+"/source/command/codec",schemaPath:"#/$defs/Binding/properties/source/oneOf/2/properties/command/properties/codec/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
if(vErrors === null){
vErrors = [err56];
}
else {
vErrors.push(err56);
}
errors++;
}
else {
if(data40 < 0 || isNaN(data40)){
const err57 = {instancePath:instancePath+"/bindings/" + i2+"/source/command/codec",schemaPath:"#/$defs/Binding/properties/source/oneOf/2/properties/command/properties/codec/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid17 = _errs100 === errors;
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
else {
const err58 = {instancePath:instancePath+"/bindings/" + i2+"/source/command",schemaPath:"#/$defs/Binding/properties/source/oneOf/2/properties/command/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
else {
const err59 = {instancePath:instancePath+"/bindings/" + i2+"/source",schemaPath:"#/$defs/Binding/properties/source/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err59];
}
else {
vErrors.push(err59);
}
errors++;
}
}
var _valid0 = _errs88 === errors;
if(_valid0 && valid10){
valid10 = false;
passing0 = [passing0, 2];
}
else {
if(_valid0){
valid10 = true;
passing0 = 2;
if(props0 !== true){
props0 = true;
}
}
}
}
if(!valid10){
const err60 = {instancePath:instancePath+"/bindings/" + i2+"/source",schemaPath:"#/$defs/Binding/properties/source/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err60];
}
else {
vErrors.push(err60);
}
errors++;
validate23.errors = vErrors;
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
var valid9 = _errs52 === errors;
}
else {
var valid9 = true;
}
}
}
}
}
else {
validate23.errors = [{instancePath:instancePath+"/bindings/" + i2,schemaPath:"#/$defs/Binding/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
var valid7 = _errs46 === errors;
if(!valid7){
break;
}
}
}
}
else {
validate23.errors = [{instancePath:instancePath+"/bindings",schemaPath:"#/properties/bindings/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid0 = _errs44 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.actions !== undefined){
let data41 = data.actions;
const _errs102 = errors;
if(errors === _errs102){
if(Array.isArray(data41)){
if(data41.length > 16){
validate23.errors = [{instancePath:instancePath+"/actions",schemaPath:"#/properties/actions/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
var valid18 = true;
const len4 = data41.length;
for(let i4=0; i4<len4; i4++){
let data42 = data41[i4];
const _errs104 = errors;
const _errs105 = errors;
if(errors === _errs105){
if(data42 && typeof data42 == "object" && !Array.isArray(data42)){
let missing10;
if((((data42.name === undefined) && (missing10 = "name")) || ((data42.label === undefined) && (missing10 = "label"))) || ((data42.target === undefined) && (missing10 = "target"))){
validate23.errors = [{instancePath:instancePath+"/actions/" + i4,schemaPath:"#/$defs/Action/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"}];
return false;
}
else {
const _errs107 = errors;
for(const key10 in data42){
if(!(((key10 === "name") || (key10 === "label")) || (key10 === "target"))){
validate23.errors = [{instancePath:instancePath+"/actions/" + i4,schemaPath:"#/$defs/Action/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs107 === errors){
if(data42.name !== undefined){
let data43 = data42.name;
const _errs108 = errors;
if(errors === _errs108){
if(typeof data43 === "string"){
if(func2(data43) > 64){
validate23.errors = [{instancePath:instancePath+"/actions/" + i4+"/name",schemaPath:"#/$defs/Action/properties/name/maxLength",keyword:"maxLength",params:{limit: 64},message:"must NOT have more than 64 characters"}];
return false;
}
else {
if(func2(data43) < 1){
validate23.errors = [{instancePath:instancePath+"/actions/" + i4+"/name",schemaPath:"#/$defs/Action/properties/name/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"}];
return false;
}
else {
if(!pattern4.test(data43)){
validate23.errors = [{instancePath:instancePath+"/actions/" + i4+"/name",schemaPath:"#/$defs/Action/properties/name/pattern",keyword:"pattern",params:{pattern: "^[A-Za-z_][A-Za-z_0-9]*$"},message:"must match pattern \""+"^[A-Za-z_][A-Za-z_0-9]*$"+"\""}];
return false;
}
}
}
}
else {
validate23.errors = [{instancePath:instancePath+"/actions/" + i4+"/name",schemaPath:"#/$defs/Action/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid20 = _errs108 === errors;
}
else {
var valid20 = true;
}
if(valid20){
if(data42.label !== undefined){
let data44 = data42.label;
const _errs110 = errors;
if(errors === _errs110){
if(typeof data44 === "string"){
if(func2(data44) > 128){
validate23.errors = [{instancePath:instancePath+"/actions/" + i4+"/label",schemaPath:"#/$defs/Action/properties/label/maxLength",keyword:"maxLength",params:{limit: 128},message:"must NOT have more than 128 characters"}];
return false;
}
else {
if(func2(data44) < 1){
validate23.errors = [{instancePath:instancePath+"/actions/" + i4+"/label",schemaPath:"#/$defs/Action/properties/label/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"}];
return false;
}
}
}
else {
validate23.errors = [{instancePath:instancePath+"/actions/" + i4+"/label",schemaPath:"#/$defs/Action/properties/label/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid20 = _errs110 === errors;
}
else {
var valid20 = true;
}
if(valid20){
if(data42.target !== undefined){
let data45 = data42.target;
const _errs112 = errors;
const _errs113 = errors;
let valid21 = false;
let passing1 = null;
const _errs114 = errors;
if(errors === _errs114){
if(data45 && typeof data45 == "object" && !Array.isArray(data45)){
let missing11;
if((data45.navigate === undefined) && (missing11 = "navigate")){
const err61 = {instancePath:instancePath+"/actions/" + i4+"/target",schemaPath:"#/$defs/Action/properties/target/oneOf/0/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
if(vErrors === null){
vErrors = [err61];
}
else {
vErrors.push(err61);
}
errors++;
}
else {
const _errs116 = errors;
for(const key11 in data45){
if(!(key11 === "navigate")){
const err62 = {instancePath:instancePath+"/actions/" + i4+"/target",schemaPath:"#/$defs/Action/properties/target/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err62];
}
else {
vErrors.push(err62);
}
errors++;
break;
}
}
if(_errs116 === errors){
if(data45.navigate !== undefined){
let data46 = data45.navigate;
const _errs117 = errors;
if(errors === _errs117){
if(typeof data46 === "string"){
if(func2(data46) > 256){
const err63 = {instancePath:instancePath+"/actions/" + i4+"/target/navigate",schemaPath:"#/$defs/Action/properties/target/oneOf/0/properties/navigate/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
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
const err64 = {instancePath:instancePath+"/actions/" + i4+"/target/navigate",schemaPath:"#/$defs/Action/properties/target/oneOf/0/properties/navigate/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
const err65 = {instancePath:instancePath+"/actions/" + i4+"/target",schemaPath:"#/$defs/Action/properties/target/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err65];
}
else {
vErrors.push(err65);
}
errors++;
}
}
var _valid1 = _errs114 === errors;
if(_valid1){
valid21 = true;
passing1 = 0;
var props1 = true;
}
const _errs119 = errors;
if(errors === _errs119){
if(data45 && typeof data45 == "object" && !Array.isArray(data45)){
let missing12;
if((data45.command === undefined) && (missing12 = "command")){
const err66 = {instancePath:instancePath+"/actions/" + i4+"/target",schemaPath:"#/$defs/Action/properties/target/oneOf/1/required",keyword:"required",params:{missingProperty: missing12},message:"must have required property '"+missing12+"'"};
if(vErrors === null){
vErrors = [err66];
}
else {
vErrors.push(err66);
}
errors++;
}
else {
const _errs121 = errors;
for(const key12 in data45){
if(!(key12 === "command")){
const err67 = {instancePath:instancePath+"/actions/" + i4+"/target",schemaPath:"#/$defs/Action/properties/target/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key12},message:"must NOT have additional properties"};
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
if(_errs121 === errors){
if(data45.command !== undefined){
let data47 = data45.command;
const _errs122 = errors;
if(errors === _errs122){
if(typeof data47 === "string"){
if(func2(data47) > 256){
const err68 = {instancePath:instancePath+"/actions/" + i4+"/target/command",schemaPath:"#/$defs/Action/properties/target/oneOf/1/properties/command/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
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
const err69 = {instancePath:instancePath+"/actions/" + i4+"/target/command",schemaPath:"#/$defs/Action/properties/target/oneOf/1/properties/command/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
const err70 = {instancePath:instancePath+"/actions/" + i4+"/target",schemaPath:"#/$defs/Action/properties/target/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err70];
}
else {
vErrors.push(err70);
}
errors++;
}
}
var _valid1 = _errs119 === errors;
if(_valid1 && valid21){
valid21 = false;
passing1 = [passing1, 1];
}
else {
if(_valid1){
valid21 = true;
passing1 = 1;
if(props1 !== true){
props1 = true;
}
}
const _errs124 = errors;
if(errors === _errs124){
if(data45 && typeof data45 == "object" && !Array.isArray(data45)){
let missing13;
if((data45.follow === undefined) && (missing13 = "follow")){
const err71 = {instancePath:instancePath+"/actions/" + i4+"/target",schemaPath:"#/$defs/Action/properties/target/oneOf/2/required",keyword:"required",params:{missingProperty: missing13},message:"must have required property '"+missing13+"'"};
if(vErrors === null){
vErrors = [err71];
}
else {
vErrors.push(err71);
}
errors++;
}
else {
const _errs126 = errors;
for(const key13 in data45){
if(!(key13 === "follow")){
const err72 = {instancePath:instancePath+"/actions/" + i4+"/target",schemaPath:"#/$defs/Action/properties/target/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key13},message:"must NOT have additional properties"};
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
if(_errs126 === errors){
if(data45.follow !== undefined){
let data48 = data45.follow;
const _errs127 = errors;
if(errors === _errs127){
if(typeof data48 === "string"){
if(func2(data48) > 256){
const err73 = {instancePath:instancePath+"/actions/" + i4+"/target/follow",schemaPath:"#/$defs/Action/properties/target/oneOf/2/properties/follow/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err73];
}
else {
vErrors.push(err73);
}
errors++;
}
}
else {
const err74 = {instancePath:instancePath+"/actions/" + i4+"/target/follow",schemaPath:"#/$defs/Action/properties/target/oneOf/2/properties/follow/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
const err75 = {instancePath:instancePath+"/actions/" + i4+"/target",schemaPath:"#/$defs/Action/properties/target/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err75];
}
else {
vErrors.push(err75);
}
errors++;
}
}
var _valid1 = _errs124 === errors;
if(_valid1 && valid21){
valid21 = false;
passing1 = [passing1, 2];
}
else {
if(_valid1){
valid21 = true;
passing1 = 2;
if(props1 !== true){
props1 = true;
}
}
}
}
if(!valid21){
const err76 = {instancePath:instancePath+"/actions/" + i4+"/target",schemaPath:"#/$defs/Action/properties/target/oneOf",keyword:"oneOf",params:{passingSchemas: passing1},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err76];
}
else {
vErrors.push(err76);
}
errors++;
validate23.errors = vErrors;
return false;
}
else {
errors = _errs113;
if(vErrors !== null){
if(_errs113){
vErrors.length = _errs113;
}
else {
vErrors = null;
}
}
}
var valid20 = _errs112 === errors;
}
else {
var valid20 = true;
}
}
}
}
}
}
else {
validate23.errors = [{instancePath:instancePath+"/actions/" + i4,schemaPath:"#/$defs/Action/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
var valid18 = _errs104 === errors;
if(!valid18){
break;
}
}
}
}
else {
validate23.errors = [{instancePath:instancePath+"/actions",schemaPath:"#/properties/actions/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid0 = _errs102 === errors;
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
validate23.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate23.errors = vErrors;
return errors === 0;
}
validate23.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Theme = validate24;

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
if(((data.name === undefined) && (missing0 = "name")) || ((data.density === undefined) && (missing0 = "density"))){
validate24.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "name") || (key0 === "density"))){
validate24.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
if(func2(data0) > 64){
validate24.errors = [{instancePath:instancePath+"/name",schemaPath:"#/properties/name/maxLength",keyword:"maxLength",params:{limit: 64},message:"must NOT have more than 64 characters"}];
return false;
}
else {
if(func2(data0) < 1){
validate24.errors = [{instancePath:instancePath+"/name",schemaPath:"#/properties/name/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"}];
return false;
}
else {
if(!pattern4.test(data0)){
validate24.errors = [{instancePath:instancePath+"/name",schemaPath:"#/properties/name/pattern",keyword:"pattern",params:{pattern: "^[A-Za-z_][A-Za-z_0-9]*$"},message:"must match pattern \""+"^[A-Za-z_][A-Za-z_0-9]*$"+"\""}];
return false;
}
}
}
}
else {
validate24.errors = [{instancePath:instancePath+"/name",schemaPath:"#/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.density !== undefined){
let data1 = data.density;
const _errs4 = errors;
if(typeof data1 !== "string"){
validate24.errors = [{instancePath:instancePath+"/density",schemaPath:"#/properties/density/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((data1 === "comfortable") || (data1 === "compact"))){
validate24.errors = [{instancePath:instancePath+"/density",schemaPath:"#/properties/density/enum",keyword:"enum",params:{allowedValues: schema33.properties.density.enum},message:"must be equal to one of the allowed values"}];
return false;
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
validate24.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate24.errors = vErrors;
return errors === 0;
}
validate24.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Screen = validate25;

function validate25(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate25.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((data.name === undefined) && (missing0 = "name")) || ((data.path === undefined) && (missing0 = "path"))) || ((data.label === undefined) && (missing0 = "label"))) || ((data.area === undefined) && (missing0 = "area"))) || ((data.renderer === undefined) && (missing0 = "renderer"))) || ((data.binding === undefined) && (missing0 = "binding"))){
validate25.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "name") || (key0 === "path")) || (key0 === "label")) || (key0 === "area")) || (key0 === "renderer")) || (key0 === "binding"))){
validate25.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
if(func2(data0) > 64){
validate25.errors = [{instancePath:instancePath+"/name",schemaPath:"#/properties/name/maxLength",keyword:"maxLength",params:{limit: 64},message:"must NOT have more than 64 characters"}];
return false;
}
else {
if(func2(data0) < 1){
validate25.errors = [{instancePath:instancePath+"/name",schemaPath:"#/properties/name/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"}];
return false;
}
else {
if(!pattern4.test(data0)){
validate25.errors = [{instancePath:instancePath+"/name",schemaPath:"#/properties/name/pattern",keyword:"pattern",params:{pattern: "^[A-Za-z_][A-Za-z_0-9]*$"},message:"must match pattern \""+"^[A-Za-z_][A-Za-z_0-9]*$"+"\""}];
return false;
}
}
}
}
else {
validate25.errors = [{instancePath:instancePath+"/name",schemaPath:"#/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.path !== undefined){
let data1 = data.path;
const _errs4 = errors;
if(errors === _errs4){
if(typeof data1 === "string"){
if(func2(data1) > 128){
validate25.errors = [{instancePath:instancePath+"/path",schemaPath:"#/properties/path/maxLength",keyword:"maxLength",params:{limit: 128},message:"must NOT have more than 128 characters"}];
return false;
}
else {
if(func2(data1) < 1){
validate25.errors = [{instancePath:instancePath+"/path",schemaPath:"#/properties/path/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"}];
return false;
}
else {
if(!pattern10.test(data1)){
validate25.errors = [{instancePath:instancePath+"/path",schemaPath:"#/properties/path/pattern",keyword:"pattern",params:{pattern: "^/[A-Za-z_0-9/-]*$"},message:"must match pattern \""+"^/[A-Za-z_0-9/-]*$"+"\""}];
return false;
}
}
}
}
else {
validate25.errors = [{instancePath:instancePath+"/path",schemaPath:"#/properties/path/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.label !== undefined){
let data2 = data.label;
const _errs6 = errors;
if(errors === _errs6){
if(typeof data2 === "string"){
if(func2(data2) > 128){
validate25.errors = [{instancePath:instancePath+"/label",schemaPath:"#/properties/label/maxLength",keyword:"maxLength",params:{limit: 128},message:"must NOT have more than 128 characters"}];
return false;
}
else {
if(func2(data2) < 1){
validate25.errors = [{instancePath:instancePath+"/label",schemaPath:"#/properties/label/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"}];
return false;
}
}
}
else {
validate25.errors = [{instancePath:instancePath+"/label",schemaPath:"#/properties/label/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.area !== undefined){
let data3 = data.area;
const _errs8 = errors;
if(typeof data3 !== "string"){
validate25.errors = [{instancePath:instancePath+"/area",schemaPath:"#/properties/area/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((data3 === "workspace") || (data3 === "operations"))){
validate25.errors = [{instancePath:instancePath+"/area",schemaPath:"#/properties/area/enum",keyword:"enum",params:{allowedValues: schema34.properties.area.enum},message:"must be equal to one of the allowed values"}];
return false;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.renderer !== undefined){
let data4 = data.renderer;
const _errs10 = errors;
if(typeof data4 !== "string"){
validate25.errors = [{instancePath:instancePath+"/renderer",schemaPath:"#/properties/renderer/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((data4 === "atlas") || (data4 === "worksheet")) || (data4 === "records")) || (data4 === "activity")) || (data4 === "definition")) || (data4 === "operations")) || (data4 === "work_items"))){
validate25.errors = [{instancePath:instancePath+"/renderer",schemaPath:"#/properties/renderer/enum",keyword:"enum",params:{allowedValues: schema34.properties.renderer.enum},message:"must be equal to one of the allowed values"}];
return false;
}
var valid0 = _errs10 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.binding !== undefined){
let data5 = data.binding;
const _errs12 = errors;
if(errors === _errs12){
if(typeof data5 === "string"){
if(func2(data5) > 64){
validate25.errors = [{instancePath:instancePath+"/binding",schemaPath:"#/properties/binding/maxLength",keyword:"maxLength",params:{limit: 64},message:"must NOT have more than 64 characters"}];
return false;
}
else {
if(func2(data5) < 1){
validate25.errors = [{instancePath:instancePath+"/binding",schemaPath:"#/properties/binding/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"}];
return false;
}
else {
if(!pattern4.test(data5)){
validate25.errors = [{instancePath:instancePath+"/binding",schemaPath:"#/properties/binding/pattern",keyword:"pattern",params:{pattern: "^[A-Za-z_][A-Za-z_0-9]*$"},message:"must match pattern \""+"^[A-Za-z_][A-Za-z_0-9]*$"+"\""}];
return false;
}
}
}
}
else {
validate25.errors = [{instancePath:instancePath+"/binding",schemaPath:"#/properties/binding/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
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
else {
validate25.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate25.errors = vErrors;
return errors === 0;
}
validate25.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Binding = validate26;

function validate26(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate26.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.name === undefined) && (missing0 = "name")) || ((data.source === undefined) && (missing0 = "source"))){
validate26.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "name") || (key0 === "source"))){
validate26.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
if(func2(data0) > 64){
validate26.errors = [{instancePath:instancePath+"/name",schemaPath:"#/properties/name/maxLength",keyword:"maxLength",params:{limit: 64},message:"must NOT have more than 64 characters"}];
return false;
}
else {
if(func2(data0) < 1){
validate26.errors = [{instancePath:instancePath+"/name",schemaPath:"#/properties/name/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"}];
return false;
}
else {
if(!pattern4.test(data0)){
validate26.errors = [{instancePath:instancePath+"/name",schemaPath:"#/properties/name/pattern",keyword:"pattern",params:{pattern: "^[A-Za-z_][A-Za-z_0-9]*$"},message:"must match pattern \""+"^[A-Za-z_][A-Za-z_0-9]*$"+"\""}];
return false;
}
}
}
}
else {
validate26.errors = [{instancePath:instancePath+"/name",schemaPath:"#/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.source !== undefined){
let data1 = data.source;
const _errs4 = errors;
const _errs5 = errors;
let valid1 = false;
let passing0 = null;
const _errs6 = errors;
if(errors === _errs6){
if(data1 && typeof data1 == "object" && !Array.isArray(data1)){
let missing1;
if((data1.inspection === undefined) && (missing1 = "inspection")){
const err0 = {instancePath:instancePath+"/source",schemaPath:"#/properties/source/oneOf/0/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
}
else {
const _errs8 = errors;
for(const key1 in data1){
if(!(key1 === "inspection")){
const err1 = {instancePath:instancePath+"/source",schemaPath:"#/properties/source/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(_errs8 === errors){
if(data1.inspection !== undefined){
let data2 = data1.inspection;
const _errs9 = errors;
if(errors === _errs9){
if(data2 && typeof data2 == "object" && !Array.isArray(data2)){
let missing2;
if((data2.projection === undefined) && (missing2 = "projection")){
const err2 = {instancePath:instancePath+"/source/inspection",schemaPath:"#/properties/source/oneOf/0/properties/inspection/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
if(vErrors === null){
vErrors = [err2];
}
else {
vErrors.push(err2);
}
errors++;
}
else {
const _errs11 = errors;
for(const key2 in data2){
if(!((key2 === "projection") || (key2 === "page_budget"))){
const err3 = {instancePath:instancePath+"/source/inspection",schemaPath:"#/properties/source/oneOf/0/properties/inspection/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(_errs11 === errors){
if(data2.projection !== undefined){
let data3 = data2.projection;
const _errs12 = errors;
if(typeof data3 !== "string"){
const err4 = {instancePath:instancePath+"/source/inspection/projection",schemaPath:"#/properties/source/oneOf/0/properties/inspection/properties/projection/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
}
if(!((((((data3 === "atlas") || (data3 === "resources")) || (data3 === "processes")) || (data3 === "records")) || (data3 === "capabilities")) || (data3 === "activity"))){
const err5 = {instancePath:instancePath+"/source/inspection/projection",schemaPath:"#/properties/source/oneOf/0/properties/inspection/properties/projection/enum",keyword:"enum",params:{allowedValues: schema35.properties.source.oneOf[0].properties.inspection.properties.projection.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err5];
}
else {
vErrors.push(err5);
}
errors++;
}
var valid3 = _errs12 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data2.page_budget !== undefined){
let data4 = data2.page_budget;
const _errs14 = errors;
if(!(((typeof data4 == "number") && (!(data4 % 1) && !isNaN(data4))) && (isFinite(data4)))){
const err6 = {instancePath:instancePath+"/source/inspection/page_budget",schemaPath:"#/properties/source/oneOf/0/properties/inspection/properties/page_budget/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err6];
}
else {
vErrors.push(err6);
}
errors++;
}
if(errors === _errs14){
if((typeof data4 == "number") && (isFinite(data4))){
if(data4 > 255 || isNaN(data4)){
const err7 = {instancePath:instancePath+"/source/inspection/page_budget",schemaPath:"#/properties/source/oneOf/0/properties/inspection/properties/page_budget/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err7];
}
else {
vErrors.push(err7);
}
errors++;
}
else {
if(data4 < 0 || isNaN(data4)){
const err8 = {instancePath:instancePath+"/source/inspection/page_budget",schemaPath:"#/properties/source/oneOf/0/properties/inspection/properties/page_budget/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid3 = _errs14 === errors;
}
else {
var valid3 = true;
}
}
}
}
}
else {
const err9 = {instancePath:instancePath+"/source/inspection",schemaPath:"#/properties/source/oneOf/0/properties/inspection/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
}
else {
const err10 = {instancePath:instancePath+"/source",schemaPath:"#/properties/source/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
}
}
var _valid0 = _errs6 === errors;
if(_valid0){
valid1 = true;
passing0 = 0;
var props0 = true;
}
const _errs16 = errors;
if(errors === _errs16){
if(data1 && typeof data1 == "object" && !Array.isArray(data1)){
let missing3;
if((data1.query === undefined) && (missing3 = "query")){
const err11 = {instancePath:instancePath+"/source",schemaPath:"#/properties/source/oneOf/1/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
if(vErrors === null){
vErrors = [err11];
}
else {
vErrors.push(err11);
}
errors++;
}
else {
const _errs18 = errors;
for(const key3 in data1){
if(!(key3 === "query")){
const err12 = {instancePath:instancePath+"/source",schemaPath:"#/properties/source/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(_errs18 === errors){
if(data1.query !== undefined){
let data5 = data1.query;
const _errs19 = errors;
if(errors === _errs19){
if(data5 && typeof data5 == "object" && !Array.isArray(data5)){
let missing4;
if(((((((data5.resource === undefined) && (missing4 = "resource")) || ((data5.name === undefined) && (missing4 = "name"))) || ((data5.source_kind === undefined) && (missing4 = "source_kind"))) || ((data5.schema === undefined) && (missing4 = "schema"))) || ((data5.profile === undefined) && (missing4 = "profile"))) || ((data5.sql === undefined) && (missing4 = "sql"))){
const err13 = {instancePath:instancePath+"/source/query",schemaPath:"#/properties/source/oneOf/1/properties/query/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
if(vErrors === null){
vErrors = [err13];
}
else {
vErrors.push(err13);
}
errors++;
}
else {
const _errs21 = errors;
for(const key4 in data5){
if(!((((((((key4 === "resource") || (key4 === "name")) || (key4 === "source_kind")) || (key4 === "schema")) || (key4 === "profile")) || (key4 === "sql")) || (key4 === "refresh")) || (key4 === "starts"))){
const err14 = {instancePath:instancePath+"/source/query",schemaPath:"#/properties/source/oneOf/1/properties/query/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(_errs21 === errors){
if(data5.resource !== undefined){
let data6 = data5.resource;
const _errs22 = errors;
if(!(((typeof data6 == "number") && (!(data6 % 1) && !isNaN(data6))) && (isFinite(data6)))){
const err15 = {instancePath:instancePath+"/source/query/resource",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/resource/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
}
if(errors === _errs22){
if((typeof data6 == "number") && (isFinite(data6))){
if(data6 > 9007199254740991 || isNaN(data6)){
const err16 = {instancePath:instancePath+"/source/query/resource",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/resource/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err16];
}
else {
vErrors.push(err16);
}
errors++;
}
else {
if(data6 < 0 || isNaN(data6)){
const err17 = {instancePath:instancePath+"/source/query/resource",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/resource/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid5 = _errs22 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data5.name !== undefined){
let data7 = data5.name;
const _errs24 = errors;
if(errors === _errs24){
if(typeof data7 === "string"){
if(func2(data7) > 64){
const err18 = {instancePath:instancePath+"/source/query/name",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/name/maxLength",keyword:"maxLength",params:{limit: 64},message:"must NOT have more than 64 characters"};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
}
else {
if(func2(data7) < 1){
const err19 = {instancePath:instancePath+"/source/query/name",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/name/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
}
else {
if(!pattern4.test(data7)){
const err20 = {instancePath:instancePath+"/source/query/name",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/name/pattern",keyword:"pattern",params:{pattern: "^[A-Za-z_][A-Za-z_0-9]*$"},message:"must match pattern \""+"^[A-Za-z_][A-Za-z_0-9]*$"+"\""};
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
else {
const err21 = {instancePath:instancePath+"/source/query/name",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
}
errors++;
}
}
var valid5 = _errs24 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data5.source_kind !== undefined){
let data8 = data5.source_kind;
const _errs26 = errors;
if(typeof data8 !== "string"){
const err22 = {instancePath:instancePath+"/source/query/source_kind",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/source_kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err22];
}
else {
vErrors.push(err22);
}
errors++;
}
if(!(((data8 === "table") || (data8 === "kv")) || (data8 === "document"))){
const err23 = {instancePath:instancePath+"/source/query/source_kind",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/source_kind/enum",keyword:"enum",params:{allowedValues: schema35.properties.source.oneOf[1].properties.query.properties.source_kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err23];
}
else {
vErrors.push(err23);
}
errors++;
}
var valid5 = _errs26 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data5.schema !== undefined){
let data9 = data5.schema;
const _errs28 = errors;
if(errors === _errs28){
if(Array.isArray(data9)){
if(data9.length > 32){
const err24 = {instancePath:instancePath+"/source/query/schema",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/schema/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
}
errors++;
}
else {
if(data9.length < 32){
const err25 = {instancePath:instancePath+"/source/query/schema",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/schema/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err25];
}
else {
vErrors.push(err25);
}
errors++;
}
else {
var valid6 = true;
const len0 = data9.length;
for(let i0=0; i0<len0; i0++){
let data10 = data9[i0];
const _errs30 = errors;
if(!(((typeof data10 == "number") && (!(data10 % 1) && !isNaN(data10))) && (isFinite(data10)))){
const err26 = {instancePath:instancePath+"/source/query/schema/" + i0,schemaPath:"#/properties/source/oneOf/1/properties/query/properties/schema/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err26];
}
else {
vErrors.push(err26);
}
errors++;
}
if(errors === _errs30){
if((typeof data10 == "number") && (isFinite(data10))){
if(data10 > 255 || isNaN(data10)){
const err27 = {instancePath:instancePath+"/source/query/schema/" + i0,schemaPath:"#/properties/source/oneOf/1/properties/query/properties/schema/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err27];
}
else {
vErrors.push(err27);
}
errors++;
}
else {
if(data10 < 0 || isNaN(data10)){
const err28 = {instancePath:instancePath+"/source/query/schema/" + i0,schemaPath:"#/properties/source/oneOf/1/properties/query/properties/schema/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err28];
}
else {
vErrors.push(err28);
}
errors++;
}
}
}
}
var valid6 = _errs30 === errors;
if(!valid6){
break;
}
}
}
}
}
else {
const err29 = {instancePath:instancePath+"/source/query/schema",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/schema/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err29];
}
else {
vErrors.push(err29);
}
errors++;
}
}
var valid5 = _errs28 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data5.profile !== undefined){
let data11 = data5.profile;
const _errs32 = errors;
if(typeof data11 !== "string"){
const err30 = {instancePath:instancePath+"/source/query/profile",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/profile/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
}
errors++;
}
if(!((data11 === "table_v1") || (data11 === "unified_v2"))){
const err31 = {instancePath:instancePath+"/source/query/profile",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/profile/enum",keyword:"enum",params:{allowedValues: schema35.properties.source.oneOf[1].properties.query.properties.profile.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err31];
}
else {
vErrors.push(err31);
}
errors++;
}
var valid5 = _errs32 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data5.sql !== undefined){
let data12 = data5.sql;
const _errs34 = errors;
if(errors === _errs34){
if(typeof data12 === "string"){
if(func2(data12) > 4096){
const err32 = {instancePath:instancePath+"/source/query/sql",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/sql/maxLength",keyword:"maxLength",params:{limit: 4096},message:"must NOT have more than 4096 characters"};
if(vErrors === null){
vErrors = [err32];
}
else {
vErrors.push(err32);
}
errors++;
}
else {
if(func2(data12) < 1){
const err33 = {instancePath:instancePath+"/source/query/sql",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/sql/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"};
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
else {
const err34 = {instancePath:instancePath+"/source/query/sql",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/sql/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err34];
}
else {
vErrors.push(err34);
}
errors++;
}
}
var valid5 = _errs34 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data5.refresh !== undefined){
let data13 = data5.refresh;
const _errs36 = errors;
if(typeof data13 !== "string"){
const err35 = {instancePath:instancePath+"/source/query/refresh",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/refresh/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err35];
}
else {
vErrors.push(err35);
}
errors++;
}
if(!((data13 === "snapshot") || (data13 === "follow"))){
const err36 = {instancePath:instancePath+"/source/query/refresh",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/refresh/enum",keyword:"enum",params:{allowedValues: schema35.properties.source.oneOf[1].properties.query.properties.refresh.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
}
var valid5 = _errs36 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data5.starts !== undefined){
let data14 = data5.starts;
const _errs38 = errors;
if(!(((typeof data14 == "number") && (!(data14 % 1) && !isNaN(data14))) && (isFinite(data14)))){
const err37 = {instancePath:instancePath+"/source/query/starts",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/starts/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err37];
}
else {
vErrors.push(err37);
}
errors++;
}
if(errors === _errs38){
if((typeof data14 == "number") && (isFinite(data14))){
if(data14 > 255 || isNaN(data14)){
const err38 = {instancePath:instancePath+"/source/query/starts",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/starts/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err38];
}
else {
vErrors.push(err38);
}
errors++;
}
else {
if(data14 < 0 || isNaN(data14)){
const err39 = {instancePath:instancePath+"/source/query/starts",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/starts/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid5 = _errs38 === errors;
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
else {
const err40 = {instancePath:instancePath+"/source/query",schemaPath:"#/properties/source/oneOf/1/properties/query/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err40];
}
else {
vErrors.push(err40);
}
errors++;
}
}
}
}
}
}
else {
const err41 = {instancePath:instancePath+"/source",schemaPath:"#/properties/source/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err41];
}
else {
vErrors.push(err41);
}
errors++;
}
}
var _valid0 = _errs16 === errors;
if(_valid0 && valid1){
valid1 = false;
passing0 = [passing0, 1];
}
else {
if(_valid0){
valid1 = true;
passing0 = 1;
if(props0 !== true){
props0 = true;
}
}
const _errs40 = errors;
if(errors === _errs40){
if(data1 && typeof data1 == "object" && !Array.isArray(data1)){
let missing5;
if((data1.command === undefined) && (missing5 = "command")){
const err42 = {instancePath:instancePath+"/source",schemaPath:"#/properties/source/oneOf/2/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
if(vErrors === null){
vErrors = [err42];
}
else {
vErrors.push(err42);
}
errors++;
}
else {
const _errs42 = errors;
for(const key5 in data1){
if(!(key5 === "command")){
const err43 = {instancePath:instancePath+"/source",schemaPath:"#/properties/source/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(_errs42 === errors){
if(data1.command !== undefined){
let data15 = data1.command;
const _errs43 = errors;
if(errors === _errs43){
if(data15 && typeof data15 == "object" && !Array.isArray(data15)){
let missing6;
if(((((data15.service === undefined) && (missing6 = "service")) || ((data15.target === undefined) && (missing6 = "target"))) || ((data15.revision === undefined) && (missing6 = "revision"))) || ((data15.codec === undefined) && (missing6 = "codec"))){
const err44 = {instancePath:instancePath+"/source/command",schemaPath:"#/properties/source/oneOf/2/properties/command/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
if(vErrors === null){
vErrors = [err44];
}
else {
vErrors.push(err44);
}
errors++;
}
else {
const _errs45 = errors;
for(const key6 in data15){
if(!((((key6 === "service") || (key6 === "target")) || (key6 === "revision")) || (key6 === "codec"))){
const err45 = {instancePath:instancePath+"/source/command",schemaPath:"#/properties/source/oneOf/2/properties/command/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
if(_errs45 === errors){
if(data15.service !== undefined){
let data16 = data15.service;
const _errs46 = errors;
if(!(((typeof data16 == "number") && (!(data16 % 1) && !isNaN(data16))) && (isFinite(data16)))){
const err46 = {instancePath:instancePath+"/source/command/service",schemaPath:"#/properties/source/oneOf/2/properties/command/properties/service/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err46];
}
else {
vErrors.push(err46);
}
errors++;
}
if(errors === _errs46){
if((typeof data16 == "number") && (isFinite(data16))){
if(data16 > 9007199254740991 || isNaN(data16)){
const err47 = {instancePath:instancePath+"/source/command/service",schemaPath:"#/properties/source/oneOf/2/properties/command/properties/service/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
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
const err48 = {instancePath:instancePath+"/source/command/service",schemaPath:"#/properties/source/oneOf/2/properties/command/properties/service/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid8 = _errs46 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data15.target !== undefined){
let data17 = data15.target;
const _errs48 = errors;
if(!(((typeof data17 == "number") && (!(data17 % 1) && !isNaN(data17))) && (isFinite(data17)))){
const err49 = {instancePath:instancePath+"/source/command/target",schemaPath:"#/properties/source/oneOf/2/properties/command/properties/target/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err49];
}
else {
vErrors.push(err49);
}
errors++;
}
if(errors === _errs48){
if((typeof data17 == "number") && (isFinite(data17))){
if(data17 > 9007199254740991 || isNaN(data17)){
const err50 = {instancePath:instancePath+"/source/command/target",schemaPath:"#/properties/source/oneOf/2/properties/command/properties/target/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
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
const err51 = {instancePath:instancePath+"/source/command/target",schemaPath:"#/properties/source/oneOf/2/properties/command/properties/target/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid8 = _errs48 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data15.revision !== undefined){
let data18 = data15.revision;
const _errs50 = errors;
if(!(((typeof data18 == "number") && (!(data18 % 1) && !isNaN(data18))) && (isFinite(data18)))){
const err52 = {instancePath:instancePath+"/source/command/revision",schemaPath:"#/properties/source/oneOf/2/properties/command/properties/revision/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err52];
}
else {
vErrors.push(err52);
}
errors++;
}
if(errors === _errs50){
if((typeof data18 == "number") && (isFinite(data18))){
if(data18 > 9007199254740991 || isNaN(data18)){
const err53 = {instancePath:instancePath+"/source/command/revision",schemaPath:"#/properties/source/oneOf/2/properties/command/properties/revision/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
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
const err54 = {instancePath:instancePath+"/source/command/revision",schemaPath:"#/properties/source/oneOf/2/properties/command/properties/revision/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid8 = _errs50 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data15.codec !== undefined){
let data19 = data15.codec;
const _errs52 = errors;
if(!(((typeof data19 == "number") && (!(data19 % 1) && !isNaN(data19))) && (isFinite(data19)))){
const err55 = {instancePath:instancePath+"/source/command/codec",schemaPath:"#/properties/source/oneOf/2/properties/command/properties/codec/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err55];
}
else {
vErrors.push(err55);
}
errors++;
}
if(errors === _errs52){
if((typeof data19 == "number") && (isFinite(data19))){
if(data19 > 65535 || isNaN(data19)){
const err56 = {instancePath:instancePath+"/source/command/codec",schemaPath:"#/properties/source/oneOf/2/properties/command/properties/codec/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
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
const err57 = {instancePath:instancePath+"/source/command/codec",schemaPath:"#/properties/source/oneOf/2/properties/command/properties/codec/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid8 = _errs52 === errors;
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
const err58 = {instancePath:instancePath+"/source/command",schemaPath:"#/properties/source/oneOf/2/properties/command/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
else {
const err59 = {instancePath:instancePath+"/source",schemaPath:"#/properties/source/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err59];
}
else {
vErrors.push(err59);
}
errors++;
}
}
var _valid0 = _errs40 === errors;
if(_valid0 && valid1){
valid1 = false;
passing0 = [passing0, 2];
}
else {
if(_valid0){
valid1 = true;
passing0 = 2;
if(props0 !== true){
props0 = true;
}
}
}
}
if(!valid1){
const err60 = {instancePath:instancePath+"/source",schemaPath:"#/properties/source/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err60];
}
else {
vErrors.push(err60);
}
errors++;
validate26.errors = vErrors;
return false;
}
else {
errors = _errs5;
if(vErrors !== null){
if(_errs5){
vErrors.length = _errs5;
}
else {
vErrors = null;
}
}
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
validate26.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate26.errors = vErrors;
return errors === 0;
}
validate26.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Action = validate27;

function validate27(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate27.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.name === undefined) && (missing0 = "name")) || ((data.label === undefined) && (missing0 = "label"))) || ((data.target === undefined) && (missing0 = "target"))){
validate27.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "name") || (key0 === "label")) || (key0 === "target"))){
validate27.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
if(func2(data0) > 64){
validate27.errors = [{instancePath:instancePath+"/name",schemaPath:"#/properties/name/maxLength",keyword:"maxLength",params:{limit: 64},message:"must NOT have more than 64 characters"}];
return false;
}
else {
if(func2(data0) < 1){
validate27.errors = [{instancePath:instancePath+"/name",schemaPath:"#/properties/name/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"}];
return false;
}
else {
if(!pattern4.test(data0)){
validate27.errors = [{instancePath:instancePath+"/name",schemaPath:"#/properties/name/pattern",keyword:"pattern",params:{pattern: "^[A-Za-z_][A-Za-z_0-9]*$"},message:"must match pattern \""+"^[A-Za-z_][A-Za-z_0-9]*$"+"\""}];
return false;
}
}
}
}
else {
validate27.errors = [{instancePath:instancePath+"/name",schemaPath:"#/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.label !== undefined){
let data1 = data.label;
const _errs4 = errors;
if(errors === _errs4){
if(typeof data1 === "string"){
if(func2(data1) > 128){
validate27.errors = [{instancePath:instancePath+"/label",schemaPath:"#/properties/label/maxLength",keyword:"maxLength",params:{limit: 128},message:"must NOT have more than 128 characters"}];
return false;
}
else {
if(func2(data1) < 1){
validate27.errors = [{instancePath:instancePath+"/label",schemaPath:"#/properties/label/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"}];
return false;
}
}
}
else {
validate27.errors = [{instancePath:instancePath+"/label",schemaPath:"#/properties/label/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.target !== undefined){
let data2 = data.target;
const _errs6 = errors;
const _errs7 = errors;
let valid1 = false;
let passing0 = null;
const _errs8 = errors;
if(errors === _errs8){
if(data2 && typeof data2 == "object" && !Array.isArray(data2)){
let missing1;
if((data2.navigate === undefined) && (missing1 = "navigate")){
const err0 = {instancePath:instancePath+"/target",schemaPath:"#/properties/target/oneOf/0/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
}
else {
const _errs10 = errors;
for(const key1 in data2){
if(!(key1 === "navigate")){
const err1 = {instancePath:instancePath+"/target",schemaPath:"#/properties/target/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(_errs10 === errors){
if(data2.navigate !== undefined){
let data3 = data2.navigate;
const _errs11 = errors;
if(errors === _errs11){
if(typeof data3 === "string"){
if(func2(data3) > 256){
const err2 = {instancePath:instancePath+"/target/navigate",schemaPath:"#/properties/target/oneOf/0/properties/navigate/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
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
const err3 = {instancePath:instancePath+"/target/navigate",schemaPath:"#/properties/target/oneOf/0/properties/navigate/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
const err4 = {instancePath:instancePath+"/target",schemaPath:"#/properties/target/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
}
}
var _valid0 = _errs8 === errors;
if(_valid0){
valid1 = true;
passing0 = 0;
var props0 = true;
}
const _errs13 = errors;
if(errors === _errs13){
if(data2 && typeof data2 == "object" && !Array.isArray(data2)){
let missing2;
if((data2.command === undefined) && (missing2 = "command")){
const err5 = {instancePath:instancePath+"/target",schemaPath:"#/properties/target/oneOf/1/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
if(vErrors === null){
vErrors = [err5];
}
else {
vErrors.push(err5);
}
errors++;
}
else {
const _errs15 = errors;
for(const key2 in data2){
if(!(key2 === "command")){
const err6 = {instancePath:instancePath+"/target",schemaPath:"#/properties/target/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(_errs15 === errors){
if(data2.command !== undefined){
let data4 = data2.command;
const _errs16 = errors;
if(errors === _errs16){
if(typeof data4 === "string"){
if(func2(data4) > 256){
const err7 = {instancePath:instancePath+"/target/command",schemaPath:"#/properties/target/oneOf/1/properties/command/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
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
const err8 = {instancePath:instancePath+"/target/command",schemaPath:"#/properties/target/oneOf/1/properties/command/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
const err9 = {instancePath:instancePath+"/target",schemaPath:"#/properties/target/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
}
}
var _valid0 = _errs13 === errors;
if(_valid0 && valid1){
valid1 = false;
passing0 = [passing0, 1];
}
else {
if(_valid0){
valid1 = true;
passing0 = 1;
if(props0 !== true){
props0 = true;
}
}
const _errs18 = errors;
if(errors === _errs18){
if(data2 && typeof data2 == "object" && !Array.isArray(data2)){
let missing3;
if((data2.follow === undefined) && (missing3 = "follow")){
const err10 = {instancePath:instancePath+"/target",schemaPath:"#/properties/target/oneOf/2/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
}
else {
const _errs20 = errors;
for(const key3 in data2){
if(!(key3 === "follow")){
const err11 = {instancePath:instancePath+"/target",schemaPath:"#/properties/target/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(_errs20 === errors){
if(data2.follow !== undefined){
let data5 = data2.follow;
const _errs21 = errors;
if(errors === _errs21){
if(typeof data5 === "string"){
if(func2(data5) > 256){
const err12 = {instancePath:instancePath+"/target/follow",schemaPath:"#/properties/target/oneOf/2/properties/follow/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
}
}
else {
const err13 = {instancePath:instancePath+"/target/follow",schemaPath:"#/properties/target/oneOf/2/properties/follow/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err13];
}
else {
vErrors.push(err13);
}
errors++;
}
}
}
}
}
}
else {
const err14 = {instancePath:instancePath+"/target",schemaPath:"#/properties/target/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err14];
}
else {
vErrors.push(err14);
}
errors++;
}
}
var _valid0 = _errs18 === errors;
if(_valid0 && valid1){
valid1 = false;
passing0 = [passing0, 2];
}
else {
if(_valid0){
valid1 = true;
passing0 = 2;
if(props0 !== true){
props0 = true;
}
}
}
}
if(!valid1){
const err15 = {instancePath:instancePath+"/target",schemaPath:"#/properties/target/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
validate27.errors = vErrors;
return false;
}
else {
errors = _errs7;
if(vErrors !== null){
if(_errs7){
vErrors.length = _errs7;
}
else {
vErrors = null;
}
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
validate27.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate27.errors = vErrors;
return errors === 0;
}
validate27.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Configuration = validate28;
const schema46 = {"type":"object","additionalProperties":false,"properties":{"application":{"type":"integer","minimum":0,"maximum":9007199254740991},"namespace":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"realm":{"type":"integer","minimum":0,"maximum":9007199254740991},"administrator":{"type":"integer","minimum":0,"maximum":9007199254740991},"name_digest":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}}},"required":["application","namespace","realm","administrator","name_digest"]};

function validate28(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate28.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.application === undefined) && (missing0 = "application")) || ((data.namespace === undefined) && (missing0 = "namespace"))) || ((data.realm === undefined) && (missing0 = "realm"))) || ((data.administrator === undefined) && (missing0 = "administrator"))) || ((data.name_digest === undefined) && (missing0 = "name_digest"))){
validate28.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "application") || (key0 === "namespace")) || (key0 === "realm")) || (key0 === "administrator")) || (key0 === "name_digest"))){
validate28.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.application !== undefined){
let data0 = data.application;
const _errs2 = errors;
if(!(((typeof data0 == "number") && (!(data0 % 1) && !isNaN(data0))) && (isFinite(data0)))){
validate28.errors = [{instancePath:instancePath+"/application",schemaPath:"#/properties/application/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs2){
if((typeof data0 == "number") && (isFinite(data0))){
if(data0 > 9007199254740991 || isNaN(data0)){
validate28.errors = [{instancePath:instancePath+"/application",schemaPath:"#/properties/application/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data0 < 0 || isNaN(data0)){
validate28.errors = [{instancePath:instancePath+"/application",schemaPath:"#/properties/application/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.namespace !== undefined){
let data1 = data.namespace;
const _errs4 = errors;
if(errors === _errs4){
if(typeof data1 === "string"){
if(func2(data1) > 20){
validate28.errors = [{instancePath:instancePath+"/namespace",schemaPath:"#/properties/namespace/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern5.test(data1)){
validate28.errors = [{instancePath:instancePath+"/namespace",schemaPath:"#/properties/namespace/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate28.errors = [{instancePath:instancePath+"/namespace",schemaPath:"#/properties/namespace/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.realm !== undefined){
let data2 = data.realm;
const _errs6 = errors;
if(!(((typeof data2 == "number") && (!(data2 % 1) && !isNaN(data2))) && (isFinite(data2)))){
validate28.errors = [{instancePath:instancePath+"/realm",schemaPath:"#/properties/realm/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs6){
if((typeof data2 == "number") && (isFinite(data2))){
if(data2 > 9007199254740991 || isNaN(data2)){
validate28.errors = [{instancePath:instancePath+"/realm",schemaPath:"#/properties/realm/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data2 < 0 || isNaN(data2)){
validate28.errors = [{instancePath:instancePath+"/realm",schemaPath:"#/properties/realm/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
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
if(data.administrator !== undefined){
let data3 = data.administrator;
const _errs8 = errors;
if(!(((typeof data3 == "number") && (!(data3 % 1) && !isNaN(data3))) && (isFinite(data3)))){
validate28.errors = [{instancePath:instancePath+"/administrator",schemaPath:"#/properties/administrator/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs8){
if((typeof data3 == "number") && (isFinite(data3))){
if(data3 > 9007199254740991 || isNaN(data3)){
validate28.errors = [{instancePath:instancePath+"/administrator",schemaPath:"#/properties/administrator/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data3 < 0 || isNaN(data3)){
validate28.errors = [{instancePath:instancePath+"/administrator",schemaPath:"#/properties/administrator/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.name_digest !== undefined){
let data4 = data.name_digest;
const _errs10 = errors;
if(errors === _errs10){
if(Array.isArray(data4)){
if(data4.length > 32){
validate28.errors = [{instancePath:instancePath+"/name_digest",schemaPath:"#/properties/name_digest/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"}];
return false;
}
else {
if(data4.length < 32){
validate28.errors = [{instancePath:instancePath+"/name_digest",schemaPath:"#/properties/name_digest/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"}];
return false;
}
else {
var valid1 = true;
const len0 = data4.length;
for(let i0=0; i0<len0; i0++){
let data5 = data4[i0];
const _errs12 = errors;
if(!(((typeof data5 == "number") && (!(data5 % 1) && !isNaN(data5))) && (isFinite(data5)))){
validate28.errors = [{instancePath:instancePath+"/name_digest/" + i0,schemaPath:"#/properties/name_digest/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs12){
if((typeof data5 == "number") && (isFinite(data5))){
if(data5 > 255 || isNaN(data5)){
validate28.errors = [{instancePath:instancePath+"/name_digest/" + i0,schemaPath:"#/properties/name_digest/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"}];
return false;
}
else {
if(data5 < 0 || isNaN(data5)){
validate28.errors = [{instancePath:instancePath+"/name_digest/" + i0,schemaPath:"#/properties/name_digest/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
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
validate28.errors = [{instancePath:instancePath+"/name_digest",schemaPath:"#/properties/name_digest/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
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
else {
validate28.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate28.errors = vErrors;
return errors === 0;
}
validate28.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Policy = validate29;
const schema47 = {"type":"object","additionalProperties":false,"properties":{"revision":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"publish":{"type":"boolean"}},"required":["revision","publish"]};

function validate29(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate29.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.revision === undefined) && (missing0 = "revision")) || ((data.publish === undefined) && (missing0 = "publish"))){
validate29.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "revision") || (key0 === "publish"))){
validate29.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.revision !== undefined){
let data0 = data.revision;
const _errs2 = errors;
if(errors === _errs2){
if(typeof data0 === "string"){
if(func2(data0) > 20){
validate29.errors = [{instancePath:instancePath+"/revision",schemaPath:"#/properties/revision/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern5.test(data0)){
validate29.errors = [{instancePath:instancePath+"/revision",schemaPath:"#/properties/revision/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate29.errors = [{instancePath:instancePath+"/revision",schemaPath:"#/properties/revision/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.publish !== undefined){
const _errs4 = errors;
if(typeof data.publish !== "boolean"){
validate29.errors = [{instancePath:instancePath+"/publish",schemaPath:"#/properties/publish/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
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
validate29.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate29.errors = vErrors;
return errors === 0;
}
validate29.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Proposal = validate30;
const schema48 = {"type":"object","additionalProperties":false,"properties":{"operation":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"record":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"expected":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"expected_digest":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"revision":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"spec":{"type":"object","additionalProperties":false,"properties":{"format":{"type":"integer","minimum":0,"maximum":4294967295},"length":{"type":"integer","minimum":0,"maximum":4294967295},"digest":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}}},"required":["format","length","digest"]}},"required":["operation","record","expected","expected_digest","revision","spec"]};

function validate30(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate30.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((data.operation === undefined) && (missing0 = "operation")) || ((data.record === undefined) && (missing0 = "record"))) || ((data.expected === undefined) && (missing0 = "expected"))) || ((data.expected_digest === undefined) && (missing0 = "expected_digest"))) || ((data.revision === undefined) && (missing0 = "revision"))) || ((data.spec === undefined) && (missing0 = "spec"))){
validate30.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "operation") || (key0 === "record")) || (key0 === "expected")) || (key0 === "expected_digest")) || (key0 === "revision")) || (key0 === "spec"))){
validate30.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.operation !== undefined){
let data0 = data.operation;
const _errs2 = errors;
if(errors === _errs2){
if(typeof data0 === "string"){
if(func2(data0) > 20){
validate30.errors = [{instancePath:instancePath+"/operation",schemaPath:"#/properties/operation/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern5.test(data0)){
validate30.errors = [{instancePath:instancePath+"/operation",schemaPath:"#/properties/operation/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate30.errors = [{instancePath:instancePath+"/operation",schemaPath:"#/properties/operation/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.record !== undefined){
let data1 = data.record;
const _errs4 = errors;
if(errors === _errs4){
if(typeof data1 === "string"){
if(func2(data1) > 20){
validate30.errors = [{instancePath:instancePath+"/record",schemaPath:"#/properties/record/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern5.test(data1)){
validate30.errors = [{instancePath:instancePath+"/record",schemaPath:"#/properties/record/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate30.errors = [{instancePath:instancePath+"/record",schemaPath:"#/properties/record/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.expected !== undefined){
let data2 = data.expected;
const _errs6 = errors;
if(errors === _errs6){
if(typeof data2 === "string"){
if(func2(data2) > 20){
validate30.errors = [{instancePath:instancePath+"/expected",schemaPath:"#/properties/expected/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern5.test(data2)){
validate30.errors = [{instancePath:instancePath+"/expected",schemaPath:"#/properties/expected/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate30.errors = [{instancePath:instancePath+"/expected",schemaPath:"#/properties/expected/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.expected_digest !== undefined){
let data3 = data.expected_digest;
const _errs8 = errors;
if(errors === _errs8){
if(Array.isArray(data3)){
if(data3.length > 32){
validate30.errors = [{instancePath:instancePath+"/expected_digest",schemaPath:"#/properties/expected_digest/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"}];
return false;
}
else {
if(data3.length < 32){
validate30.errors = [{instancePath:instancePath+"/expected_digest",schemaPath:"#/properties/expected_digest/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"}];
return false;
}
else {
var valid1 = true;
const len0 = data3.length;
for(let i0=0; i0<len0; i0++){
let data4 = data3[i0];
const _errs10 = errors;
if(!(((typeof data4 == "number") && (!(data4 % 1) && !isNaN(data4))) && (isFinite(data4)))){
validate30.errors = [{instancePath:instancePath+"/expected_digest/" + i0,schemaPath:"#/properties/expected_digest/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs10){
if((typeof data4 == "number") && (isFinite(data4))){
if(data4 > 255 || isNaN(data4)){
validate30.errors = [{instancePath:instancePath+"/expected_digest/" + i0,schemaPath:"#/properties/expected_digest/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"}];
return false;
}
else {
if(data4 < 0 || isNaN(data4)){
validate30.errors = [{instancePath:instancePath+"/expected_digest/" + i0,schemaPath:"#/properties/expected_digest/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid1 = _errs10 === errors;
if(!valid1){
break;
}
}
}
}
}
else {
validate30.errors = [{instancePath:instancePath+"/expected_digest",schemaPath:"#/properties/expected_digest/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.revision !== undefined){
let data5 = data.revision;
const _errs12 = errors;
if(errors === _errs12){
if(typeof data5 === "string"){
if(func2(data5) > 20){
validate30.errors = [{instancePath:instancePath+"/revision",schemaPath:"#/properties/revision/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern5.test(data5)){
validate30.errors = [{instancePath:instancePath+"/revision",schemaPath:"#/properties/revision/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate30.errors = [{instancePath:instancePath+"/revision",schemaPath:"#/properties/revision/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs12 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.spec !== undefined){
let data6 = data.spec;
const _errs14 = errors;
if(errors === _errs14){
if(data6 && typeof data6 == "object" && !Array.isArray(data6)){
let missing1;
if((((data6.format === undefined) && (missing1 = "format")) || ((data6.length === undefined) && (missing1 = "length"))) || ((data6.digest === undefined) && (missing1 = "digest"))){
validate30.errors = [{instancePath:instancePath+"/spec",schemaPath:"#/properties/spec/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"}];
return false;
}
else {
const _errs16 = errors;
for(const key1 in data6){
if(!(((key1 === "format") || (key1 === "length")) || (key1 === "digest"))){
validate30.errors = [{instancePath:instancePath+"/spec",schemaPath:"#/properties/spec/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs16 === errors){
if(data6.format !== undefined){
let data7 = data6.format;
const _errs17 = errors;
if(!(((typeof data7 == "number") && (!(data7 % 1) && !isNaN(data7))) && (isFinite(data7)))){
validate30.errors = [{instancePath:instancePath+"/spec/format",schemaPath:"#/properties/spec/properties/format/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs17){
if((typeof data7 == "number") && (isFinite(data7))){
if(data7 > 4294967295 || isNaN(data7)){
validate30.errors = [{instancePath:instancePath+"/spec/format",schemaPath:"#/properties/spec/properties/format/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
return false;
}
else {
if(data7 < 0 || isNaN(data7)){
validate30.errors = [{instancePath:instancePath+"/spec/format",schemaPath:"#/properties/spec/properties/format/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid2 = _errs17 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data6.length !== undefined){
let data8 = data6.length;
const _errs19 = errors;
if(!(((typeof data8 == "number") && (!(data8 % 1) && !isNaN(data8))) && (isFinite(data8)))){
validate30.errors = [{instancePath:instancePath+"/spec/length",schemaPath:"#/properties/spec/properties/length/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs19){
if((typeof data8 == "number") && (isFinite(data8))){
if(data8 > 4294967295 || isNaN(data8)){
validate30.errors = [{instancePath:instancePath+"/spec/length",schemaPath:"#/properties/spec/properties/length/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
return false;
}
else {
if(data8 < 0 || isNaN(data8)){
validate30.errors = [{instancePath:instancePath+"/spec/length",schemaPath:"#/properties/spec/properties/length/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid2 = _errs19 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data6.digest !== undefined){
let data9 = data6.digest;
const _errs21 = errors;
if(errors === _errs21){
if(Array.isArray(data9)){
if(data9.length > 32){
validate30.errors = [{instancePath:instancePath+"/spec/digest",schemaPath:"#/properties/spec/properties/digest/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"}];
return false;
}
else {
if(data9.length < 32){
validate30.errors = [{instancePath:instancePath+"/spec/digest",schemaPath:"#/properties/spec/properties/digest/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"}];
return false;
}
else {
var valid3 = true;
const len1 = data9.length;
for(let i1=0; i1<len1; i1++){
let data10 = data9[i1];
const _errs23 = errors;
if(!(((typeof data10 == "number") && (!(data10 % 1) && !isNaN(data10))) && (isFinite(data10)))){
validate30.errors = [{instancePath:instancePath+"/spec/digest/" + i1,schemaPath:"#/properties/spec/properties/digest/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs23){
if((typeof data10 == "number") && (isFinite(data10))){
if(data10 > 255 || isNaN(data10)){
validate30.errors = [{instancePath:instancePath+"/spec/digest/" + i1,schemaPath:"#/properties/spec/properties/digest/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"}];
return false;
}
else {
if(data10 < 0 || isNaN(data10)){
validate30.errors = [{instancePath:instancePath+"/spec/digest/" + i1,schemaPath:"#/properties/spec/properties/digest/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid3 = _errs23 === errors;
if(!valid3){
break;
}
}
}
}
}
else {
validate30.errors = [{instancePath:instancePath+"/spec/digest",schemaPath:"#/properties/spec/properties/digest/type",keyword:"type",params:{type: "array"},message:"must be array"}];
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
validate30.errors = [{instancePath:instancePath+"/spec",schemaPath:"#/properties/spec/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
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
else {
validate30.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate30.errors = vErrors;
return errors === 0;
}
validate30.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Receipt = validate31;
const schema49 = {"type":"object","additionalProperties":false,"properties":{"proposal":{"type":"object","additionalProperties":false,"properties":{"operation":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"record":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"expected":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"expected_digest":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"revision":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"spec":{"type":"object","additionalProperties":false,"properties":{"format":{"type":"integer","minimum":0,"maximum":4294967295},"length":{"type":"integer","minimum":0,"maximum":4294967295},"digest":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}}},"required":["format","length","digest"]}},"required":["operation","record","expected","expected_digest","revision","spec"]},"phase":{"type":"string","enum":["staging","applied","conflict","abandoned"]},"input":{"type":"integer","minimum":0,"maximum":9007199254740991},"owns_record":{"type":"boolean"}},"required":["proposal","phase","input","owns_record"]};

function validate31(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate31.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.proposal === undefined) && (missing0 = "proposal")) || ((data.phase === undefined) && (missing0 = "phase"))) || ((data.input === undefined) && (missing0 = "input"))) || ((data.owns_record === undefined) && (missing0 = "owns_record"))){
validate31.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "proposal") || (key0 === "phase")) || (key0 === "input")) || (key0 === "owns_record"))){
validate31.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.proposal !== undefined){
let data0 = data.proposal;
const _errs2 = errors;
if(errors === _errs2){
if(data0 && typeof data0 == "object" && !Array.isArray(data0)){
let missing1;
if(((((((data0.operation === undefined) && (missing1 = "operation")) || ((data0.record === undefined) && (missing1 = "record"))) || ((data0.expected === undefined) && (missing1 = "expected"))) || ((data0.expected_digest === undefined) && (missing1 = "expected_digest"))) || ((data0.revision === undefined) && (missing1 = "revision"))) || ((data0.spec === undefined) && (missing1 = "spec"))){
validate31.errors = [{instancePath:instancePath+"/proposal",schemaPath:"#/properties/proposal/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"}];
return false;
}
else {
const _errs4 = errors;
for(const key1 in data0){
if(!((((((key1 === "operation") || (key1 === "record")) || (key1 === "expected")) || (key1 === "expected_digest")) || (key1 === "revision")) || (key1 === "spec"))){
validate31.errors = [{instancePath:instancePath+"/proposal",schemaPath:"#/properties/proposal/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs4 === errors){
if(data0.operation !== undefined){
let data1 = data0.operation;
const _errs5 = errors;
if(errors === _errs5){
if(typeof data1 === "string"){
if(func2(data1) > 20){
validate31.errors = [{instancePath:instancePath+"/proposal/operation",schemaPath:"#/properties/proposal/properties/operation/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern5.test(data1)){
validate31.errors = [{instancePath:instancePath+"/proposal/operation",schemaPath:"#/properties/proposal/properties/operation/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate31.errors = [{instancePath:instancePath+"/proposal/operation",schemaPath:"#/properties/proposal/properties/operation/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid1 = _errs5 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.record !== undefined){
let data2 = data0.record;
const _errs7 = errors;
if(errors === _errs7){
if(typeof data2 === "string"){
if(func2(data2) > 20){
validate31.errors = [{instancePath:instancePath+"/proposal/record",schemaPath:"#/properties/proposal/properties/record/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern5.test(data2)){
validate31.errors = [{instancePath:instancePath+"/proposal/record",schemaPath:"#/properties/proposal/properties/record/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate31.errors = [{instancePath:instancePath+"/proposal/record",schemaPath:"#/properties/proposal/properties/record/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid1 = _errs7 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.expected !== undefined){
let data3 = data0.expected;
const _errs9 = errors;
if(errors === _errs9){
if(typeof data3 === "string"){
if(func2(data3) > 20){
validate31.errors = [{instancePath:instancePath+"/proposal/expected",schemaPath:"#/properties/proposal/properties/expected/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern5.test(data3)){
validate31.errors = [{instancePath:instancePath+"/proposal/expected",schemaPath:"#/properties/proposal/properties/expected/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate31.errors = [{instancePath:instancePath+"/proposal/expected",schemaPath:"#/properties/proposal/properties/expected/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid1 = _errs9 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.expected_digest !== undefined){
let data4 = data0.expected_digest;
const _errs11 = errors;
if(errors === _errs11){
if(Array.isArray(data4)){
if(data4.length > 32){
validate31.errors = [{instancePath:instancePath+"/proposal/expected_digest",schemaPath:"#/properties/proposal/properties/expected_digest/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"}];
return false;
}
else {
if(data4.length < 32){
validate31.errors = [{instancePath:instancePath+"/proposal/expected_digest",schemaPath:"#/properties/proposal/properties/expected_digest/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"}];
return false;
}
else {
var valid2 = true;
const len0 = data4.length;
for(let i0=0; i0<len0; i0++){
let data5 = data4[i0];
const _errs13 = errors;
if(!(((typeof data5 == "number") && (!(data5 % 1) && !isNaN(data5))) && (isFinite(data5)))){
validate31.errors = [{instancePath:instancePath+"/proposal/expected_digest/" + i0,schemaPath:"#/properties/proposal/properties/expected_digest/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs13){
if((typeof data5 == "number") && (isFinite(data5))){
if(data5 > 255 || isNaN(data5)){
validate31.errors = [{instancePath:instancePath+"/proposal/expected_digest/" + i0,schemaPath:"#/properties/proposal/properties/expected_digest/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"}];
return false;
}
else {
if(data5 < 0 || isNaN(data5)){
validate31.errors = [{instancePath:instancePath+"/proposal/expected_digest/" + i0,schemaPath:"#/properties/proposal/properties/expected_digest/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid2 = _errs13 === errors;
if(!valid2){
break;
}
}
}
}
}
else {
validate31.errors = [{instancePath:instancePath+"/proposal/expected_digest",schemaPath:"#/properties/proposal/properties/expected_digest/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid1 = _errs11 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.revision !== undefined){
let data6 = data0.revision;
const _errs15 = errors;
if(errors === _errs15){
if(typeof data6 === "string"){
if(func2(data6) > 20){
validate31.errors = [{instancePath:instancePath+"/proposal/revision",schemaPath:"#/properties/proposal/properties/revision/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern5.test(data6)){
validate31.errors = [{instancePath:instancePath+"/proposal/revision",schemaPath:"#/properties/proposal/properties/revision/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate31.errors = [{instancePath:instancePath+"/proposal/revision",schemaPath:"#/properties/proposal/properties/revision/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid1 = _errs15 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.spec !== undefined){
let data7 = data0.spec;
const _errs17 = errors;
if(errors === _errs17){
if(data7 && typeof data7 == "object" && !Array.isArray(data7)){
let missing2;
if((((data7.format === undefined) && (missing2 = "format")) || ((data7.length === undefined) && (missing2 = "length"))) || ((data7.digest === undefined) && (missing2 = "digest"))){
validate31.errors = [{instancePath:instancePath+"/proposal/spec",schemaPath:"#/properties/proposal/properties/spec/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"}];
return false;
}
else {
const _errs19 = errors;
for(const key2 in data7){
if(!(((key2 === "format") || (key2 === "length")) || (key2 === "digest"))){
validate31.errors = [{instancePath:instancePath+"/proposal/spec",schemaPath:"#/properties/proposal/properties/spec/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs19 === errors){
if(data7.format !== undefined){
let data8 = data7.format;
const _errs20 = errors;
if(!(((typeof data8 == "number") && (!(data8 % 1) && !isNaN(data8))) && (isFinite(data8)))){
validate31.errors = [{instancePath:instancePath+"/proposal/spec/format",schemaPath:"#/properties/proposal/properties/spec/properties/format/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs20){
if((typeof data8 == "number") && (isFinite(data8))){
if(data8 > 4294967295 || isNaN(data8)){
validate31.errors = [{instancePath:instancePath+"/proposal/spec/format",schemaPath:"#/properties/proposal/properties/spec/properties/format/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
return false;
}
else {
if(data8 < 0 || isNaN(data8)){
validate31.errors = [{instancePath:instancePath+"/proposal/spec/format",schemaPath:"#/properties/proposal/properties/spec/properties/format/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid3 = _errs20 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data7.length !== undefined){
let data9 = data7.length;
const _errs22 = errors;
if(!(((typeof data9 == "number") && (!(data9 % 1) && !isNaN(data9))) && (isFinite(data9)))){
validate31.errors = [{instancePath:instancePath+"/proposal/spec/length",schemaPath:"#/properties/proposal/properties/spec/properties/length/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs22){
if((typeof data9 == "number") && (isFinite(data9))){
if(data9 > 4294967295 || isNaN(data9)){
validate31.errors = [{instancePath:instancePath+"/proposal/spec/length",schemaPath:"#/properties/proposal/properties/spec/properties/length/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
return false;
}
else {
if(data9 < 0 || isNaN(data9)){
validate31.errors = [{instancePath:instancePath+"/proposal/spec/length",schemaPath:"#/properties/proposal/properties/spec/properties/length/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid3 = _errs22 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data7.digest !== undefined){
let data10 = data7.digest;
const _errs24 = errors;
if(errors === _errs24){
if(Array.isArray(data10)){
if(data10.length > 32){
validate31.errors = [{instancePath:instancePath+"/proposal/spec/digest",schemaPath:"#/properties/proposal/properties/spec/properties/digest/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"}];
return false;
}
else {
if(data10.length < 32){
validate31.errors = [{instancePath:instancePath+"/proposal/spec/digest",schemaPath:"#/properties/proposal/properties/spec/properties/digest/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"}];
return false;
}
else {
var valid4 = true;
const len1 = data10.length;
for(let i1=0; i1<len1; i1++){
let data11 = data10[i1];
const _errs26 = errors;
if(!(((typeof data11 == "number") && (!(data11 % 1) && !isNaN(data11))) && (isFinite(data11)))){
validate31.errors = [{instancePath:instancePath+"/proposal/spec/digest/" + i1,schemaPath:"#/properties/proposal/properties/spec/properties/digest/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs26){
if((typeof data11 == "number") && (isFinite(data11))){
if(data11 > 255 || isNaN(data11)){
validate31.errors = [{instancePath:instancePath+"/proposal/spec/digest/" + i1,schemaPath:"#/properties/proposal/properties/spec/properties/digest/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"}];
return false;
}
else {
if(data11 < 0 || isNaN(data11)){
validate31.errors = [{instancePath:instancePath+"/proposal/spec/digest/" + i1,schemaPath:"#/properties/proposal/properties/spec/properties/digest/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid4 = _errs26 === errors;
if(!valid4){
break;
}
}
}
}
}
else {
validate31.errors = [{instancePath:instancePath+"/proposal/spec/digest",schemaPath:"#/properties/proposal/properties/spec/properties/digest/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid3 = _errs24 === errors;
}
else {
var valid3 = true;
}
}
}
}
}
}
else {
validate31.errors = [{instancePath:instancePath+"/proposal/spec",schemaPath:"#/properties/proposal/properties/spec/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
var valid1 = _errs17 === errors;
}
else {
var valid1 = true;
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
validate31.errors = [{instancePath:instancePath+"/proposal",schemaPath:"#/properties/proposal/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.phase !== undefined){
let data12 = data.phase;
const _errs28 = errors;
if(typeof data12 !== "string"){
validate31.errors = [{instancePath:instancePath+"/phase",schemaPath:"#/properties/phase/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((data12 === "staging") || (data12 === "applied")) || (data12 === "conflict")) || (data12 === "abandoned"))){
validate31.errors = [{instancePath:instancePath+"/phase",schemaPath:"#/properties/phase/enum",keyword:"enum",params:{allowedValues: schema49.properties.phase.enum},message:"must be equal to one of the allowed values"}];
return false;
}
var valid0 = _errs28 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.input !== undefined){
let data13 = data.input;
const _errs30 = errors;
if(!(((typeof data13 == "number") && (!(data13 % 1) && !isNaN(data13))) && (isFinite(data13)))){
validate31.errors = [{instancePath:instancePath+"/input",schemaPath:"#/properties/input/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs30){
if((typeof data13 == "number") && (isFinite(data13))){
if(data13 > 9007199254740991 || isNaN(data13)){
validate31.errors = [{instancePath:instancePath+"/input",schemaPath:"#/properties/input/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data13 < 0 || isNaN(data13)){
validate31.errors = [{instancePath:instancePath+"/input",schemaPath:"#/properties/input/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid0 = _errs30 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.owns_record !== undefined){
const _errs32 = errors;
if(typeof data.owns_record !== "boolean"){
validate31.errors = [{instancePath:instancePath+"/owns_record",schemaPath:"#/properties/owns_record/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs32 === errors;
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
validate31.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate31.errors = vErrors;
return errors === 0;
}
validate31.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Head = validate32;
const schema50 = {"type":"object","additionalProperties":false,"properties":{"revision":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"record":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"spec":{"type":"object","additionalProperties":false,"properties":{"format":{"type":"integer","minimum":0,"maximum":4294967295},"length":{"type":"integer","minimum":0,"maximum":4294967295},"digest":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}}},"required":["format","length","digest"]},"principal":{"type":"integer","minimum":0,"maximum":9007199254740991},"operation":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"input":{"type":"integer","minimum":0,"maximum":9007199254740991}},"required":["revision","record","spec","principal","operation","input"]};

function validate32(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate32.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((data.revision === undefined) && (missing0 = "revision")) || ((data.record === undefined) && (missing0 = "record"))) || ((data.spec === undefined) && (missing0 = "spec"))) || ((data.principal === undefined) && (missing0 = "principal"))) || ((data.operation === undefined) && (missing0 = "operation"))) || ((data.input === undefined) && (missing0 = "input"))){
validate32.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "revision") || (key0 === "record")) || (key0 === "spec")) || (key0 === "principal")) || (key0 === "operation")) || (key0 === "input"))){
validate32.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.revision !== undefined){
let data0 = data.revision;
const _errs2 = errors;
if(errors === _errs2){
if(typeof data0 === "string"){
if(func2(data0) > 20){
validate32.errors = [{instancePath:instancePath+"/revision",schemaPath:"#/properties/revision/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern5.test(data0)){
validate32.errors = [{instancePath:instancePath+"/revision",schemaPath:"#/properties/revision/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate32.errors = [{instancePath:instancePath+"/revision",schemaPath:"#/properties/revision/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.record !== undefined){
let data1 = data.record;
const _errs4 = errors;
if(errors === _errs4){
if(typeof data1 === "string"){
if(func2(data1) > 20){
validate32.errors = [{instancePath:instancePath+"/record",schemaPath:"#/properties/record/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern5.test(data1)){
validate32.errors = [{instancePath:instancePath+"/record",schemaPath:"#/properties/record/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate32.errors = [{instancePath:instancePath+"/record",schemaPath:"#/properties/record/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.spec !== undefined){
let data2 = data.spec;
const _errs6 = errors;
if(errors === _errs6){
if(data2 && typeof data2 == "object" && !Array.isArray(data2)){
let missing1;
if((((data2.format === undefined) && (missing1 = "format")) || ((data2.length === undefined) && (missing1 = "length"))) || ((data2.digest === undefined) && (missing1 = "digest"))){
validate32.errors = [{instancePath:instancePath+"/spec",schemaPath:"#/properties/spec/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"}];
return false;
}
else {
const _errs8 = errors;
for(const key1 in data2){
if(!(((key1 === "format") || (key1 === "length")) || (key1 === "digest"))){
validate32.errors = [{instancePath:instancePath+"/spec",schemaPath:"#/properties/spec/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs8 === errors){
if(data2.format !== undefined){
let data3 = data2.format;
const _errs9 = errors;
if(!(((typeof data3 == "number") && (!(data3 % 1) && !isNaN(data3))) && (isFinite(data3)))){
validate32.errors = [{instancePath:instancePath+"/spec/format",schemaPath:"#/properties/spec/properties/format/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs9){
if((typeof data3 == "number") && (isFinite(data3))){
if(data3 > 4294967295 || isNaN(data3)){
validate32.errors = [{instancePath:instancePath+"/spec/format",schemaPath:"#/properties/spec/properties/format/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
return false;
}
else {
if(data3 < 0 || isNaN(data3)){
validate32.errors = [{instancePath:instancePath+"/spec/format",schemaPath:"#/properties/spec/properties/format/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid1 = _errs9 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data2.length !== undefined){
let data4 = data2.length;
const _errs11 = errors;
if(!(((typeof data4 == "number") && (!(data4 % 1) && !isNaN(data4))) && (isFinite(data4)))){
validate32.errors = [{instancePath:instancePath+"/spec/length",schemaPath:"#/properties/spec/properties/length/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs11){
if((typeof data4 == "number") && (isFinite(data4))){
if(data4 > 4294967295 || isNaN(data4)){
validate32.errors = [{instancePath:instancePath+"/spec/length",schemaPath:"#/properties/spec/properties/length/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
return false;
}
else {
if(data4 < 0 || isNaN(data4)){
validate32.errors = [{instancePath:instancePath+"/spec/length",schemaPath:"#/properties/spec/properties/length/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid1 = _errs11 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data2.digest !== undefined){
let data5 = data2.digest;
const _errs13 = errors;
if(errors === _errs13){
if(Array.isArray(data5)){
if(data5.length > 32){
validate32.errors = [{instancePath:instancePath+"/spec/digest",schemaPath:"#/properties/spec/properties/digest/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"}];
return false;
}
else {
if(data5.length < 32){
validate32.errors = [{instancePath:instancePath+"/spec/digest",schemaPath:"#/properties/spec/properties/digest/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"}];
return false;
}
else {
var valid2 = true;
const len0 = data5.length;
for(let i0=0; i0<len0; i0++){
let data6 = data5[i0];
const _errs15 = errors;
if(!(((typeof data6 == "number") && (!(data6 % 1) && !isNaN(data6))) && (isFinite(data6)))){
validate32.errors = [{instancePath:instancePath+"/spec/digest/" + i0,schemaPath:"#/properties/spec/properties/digest/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs15){
if((typeof data6 == "number") && (isFinite(data6))){
if(data6 > 255 || isNaN(data6)){
validate32.errors = [{instancePath:instancePath+"/spec/digest/" + i0,schemaPath:"#/properties/spec/properties/digest/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"}];
return false;
}
else {
if(data6 < 0 || isNaN(data6)){
validate32.errors = [{instancePath:instancePath+"/spec/digest/" + i0,schemaPath:"#/properties/spec/properties/digest/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid2 = _errs15 === errors;
if(!valid2){
break;
}
}
}
}
}
else {
validate32.errors = [{instancePath:instancePath+"/spec/digest",schemaPath:"#/properties/spec/properties/digest/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid1 = _errs13 === errors;
}
else {
var valid1 = true;
}
}
}
}
}
}
else {
validate32.errors = [{instancePath:instancePath+"/spec",schemaPath:"#/properties/spec/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.principal !== undefined){
let data7 = data.principal;
const _errs17 = errors;
if(!(((typeof data7 == "number") && (!(data7 % 1) && !isNaN(data7))) && (isFinite(data7)))){
validate32.errors = [{instancePath:instancePath+"/principal",schemaPath:"#/properties/principal/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs17){
if((typeof data7 == "number") && (isFinite(data7))){
if(data7 > 9007199254740991 || isNaN(data7)){
validate32.errors = [{instancePath:instancePath+"/principal",schemaPath:"#/properties/principal/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data7 < 0 || isNaN(data7)){
validate32.errors = [{instancePath:instancePath+"/principal",schemaPath:"#/properties/principal/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid0 = _errs17 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.operation !== undefined){
let data8 = data.operation;
const _errs19 = errors;
if(errors === _errs19){
if(typeof data8 === "string"){
if(func2(data8) > 20){
validate32.errors = [{instancePath:instancePath+"/operation",schemaPath:"#/properties/operation/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern5.test(data8)){
validate32.errors = [{instancePath:instancePath+"/operation",schemaPath:"#/properties/operation/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate32.errors = [{instancePath:instancePath+"/operation",schemaPath:"#/properties/operation/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs19 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.input !== undefined){
let data9 = data.input;
const _errs21 = errors;
if(!(((typeof data9 == "number") && (!(data9 % 1) && !isNaN(data9))) && (isFinite(data9)))){
validate32.errors = [{instancePath:instancePath+"/input",schemaPath:"#/properties/input/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs21){
if((typeof data9 == "number") && (isFinite(data9))){
if(data9 > 9007199254740991 || isNaN(data9)){
validate32.errors = [{instancePath:instancePath+"/input",schemaPath:"#/properties/input/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data9 < 0 || isNaN(data9)){
validate32.errors = [{instancePath:instancePath+"/input",schemaPath:"#/properties/input/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
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
else {
validate32.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate32.errors = vErrors;
return errors === 0;
}
validate32.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};
