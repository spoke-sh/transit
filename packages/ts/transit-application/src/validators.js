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

export const Command = validate33;
const schema51 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["initialize"],"properties":{"initialize":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["policy"],"properties":{"policy":{"type":"object","additionalProperties":false,"properties":{"principal":{"type":"integer","minimum":0,"maximum":9007199254740991},"expected":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"next":{"type":"object","additionalProperties":false,"properties":{"revision":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"publish":{"type":"boolean"}},"required":["revision","publish"]}},"required":["principal","expected","next"]}}},{"type":"object","additionalProperties":false,"required":["begin"],"properties":{"begin":{"type":"object","additionalProperties":false,"properties":{"operation":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"record":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"expected":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"expected_digest":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"revision":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"spec":{"type":"object","additionalProperties":false,"properties":{"format":{"type":"integer","minimum":0,"maximum":4294967295},"length":{"type":"integer","minimum":0,"maximum":4294967295},"digest":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}}},"required":["format","length","digest"]}},"required":["operation","record","expected","expected_digest","revision","spec"]}}},{"type":"object","additionalProperties":false,"required":["part"],"properties":{"part":{"type":"object","additionalProperties":false,"properties":{"operation":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"ordinal":{"type":"integer","minimum":0,"maximum":4294967295},"second":{"type":"boolean"},"bytes":{"type":"string","pattern":"^(?:[0-9a-f]{2})+$","maxLength":256}},"required":["operation","ordinal","second","bytes"]}}},{"type":"object","additionalProperties":false,"required":["publish"],"properties":{"publish":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20}}},{"type":"object","additionalProperties":false,"required":["abandon"],"properties":{"abandon":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20}}},{"type":"object","additionalProperties":false,"required":["collect"],"properties":{"collect":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20}}}]};
const pattern53 = new RegExp("^(?:[0-9a-f]{2})+$", "u");

function validate33(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate33.evaluated;
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
if((data.initialize === undefined) && (missing0 = "initialize")){
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
if(!(key0 === "initialize")){
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
if(data.initialize !== undefined){
let data0 = data.initialize;
const _errs4 = errors;
if(errors === _errs4){
if(data0 && typeof data0 == "object" && !Array.isArray(data0)){
if(Object.keys(data0).length > 0){
const err2 = {instancePath:instancePath+"/initialize",schemaPath:"#/oneOf/0/properties/initialize/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
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
const err3 = {instancePath:instancePath+"/initialize",schemaPath:"#/oneOf/0/properties/initialize/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.policy === undefined) && (missing1 = "policy")){
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
if(!(key1 === "policy")){
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
if(data.policy !== undefined){
let data1 = data.policy;
const _errs9 = errors;
if(errors === _errs9){
if(data1 && typeof data1 == "object" && !Array.isArray(data1)){
let missing2;
if((((data1.principal === undefined) && (missing2 = "principal")) || ((data1.expected === undefined) && (missing2 = "expected"))) || ((data1.next === undefined) && (missing2 = "next"))){
const err7 = {instancePath:instancePath+"/policy",schemaPath:"#/oneOf/1/properties/policy/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
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
if(!(((key2 === "principal") || (key2 === "expected")) || (key2 === "next"))){
const err8 = {instancePath:instancePath+"/policy",schemaPath:"#/oneOf/1/properties/policy/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(data1.principal !== undefined){
let data2 = data1.principal;
const _errs12 = errors;
if(!(((typeof data2 == "number") && (!(data2 % 1) && !isNaN(data2))) && (isFinite(data2)))){
const err9 = {instancePath:instancePath+"/policy/principal",schemaPath:"#/oneOf/1/properties/policy/properties/principal/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
}
if(errors === _errs12){
if((typeof data2 == "number") && (isFinite(data2))){
if(data2 > 9007199254740991 || isNaN(data2)){
const err10 = {instancePath:instancePath+"/policy/principal",schemaPath:"#/oneOf/1/properties/policy/properties/principal/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
}
else {
if(data2 < 0 || isNaN(data2)){
const err11 = {instancePath:instancePath+"/policy/principal",schemaPath:"#/oneOf/1/properties/policy/properties/principal/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
if(data1.expected !== undefined){
let data3 = data1.expected;
const _errs14 = errors;
if(errors === _errs14){
if(typeof data3 === "string"){
if(func2(data3) > 20){
const err12 = {instancePath:instancePath+"/policy/expected",schemaPath:"#/oneOf/1/properties/policy/properties/expected/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
}
else {
if(!pattern5.test(data3)){
const err13 = {instancePath:instancePath+"/policy/expected",schemaPath:"#/oneOf/1/properties/policy/properties/expected/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err14 = {instancePath:instancePath+"/policy/expected",schemaPath:"#/oneOf/1/properties/policy/properties/expected/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err14];
}
else {
vErrors.push(err14);
}
errors++;
}
}
var valid3 = _errs14 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data1.next !== undefined){
let data4 = data1.next;
const _errs16 = errors;
if(errors === _errs16){
if(data4 && typeof data4 == "object" && !Array.isArray(data4)){
let missing3;
if(((data4.revision === undefined) && (missing3 = "revision")) || ((data4.publish === undefined) && (missing3 = "publish"))){
const err15 = {instancePath:instancePath+"/policy/next",schemaPath:"#/oneOf/1/properties/policy/properties/next/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
}
else {
const _errs18 = errors;
for(const key3 in data4){
if(!((key3 === "revision") || (key3 === "publish"))){
const err16 = {instancePath:instancePath+"/policy/next",schemaPath:"#/oneOf/1/properties/policy/properties/next/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(_errs18 === errors){
if(data4.revision !== undefined){
let data5 = data4.revision;
const _errs19 = errors;
if(errors === _errs19){
if(typeof data5 === "string"){
if(func2(data5) > 20){
const err17 = {instancePath:instancePath+"/policy/next/revision",schemaPath:"#/oneOf/1/properties/policy/properties/next/properties/revision/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err17];
}
else {
vErrors.push(err17);
}
errors++;
}
else {
if(!pattern5.test(data5)){
const err18 = {instancePath:instancePath+"/policy/next/revision",schemaPath:"#/oneOf/1/properties/policy/properties/next/properties/revision/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
}
}
}
else {
const err19 = {instancePath:instancePath+"/policy/next/revision",schemaPath:"#/oneOf/1/properties/policy/properties/next/properties/revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
}
}
var valid4 = _errs19 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data4.publish !== undefined){
const _errs21 = errors;
if(typeof data4.publish !== "boolean"){
const err20 = {instancePath:instancePath+"/policy/next/publish",schemaPath:"#/oneOf/1/properties/policy/properties/next/properties/publish/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err20];
}
else {
vErrors.push(err20);
}
errors++;
}
var valid4 = _errs21 === errors;
}
else {
var valid4 = true;
}
}
}
}
}
else {
const err21 = {instancePath:instancePath+"/policy/next",schemaPath:"#/oneOf/1/properties/policy/properties/next/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
}
errors++;
}
}
var valid3 = _errs16 === errors;
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
const err22 = {instancePath:instancePath+"/policy",schemaPath:"#/oneOf/1/properties/policy/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
}
else {
const err23 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err23];
}
else {
vErrors.push(err23);
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
const _errs23 = errors;
if(errors === _errs23){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing4;
if((data.begin === undefined) && (missing4 = "begin")){
const err24 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
}
errors++;
}
else {
const _errs25 = errors;
for(const key4 in data){
if(!(key4 === "begin")){
const err25 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(_errs25 === errors){
if(data.begin !== undefined){
let data7 = data.begin;
const _errs26 = errors;
if(errors === _errs26){
if(data7 && typeof data7 == "object" && !Array.isArray(data7)){
let missing5;
if(((((((data7.operation === undefined) && (missing5 = "operation")) || ((data7.record === undefined) && (missing5 = "record"))) || ((data7.expected === undefined) && (missing5 = "expected"))) || ((data7.expected_digest === undefined) && (missing5 = "expected_digest"))) || ((data7.revision === undefined) && (missing5 = "revision"))) || ((data7.spec === undefined) && (missing5 = "spec"))){
const err26 = {instancePath:instancePath+"/begin",schemaPath:"#/oneOf/2/properties/begin/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
if(vErrors === null){
vErrors = [err26];
}
else {
vErrors.push(err26);
}
errors++;
}
else {
const _errs28 = errors;
for(const key5 in data7){
if(!((((((key5 === "operation") || (key5 === "record")) || (key5 === "expected")) || (key5 === "expected_digest")) || (key5 === "revision")) || (key5 === "spec"))){
const err27 = {instancePath:instancePath+"/begin",schemaPath:"#/oneOf/2/properties/begin/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err27];
}
else {
vErrors.push(err27);
}
errors++;
break;
}
}
if(_errs28 === errors){
if(data7.operation !== undefined){
let data8 = data7.operation;
const _errs29 = errors;
if(errors === _errs29){
if(typeof data8 === "string"){
if(func2(data8) > 20){
const err28 = {instancePath:instancePath+"/begin/operation",schemaPath:"#/oneOf/2/properties/begin/properties/operation/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err28];
}
else {
vErrors.push(err28);
}
errors++;
}
else {
if(!pattern5.test(data8)){
const err29 = {instancePath:instancePath+"/begin/operation",schemaPath:"#/oneOf/2/properties/begin/properties/operation/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err30 = {instancePath:instancePath+"/begin/operation",schemaPath:"#/oneOf/2/properties/begin/properties/operation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
}
errors++;
}
}
var valid6 = _errs29 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data7.record !== undefined){
let data9 = data7.record;
const _errs31 = errors;
if(errors === _errs31){
if(typeof data9 === "string"){
if(func2(data9) > 20){
const err31 = {instancePath:instancePath+"/begin/record",schemaPath:"#/oneOf/2/properties/begin/properties/record/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err31];
}
else {
vErrors.push(err31);
}
errors++;
}
else {
if(!pattern5.test(data9)){
const err32 = {instancePath:instancePath+"/begin/record",schemaPath:"#/oneOf/2/properties/begin/properties/record/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err33 = {instancePath:instancePath+"/begin/record",schemaPath:"#/oneOf/2/properties/begin/properties/record/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
}
var valid6 = _errs31 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data7.expected !== undefined){
let data10 = data7.expected;
const _errs33 = errors;
if(errors === _errs33){
if(typeof data10 === "string"){
if(func2(data10) > 20){
const err34 = {instancePath:instancePath+"/begin/expected",schemaPath:"#/oneOf/2/properties/begin/properties/expected/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err34];
}
else {
vErrors.push(err34);
}
errors++;
}
else {
if(!pattern5.test(data10)){
const err35 = {instancePath:instancePath+"/begin/expected",schemaPath:"#/oneOf/2/properties/begin/properties/expected/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err36 = {instancePath:instancePath+"/begin/expected",schemaPath:"#/oneOf/2/properties/begin/properties/expected/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
}
}
var valid6 = _errs33 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data7.expected_digest !== undefined){
let data11 = data7.expected_digest;
const _errs35 = errors;
if(errors === _errs35){
if(Array.isArray(data11)){
if(data11.length > 32){
const err37 = {instancePath:instancePath+"/begin/expected_digest",schemaPath:"#/oneOf/2/properties/begin/properties/expected_digest/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err37];
}
else {
vErrors.push(err37);
}
errors++;
}
else {
if(data11.length < 32){
const err38 = {instancePath:instancePath+"/begin/expected_digest",schemaPath:"#/oneOf/2/properties/begin/properties/expected_digest/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err38];
}
else {
vErrors.push(err38);
}
errors++;
}
else {
var valid7 = true;
const len0 = data11.length;
for(let i0=0; i0<len0; i0++){
let data12 = data11[i0];
const _errs37 = errors;
if(!(((typeof data12 == "number") && (!(data12 % 1) && !isNaN(data12))) && (isFinite(data12)))){
const err39 = {instancePath:instancePath+"/begin/expected_digest/" + i0,schemaPath:"#/oneOf/2/properties/begin/properties/expected_digest/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err39];
}
else {
vErrors.push(err39);
}
errors++;
}
if(errors === _errs37){
if((typeof data12 == "number") && (isFinite(data12))){
if(data12 > 255 || isNaN(data12)){
const err40 = {instancePath:instancePath+"/begin/expected_digest/" + i0,schemaPath:"#/oneOf/2/properties/begin/properties/expected_digest/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err40];
}
else {
vErrors.push(err40);
}
errors++;
}
else {
if(data12 < 0 || isNaN(data12)){
const err41 = {instancePath:instancePath+"/begin/expected_digest/" + i0,schemaPath:"#/oneOf/2/properties/begin/properties/expected_digest/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err41];
}
else {
vErrors.push(err41);
}
errors++;
}
}
}
}
var valid7 = _errs37 === errors;
if(!valid7){
break;
}
}
}
}
}
else {
const err42 = {instancePath:instancePath+"/begin/expected_digest",schemaPath:"#/oneOf/2/properties/begin/properties/expected_digest/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err42];
}
else {
vErrors.push(err42);
}
errors++;
}
}
var valid6 = _errs35 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data7.revision !== undefined){
let data13 = data7.revision;
const _errs39 = errors;
if(errors === _errs39){
if(typeof data13 === "string"){
if(func2(data13) > 20){
const err43 = {instancePath:instancePath+"/begin/revision",schemaPath:"#/oneOf/2/properties/begin/properties/revision/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err43];
}
else {
vErrors.push(err43);
}
errors++;
}
else {
if(!pattern5.test(data13)){
const err44 = {instancePath:instancePath+"/begin/revision",schemaPath:"#/oneOf/2/properties/begin/properties/revision/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
const err45 = {instancePath:instancePath+"/begin/revision",schemaPath:"#/oneOf/2/properties/begin/properties/revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err45];
}
else {
vErrors.push(err45);
}
errors++;
}
}
var valid6 = _errs39 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data7.spec !== undefined){
let data14 = data7.spec;
const _errs41 = errors;
if(errors === _errs41){
if(data14 && typeof data14 == "object" && !Array.isArray(data14)){
let missing6;
if((((data14.format === undefined) && (missing6 = "format")) || ((data14.length === undefined) && (missing6 = "length"))) || ((data14.digest === undefined) && (missing6 = "digest"))){
const err46 = {instancePath:instancePath+"/begin/spec",schemaPath:"#/oneOf/2/properties/begin/properties/spec/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
if(vErrors === null){
vErrors = [err46];
}
else {
vErrors.push(err46);
}
errors++;
}
else {
const _errs43 = errors;
for(const key6 in data14){
if(!(((key6 === "format") || (key6 === "length")) || (key6 === "digest"))){
const err47 = {instancePath:instancePath+"/begin/spec",schemaPath:"#/oneOf/2/properties/begin/properties/spec/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
if(_errs43 === errors){
if(data14.format !== undefined){
let data15 = data14.format;
const _errs44 = errors;
if(!(((typeof data15 == "number") && (!(data15 % 1) && !isNaN(data15))) && (isFinite(data15)))){
const err48 = {instancePath:instancePath+"/begin/spec/format",schemaPath:"#/oneOf/2/properties/begin/properties/spec/properties/format/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err48];
}
else {
vErrors.push(err48);
}
errors++;
}
if(errors === _errs44){
if((typeof data15 == "number") && (isFinite(data15))){
if(data15 > 4294967295 || isNaN(data15)){
const err49 = {instancePath:instancePath+"/begin/spec/format",schemaPath:"#/oneOf/2/properties/begin/properties/spec/properties/format/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err49];
}
else {
vErrors.push(err49);
}
errors++;
}
else {
if(data15 < 0 || isNaN(data15)){
const err50 = {instancePath:instancePath+"/begin/spec/format",schemaPath:"#/oneOf/2/properties/begin/properties/spec/properties/format/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
}
var valid8 = _errs44 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data14.length !== undefined){
let data16 = data14.length;
const _errs46 = errors;
if(!(((typeof data16 == "number") && (!(data16 % 1) && !isNaN(data16))) && (isFinite(data16)))){
const err51 = {instancePath:instancePath+"/begin/spec/length",schemaPath:"#/oneOf/2/properties/begin/properties/spec/properties/length/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err51];
}
else {
vErrors.push(err51);
}
errors++;
}
if(errors === _errs46){
if((typeof data16 == "number") && (isFinite(data16))){
if(data16 > 4294967295 || isNaN(data16)){
const err52 = {instancePath:instancePath+"/begin/spec/length",schemaPath:"#/oneOf/2/properties/begin/properties/spec/properties/length/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err52];
}
else {
vErrors.push(err52);
}
errors++;
}
else {
if(data16 < 0 || isNaN(data16)){
const err53 = {instancePath:instancePath+"/begin/spec/length",schemaPath:"#/oneOf/2/properties/begin/properties/spec/properties/length/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid8 = _errs46 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data14.digest !== undefined){
let data17 = data14.digest;
const _errs48 = errors;
if(errors === _errs48){
if(Array.isArray(data17)){
if(data17.length > 32){
const err54 = {instancePath:instancePath+"/begin/spec/digest",schemaPath:"#/oneOf/2/properties/begin/properties/spec/properties/digest/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err54];
}
else {
vErrors.push(err54);
}
errors++;
}
else {
if(data17.length < 32){
const err55 = {instancePath:instancePath+"/begin/spec/digest",schemaPath:"#/oneOf/2/properties/begin/properties/spec/properties/digest/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err55];
}
else {
vErrors.push(err55);
}
errors++;
}
else {
var valid9 = true;
const len1 = data17.length;
for(let i1=0; i1<len1; i1++){
let data18 = data17[i1];
const _errs50 = errors;
if(!(((typeof data18 == "number") && (!(data18 % 1) && !isNaN(data18))) && (isFinite(data18)))){
const err56 = {instancePath:instancePath+"/begin/spec/digest/" + i1,schemaPath:"#/oneOf/2/properties/begin/properties/spec/properties/digest/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err56];
}
else {
vErrors.push(err56);
}
errors++;
}
if(errors === _errs50){
if((typeof data18 == "number") && (isFinite(data18))){
if(data18 > 255 || isNaN(data18)){
const err57 = {instancePath:instancePath+"/begin/spec/digest/" + i1,schemaPath:"#/oneOf/2/properties/begin/properties/spec/properties/digest/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err57];
}
else {
vErrors.push(err57);
}
errors++;
}
else {
if(data18 < 0 || isNaN(data18)){
const err58 = {instancePath:instancePath+"/begin/spec/digest/" + i1,schemaPath:"#/oneOf/2/properties/begin/properties/spec/properties/digest/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid9 = _errs50 === errors;
if(!valid9){
break;
}
}
}
}
}
else {
const err59 = {instancePath:instancePath+"/begin/spec/digest",schemaPath:"#/oneOf/2/properties/begin/properties/spec/properties/digest/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err59];
}
else {
vErrors.push(err59);
}
errors++;
}
}
var valid8 = _errs48 === errors;
}
else {
var valid8 = true;
}
}
}
}
}
}
else {
const err60 = {instancePath:instancePath+"/begin/spec",schemaPath:"#/oneOf/2/properties/begin/properties/spec/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err60];
}
else {
vErrors.push(err60);
}
errors++;
}
}
var valid6 = _errs41 === errors;
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
const err61 = {instancePath:instancePath+"/begin",schemaPath:"#/oneOf/2/properties/begin/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err61];
}
else {
vErrors.push(err61);
}
errors++;
}
}
}
}
}
}
else {
const err62 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err62];
}
else {
vErrors.push(err62);
}
errors++;
}
}
var _valid0 = _errs23 === errors;
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
const _errs52 = errors;
if(errors === _errs52){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing7;
if((data.part === undefined) && (missing7 = "part")){
const err63 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
if(vErrors === null){
vErrors = [err63];
}
else {
vErrors.push(err63);
}
errors++;
}
else {
const _errs54 = errors;
for(const key7 in data){
if(!(key7 === "part")){
const err64 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
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
if(_errs54 === errors){
if(data.part !== undefined){
let data19 = data.part;
const _errs55 = errors;
if(errors === _errs55){
if(data19 && typeof data19 == "object" && !Array.isArray(data19)){
let missing8;
if(((((data19.operation === undefined) && (missing8 = "operation")) || ((data19.ordinal === undefined) && (missing8 = "ordinal"))) || ((data19.second === undefined) && (missing8 = "second"))) || ((data19.bytes === undefined) && (missing8 = "bytes"))){
const err65 = {instancePath:instancePath+"/part",schemaPath:"#/oneOf/3/properties/part/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
if(vErrors === null){
vErrors = [err65];
}
else {
vErrors.push(err65);
}
errors++;
}
else {
const _errs57 = errors;
for(const key8 in data19){
if(!((((key8 === "operation") || (key8 === "ordinal")) || (key8 === "second")) || (key8 === "bytes"))){
const err66 = {instancePath:instancePath+"/part",schemaPath:"#/oneOf/3/properties/part/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
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
if(_errs57 === errors){
if(data19.operation !== undefined){
let data20 = data19.operation;
const _errs58 = errors;
if(errors === _errs58){
if(typeof data20 === "string"){
if(func2(data20) > 20){
const err67 = {instancePath:instancePath+"/part/operation",schemaPath:"#/oneOf/3/properties/part/properties/operation/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err67];
}
else {
vErrors.push(err67);
}
errors++;
}
else {
if(!pattern5.test(data20)){
const err68 = {instancePath:instancePath+"/part/operation",schemaPath:"#/oneOf/3/properties/part/properties/operation/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err69 = {instancePath:instancePath+"/part/operation",schemaPath:"#/oneOf/3/properties/part/properties/operation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err69];
}
else {
vErrors.push(err69);
}
errors++;
}
}
var valid11 = _errs58 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data19.ordinal !== undefined){
let data21 = data19.ordinal;
const _errs60 = errors;
if(!(((typeof data21 == "number") && (!(data21 % 1) && !isNaN(data21))) && (isFinite(data21)))){
const err70 = {instancePath:instancePath+"/part/ordinal",schemaPath:"#/oneOf/3/properties/part/properties/ordinal/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err70];
}
else {
vErrors.push(err70);
}
errors++;
}
if(errors === _errs60){
if((typeof data21 == "number") && (isFinite(data21))){
if(data21 > 4294967295 || isNaN(data21)){
const err71 = {instancePath:instancePath+"/part/ordinal",schemaPath:"#/oneOf/3/properties/part/properties/ordinal/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err71];
}
else {
vErrors.push(err71);
}
errors++;
}
else {
if(data21 < 0 || isNaN(data21)){
const err72 = {instancePath:instancePath+"/part/ordinal",schemaPath:"#/oneOf/3/properties/part/properties/ordinal/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err72];
}
else {
vErrors.push(err72);
}
errors++;
}
}
}
}
var valid11 = _errs60 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data19.second !== undefined){
const _errs62 = errors;
if(typeof data19.second !== "boolean"){
const err73 = {instancePath:instancePath+"/part/second",schemaPath:"#/oneOf/3/properties/part/properties/second/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err73];
}
else {
vErrors.push(err73);
}
errors++;
}
var valid11 = _errs62 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data19.bytes !== undefined){
let data23 = data19.bytes;
const _errs64 = errors;
if(errors === _errs64){
if(typeof data23 === "string"){
if(func2(data23) > 256){
const err74 = {instancePath:instancePath+"/part/bytes",schemaPath:"#/oneOf/3/properties/part/properties/bytes/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err74];
}
else {
vErrors.push(err74);
}
errors++;
}
else {
if(!pattern53.test(data23)){
const err75 = {instancePath:instancePath+"/part/bytes",schemaPath:"#/oneOf/3/properties/part/properties/bytes/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})+$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})+$"+"\""};
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
else {
const err76 = {instancePath:instancePath+"/part/bytes",schemaPath:"#/oneOf/3/properties/part/properties/bytes/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err76];
}
else {
vErrors.push(err76);
}
errors++;
}
}
var valid11 = _errs64 === errors;
}
else {
var valid11 = true;
}
}
}
}
}
}
}
else {
const err77 = {instancePath:instancePath+"/part",schemaPath:"#/oneOf/3/properties/part/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err77];
}
else {
vErrors.push(err77);
}
errors++;
}
}
}
}
}
}
else {
const err78 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err78];
}
else {
vErrors.push(err78);
}
errors++;
}
}
var _valid0 = _errs52 === errors;
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
const _errs66 = errors;
if(errors === _errs66){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing9;
if((data.publish === undefined) && (missing9 = "publish")){
const err79 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
if(vErrors === null){
vErrors = [err79];
}
else {
vErrors.push(err79);
}
errors++;
}
else {
const _errs68 = errors;
for(const key9 in data){
if(!(key9 === "publish")){
const err80 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
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
if(_errs68 === errors){
if(data.publish !== undefined){
let data24 = data.publish;
const _errs69 = errors;
if(errors === _errs69){
if(typeof data24 === "string"){
if(func2(data24) > 20){
const err81 = {instancePath:instancePath+"/publish",schemaPath:"#/oneOf/4/properties/publish/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err81];
}
else {
vErrors.push(err81);
}
errors++;
}
else {
if(!pattern5.test(data24)){
const err82 = {instancePath:instancePath+"/publish",schemaPath:"#/oneOf/4/properties/publish/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err83 = {instancePath:instancePath+"/publish",schemaPath:"#/oneOf/4/properties/publish/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err83];
}
else {
vErrors.push(err83);
}
errors++;
}
}
}
}
}
}
else {
const err84 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err84];
}
else {
vErrors.push(err84);
}
errors++;
}
}
var _valid0 = _errs66 === errors;
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
const _errs71 = errors;
if(errors === _errs71){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing10;
if((data.abandon === undefined) && (missing10 = "abandon")){
const err85 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"};
if(vErrors === null){
vErrors = [err85];
}
else {
vErrors.push(err85);
}
errors++;
}
else {
const _errs73 = errors;
for(const key10 in data){
if(!(key10 === "abandon")){
const err86 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err86];
}
else {
vErrors.push(err86);
}
errors++;
break;
}
}
if(_errs73 === errors){
if(data.abandon !== undefined){
let data25 = data.abandon;
const _errs74 = errors;
if(errors === _errs74){
if(typeof data25 === "string"){
if(func2(data25) > 20){
const err87 = {instancePath:instancePath+"/abandon",schemaPath:"#/oneOf/5/properties/abandon/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err87];
}
else {
vErrors.push(err87);
}
errors++;
}
else {
if(!pattern5.test(data25)){
const err88 = {instancePath:instancePath+"/abandon",schemaPath:"#/oneOf/5/properties/abandon/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err89 = {instancePath:instancePath+"/abandon",schemaPath:"#/oneOf/5/properties/abandon/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err89];
}
else {
vErrors.push(err89);
}
errors++;
}
}
}
}
}
}
else {
const err90 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err90];
}
else {
vErrors.push(err90);
}
errors++;
}
}
var _valid0 = _errs71 === errors;
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
const _errs76 = errors;
if(errors === _errs76){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing11;
if((data.collect === undefined) && (missing11 = "collect")){
const err91 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
if(vErrors === null){
vErrors = [err91];
}
else {
vErrors.push(err91);
}
errors++;
}
else {
const _errs78 = errors;
for(const key11 in data){
if(!(key11 === "collect")){
const err92 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
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
if(_errs78 === errors){
if(data.collect !== undefined){
let data26 = data.collect;
const _errs79 = errors;
if(errors === _errs79){
if(typeof data26 === "string"){
if(func2(data26) > 20){
const err93 = {instancePath:instancePath+"/collect",schemaPath:"#/oneOf/6/properties/collect/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err93];
}
else {
vErrors.push(err93);
}
errors++;
}
else {
if(!pattern5.test(data26)){
const err94 = {instancePath:instancePath+"/collect",schemaPath:"#/oneOf/6/properties/collect/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err95 = {instancePath:instancePath+"/collect",schemaPath:"#/oneOf/6/properties/collect/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
const err96 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err96];
}
else {
vErrors.push(err96);
}
errors++;
}
}
var _valid0 = _errs76 === errors;
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
}
}
}
}
}
}
if(!valid0){
const err97 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err97];
}
else {
vErrors.push(err97);
}
errors++;
validate33.errors = vErrors;
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
validate33.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate33.evaluated = {"dynamicProps":true,"dynamicItems":false};

export const Scope = validate34;
const schema52 = {"type":"object","additionalProperties":false,"properties":{"realm":{"type":"integer","minimum":0,"maximum":9007199254740991},"application":{"type":"integer","minimum":0,"maximum":9007199254740991},"pid":{"type":"integer","minimum":0,"maximum":9007199254740991},"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"namespace":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20}},"required":["realm","application","pid","resource","namespace"]};

function validate34(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate34.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.realm === undefined) && (missing0 = "realm")) || ((data.application === undefined) && (missing0 = "application"))) || ((data.pid === undefined) && (missing0 = "pid"))) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.namespace === undefined) && (missing0 = "namespace"))){
validate34.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "realm") || (key0 === "application")) || (key0 === "pid")) || (key0 === "resource")) || (key0 === "namespace"))){
validate34.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
let data0 = data.realm;
const _errs2 = errors;
if(!(((typeof data0 == "number") && (!(data0 % 1) && !isNaN(data0))) && (isFinite(data0)))){
validate34.errors = [{instancePath:instancePath+"/realm",schemaPath:"#/properties/realm/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs2){
if((typeof data0 == "number") && (isFinite(data0))){
if(data0 > 9007199254740991 || isNaN(data0)){
validate34.errors = [{instancePath:instancePath+"/realm",schemaPath:"#/properties/realm/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data0 < 0 || isNaN(data0)){
validate34.errors = [{instancePath:instancePath+"/realm",schemaPath:"#/properties/realm/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
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
if(data.application !== undefined){
let data1 = data.application;
const _errs4 = errors;
if(!(((typeof data1 == "number") && (!(data1 % 1) && !isNaN(data1))) && (isFinite(data1)))){
validate34.errors = [{instancePath:instancePath+"/application",schemaPath:"#/properties/application/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs4){
if((typeof data1 == "number") && (isFinite(data1))){
if(data1 > 9007199254740991 || isNaN(data1)){
validate34.errors = [{instancePath:instancePath+"/application",schemaPath:"#/properties/application/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data1 < 0 || isNaN(data1)){
validate34.errors = [{instancePath:instancePath+"/application",schemaPath:"#/properties/application/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
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
if(data.pid !== undefined){
let data2 = data.pid;
const _errs6 = errors;
if(!(((typeof data2 == "number") && (!(data2 % 1) && !isNaN(data2))) && (isFinite(data2)))){
validate34.errors = [{instancePath:instancePath+"/pid",schemaPath:"#/properties/pid/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs6){
if((typeof data2 == "number") && (isFinite(data2))){
if(data2 > 9007199254740991 || isNaN(data2)){
validate34.errors = [{instancePath:instancePath+"/pid",schemaPath:"#/properties/pid/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data2 < 0 || isNaN(data2)){
validate34.errors = [{instancePath:instancePath+"/pid",schemaPath:"#/properties/pid/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
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
if(data.resource !== undefined){
let data3 = data.resource;
const _errs8 = errors;
if(!(((typeof data3 == "number") && (!(data3 % 1) && !isNaN(data3))) && (isFinite(data3)))){
validate34.errors = [{instancePath:instancePath+"/resource",schemaPath:"#/properties/resource/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs8){
if((typeof data3 == "number") && (isFinite(data3))){
if(data3 > 9007199254740991 || isNaN(data3)){
validate34.errors = [{instancePath:instancePath+"/resource",schemaPath:"#/properties/resource/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data3 < 0 || isNaN(data3)){
validate34.errors = [{instancePath:instancePath+"/resource",schemaPath:"#/properties/resource/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
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
if(data.namespace !== undefined){
let data4 = data.namespace;
const _errs10 = errors;
if(errors === _errs10){
if(typeof data4 === "string"){
if(func2(data4) > 20){
validate34.errors = [{instancePath:instancePath+"/namespace",schemaPath:"#/properties/namespace/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern5.test(data4)){
validate34.errors = [{instancePath:instancePath+"/namespace",schemaPath:"#/properties/namespace/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate34.errors = [{instancePath:instancePath+"/namespace",schemaPath:"#/properties/namespace/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
validate34.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate34.errors = vErrors;
return errors === 0;
}
validate34.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Prepared = validate35;
const schema53 = {"type":"object","additionalProperties":false,"properties":{"scope":{"type":"object","additionalProperties":false,"properties":{"realm":{"type":"integer","minimum":0,"maximum":9007199254740991},"application":{"type":"integer","minimum":0,"maximum":9007199254740991},"pid":{"type":"integer","minimum":0,"maximum":9007199254740991},"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"namespace":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20}},"required":["realm","application","pid","resource","namespace"]},"principal":{"type":"integer","minimum":0,"maximum":9007199254740991},"sequence":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"command":{"oneOf":[{"type":"object","additionalProperties":false,"required":["initialize"],"properties":{"initialize":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["policy"],"properties":{"policy":{"type":"object","additionalProperties":false,"properties":{"principal":{"type":"integer","minimum":0,"maximum":9007199254740991},"expected":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"next":{"type":"object","additionalProperties":false,"properties":{"revision":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"publish":{"type":"boolean"}},"required":["revision","publish"]}},"required":["principal","expected","next"]}}},{"type":"object","additionalProperties":false,"required":["begin"],"properties":{"begin":{"type":"object","additionalProperties":false,"properties":{"operation":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"record":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"expected":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"expected_digest":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"revision":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"spec":{"type":"object","additionalProperties":false,"properties":{"format":{"type":"integer","minimum":0,"maximum":4294967295},"length":{"type":"integer","minimum":0,"maximum":4294967295},"digest":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}}},"required":["format","length","digest"]}},"required":["operation","record","expected","expected_digest","revision","spec"]}}},{"type":"object","additionalProperties":false,"required":["part"],"properties":{"part":{"type":"object","additionalProperties":false,"properties":{"operation":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"ordinal":{"type":"integer","minimum":0,"maximum":4294967295},"second":{"type":"boolean"},"bytes":{"type":"string","pattern":"^(?:[0-9a-f]{2})+$","maxLength":256}},"required":["operation","ordinal","second","bytes"]}}},{"type":"object","additionalProperties":false,"required":["publish"],"properties":{"publish":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20}}},{"type":"object","additionalProperties":false,"required":["abandon"],"properties":{"abandon":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20}}},{"type":"object","additionalProperties":false,"required":["collect"],"properties":{"collect":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20}}}]},"digest":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}}},"required":["scope","principal","sequence","command","digest"]};

function validate35(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate35.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.scope === undefined) && (missing0 = "scope")) || ((data.principal === undefined) && (missing0 = "principal"))) || ((data.sequence === undefined) && (missing0 = "sequence"))) || ((data.command === undefined) && (missing0 = "command"))) || ((data.digest === undefined) && (missing0 = "digest"))){
validate35.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "scope") || (key0 === "principal")) || (key0 === "sequence")) || (key0 === "command")) || (key0 === "digest"))){
validate35.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
let data0 = data.scope;
const _errs2 = errors;
if(errors === _errs2){
if(data0 && typeof data0 == "object" && !Array.isArray(data0)){
let missing1;
if((((((data0.realm === undefined) && (missing1 = "realm")) || ((data0.application === undefined) && (missing1 = "application"))) || ((data0.pid === undefined) && (missing1 = "pid"))) || ((data0.resource === undefined) && (missing1 = "resource"))) || ((data0.namespace === undefined) && (missing1 = "namespace"))){
validate35.errors = [{instancePath:instancePath+"/scope",schemaPath:"#/properties/scope/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"}];
return false;
}
else {
const _errs4 = errors;
for(const key1 in data0){
if(!(((((key1 === "realm") || (key1 === "application")) || (key1 === "pid")) || (key1 === "resource")) || (key1 === "namespace"))){
validate35.errors = [{instancePath:instancePath+"/scope",schemaPath:"#/properties/scope/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs4 === errors){
if(data0.realm !== undefined){
let data1 = data0.realm;
const _errs5 = errors;
if(!(((typeof data1 == "number") && (!(data1 % 1) && !isNaN(data1))) && (isFinite(data1)))){
validate35.errors = [{instancePath:instancePath+"/scope/realm",schemaPath:"#/properties/scope/properties/realm/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs5){
if((typeof data1 == "number") && (isFinite(data1))){
if(data1 > 9007199254740991 || isNaN(data1)){
validate35.errors = [{instancePath:instancePath+"/scope/realm",schemaPath:"#/properties/scope/properties/realm/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data1 < 0 || isNaN(data1)){
validate35.errors = [{instancePath:instancePath+"/scope/realm",schemaPath:"#/properties/scope/properties/realm/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid1 = _errs5 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.application !== undefined){
let data2 = data0.application;
const _errs7 = errors;
if(!(((typeof data2 == "number") && (!(data2 % 1) && !isNaN(data2))) && (isFinite(data2)))){
validate35.errors = [{instancePath:instancePath+"/scope/application",schemaPath:"#/properties/scope/properties/application/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs7){
if((typeof data2 == "number") && (isFinite(data2))){
if(data2 > 9007199254740991 || isNaN(data2)){
validate35.errors = [{instancePath:instancePath+"/scope/application",schemaPath:"#/properties/scope/properties/application/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data2 < 0 || isNaN(data2)){
validate35.errors = [{instancePath:instancePath+"/scope/application",schemaPath:"#/properties/scope/properties/application/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid1 = _errs7 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.pid !== undefined){
let data3 = data0.pid;
const _errs9 = errors;
if(!(((typeof data3 == "number") && (!(data3 % 1) && !isNaN(data3))) && (isFinite(data3)))){
validate35.errors = [{instancePath:instancePath+"/scope/pid",schemaPath:"#/properties/scope/properties/pid/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs9){
if((typeof data3 == "number") && (isFinite(data3))){
if(data3 > 9007199254740991 || isNaN(data3)){
validate35.errors = [{instancePath:instancePath+"/scope/pid",schemaPath:"#/properties/scope/properties/pid/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data3 < 0 || isNaN(data3)){
validate35.errors = [{instancePath:instancePath+"/scope/pid",schemaPath:"#/properties/scope/properties/pid/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
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
if(data0.resource !== undefined){
let data4 = data0.resource;
const _errs11 = errors;
if(!(((typeof data4 == "number") && (!(data4 % 1) && !isNaN(data4))) && (isFinite(data4)))){
validate35.errors = [{instancePath:instancePath+"/scope/resource",schemaPath:"#/properties/scope/properties/resource/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs11){
if((typeof data4 == "number") && (isFinite(data4))){
if(data4 > 9007199254740991 || isNaN(data4)){
validate35.errors = [{instancePath:instancePath+"/scope/resource",schemaPath:"#/properties/scope/properties/resource/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data4 < 0 || isNaN(data4)){
validate35.errors = [{instancePath:instancePath+"/scope/resource",schemaPath:"#/properties/scope/properties/resource/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
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
if(data0.namespace !== undefined){
let data5 = data0.namespace;
const _errs13 = errors;
if(errors === _errs13){
if(typeof data5 === "string"){
if(func2(data5) > 20){
validate35.errors = [{instancePath:instancePath+"/scope/namespace",schemaPath:"#/properties/scope/properties/namespace/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern5.test(data5)){
validate35.errors = [{instancePath:instancePath+"/scope/namespace",schemaPath:"#/properties/scope/properties/namespace/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate35.errors = [{instancePath:instancePath+"/scope/namespace",schemaPath:"#/properties/scope/properties/namespace/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
}
}
else {
validate35.errors = [{instancePath:instancePath+"/scope",schemaPath:"#/properties/scope/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.principal !== undefined){
let data6 = data.principal;
const _errs15 = errors;
if(!(((typeof data6 == "number") && (!(data6 % 1) && !isNaN(data6))) && (isFinite(data6)))){
validate35.errors = [{instancePath:instancePath+"/principal",schemaPath:"#/properties/principal/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs15){
if((typeof data6 == "number") && (isFinite(data6))){
if(data6 > 9007199254740991 || isNaN(data6)){
validate35.errors = [{instancePath:instancePath+"/principal",schemaPath:"#/properties/principal/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data6 < 0 || isNaN(data6)){
validate35.errors = [{instancePath:instancePath+"/principal",schemaPath:"#/properties/principal/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid0 = _errs15 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.sequence !== undefined){
let data7 = data.sequence;
const _errs17 = errors;
if(errors === _errs17){
if(typeof data7 === "string"){
if(func2(data7) > 20){
validate35.errors = [{instancePath:instancePath+"/sequence",schemaPath:"#/properties/sequence/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern5.test(data7)){
validate35.errors = [{instancePath:instancePath+"/sequence",schemaPath:"#/properties/sequence/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate35.errors = [{instancePath:instancePath+"/sequence",schemaPath:"#/properties/sequence/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs17 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.command !== undefined){
let data8 = data.command;
const _errs19 = errors;
const _errs20 = errors;
let valid2 = false;
let passing0 = null;
const _errs21 = errors;
if(errors === _errs21){
if(data8 && typeof data8 == "object" && !Array.isArray(data8)){
let missing2;
if((data8.initialize === undefined) && (missing2 = "initialize")){
const err0 = {instancePath:instancePath+"/command",schemaPath:"#/properties/command/oneOf/0/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
}
else {
const _errs23 = errors;
for(const key2 in data8){
if(!(key2 === "initialize")){
const err1 = {instancePath:instancePath+"/command",schemaPath:"#/properties/command/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(_errs23 === errors){
if(data8.initialize !== undefined){
let data9 = data8.initialize;
const _errs24 = errors;
if(errors === _errs24){
if(data9 && typeof data9 == "object" && !Array.isArray(data9)){
if(Object.keys(data9).length > 0){
const err2 = {instancePath:instancePath+"/command/initialize",schemaPath:"#/properties/command/oneOf/0/properties/initialize/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
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
const err3 = {instancePath:instancePath+"/command/initialize",schemaPath:"#/properties/command/oneOf/0/properties/initialize/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err4 = {instancePath:instancePath+"/command",schemaPath:"#/properties/command/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
}
}
var _valid0 = _errs21 === errors;
if(_valid0){
valid2 = true;
passing0 = 0;
var props0 = true;
}
const _errs26 = errors;
if(errors === _errs26){
if(data8 && typeof data8 == "object" && !Array.isArray(data8)){
let missing3;
if((data8.policy === undefined) && (missing3 = "policy")){
const err5 = {instancePath:instancePath+"/command",schemaPath:"#/properties/command/oneOf/1/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
if(vErrors === null){
vErrors = [err5];
}
else {
vErrors.push(err5);
}
errors++;
}
else {
const _errs28 = errors;
for(const key3 in data8){
if(!(key3 === "policy")){
const err6 = {instancePath:instancePath+"/command",schemaPath:"#/properties/command/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(_errs28 === errors){
if(data8.policy !== undefined){
let data10 = data8.policy;
const _errs29 = errors;
if(errors === _errs29){
if(data10 && typeof data10 == "object" && !Array.isArray(data10)){
let missing4;
if((((data10.principal === undefined) && (missing4 = "principal")) || ((data10.expected === undefined) && (missing4 = "expected"))) || ((data10.next === undefined) && (missing4 = "next"))){
const err7 = {instancePath:instancePath+"/command/policy",schemaPath:"#/properties/command/oneOf/1/properties/policy/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
if(vErrors === null){
vErrors = [err7];
}
else {
vErrors.push(err7);
}
errors++;
}
else {
const _errs31 = errors;
for(const key4 in data10){
if(!(((key4 === "principal") || (key4 === "expected")) || (key4 === "next"))){
const err8 = {instancePath:instancePath+"/command/policy",schemaPath:"#/properties/command/oneOf/1/properties/policy/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(_errs31 === errors){
if(data10.principal !== undefined){
let data11 = data10.principal;
const _errs32 = errors;
if(!(((typeof data11 == "number") && (!(data11 % 1) && !isNaN(data11))) && (isFinite(data11)))){
const err9 = {instancePath:instancePath+"/command/policy/principal",schemaPath:"#/properties/command/oneOf/1/properties/policy/properties/principal/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
}
if(errors === _errs32){
if((typeof data11 == "number") && (isFinite(data11))){
if(data11 > 9007199254740991 || isNaN(data11)){
const err10 = {instancePath:instancePath+"/command/policy/principal",schemaPath:"#/properties/command/oneOf/1/properties/policy/properties/principal/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
}
else {
if(data11 < 0 || isNaN(data11)){
const err11 = {instancePath:instancePath+"/command/policy/principal",schemaPath:"#/properties/command/oneOf/1/properties/policy/properties/principal/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid5 = _errs32 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data10.expected !== undefined){
let data12 = data10.expected;
const _errs34 = errors;
if(errors === _errs34){
if(typeof data12 === "string"){
if(func2(data12) > 20){
const err12 = {instancePath:instancePath+"/command/policy/expected",schemaPath:"#/properties/command/oneOf/1/properties/policy/properties/expected/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
}
else {
if(!pattern5.test(data12)){
const err13 = {instancePath:instancePath+"/command/policy/expected",schemaPath:"#/properties/command/oneOf/1/properties/policy/properties/expected/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err14 = {instancePath:instancePath+"/command/policy/expected",schemaPath:"#/properties/command/oneOf/1/properties/policy/properties/expected/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err14];
}
else {
vErrors.push(err14);
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
if(data10.next !== undefined){
let data13 = data10.next;
const _errs36 = errors;
if(errors === _errs36){
if(data13 && typeof data13 == "object" && !Array.isArray(data13)){
let missing5;
if(((data13.revision === undefined) && (missing5 = "revision")) || ((data13.publish === undefined) && (missing5 = "publish"))){
const err15 = {instancePath:instancePath+"/command/policy/next",schemaPath:"#/properties/command/oneOf/1/properties/policy/properties/next/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
}
else {
const _errs38 = errors;
for(const key5 in data13){
if(!((key5 === "revision") || (key5 === "publish"))){
const err16 = {instancePath:instancePath+"/command/policy/next",schemaPath:"#/properties/command/oneOf/1/properties/policy/properties/next/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(_errs38 === errors){
if(data13.revision !== undefined){
let data14 = data13.revision;
const _errs39 = errors;
if(errors === _errs39){
if(typeof data14 === "string"){
if(func2(data14) > 20){
const err17 = {instancePath:instancePath+"/command/policy/next/revision",schemaPath:"#/properties/command/oneOf/1/properties/policy/properties/next/properties/revision/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err17];
}
else {
vErrors.push(err17);
}
errors++;
}
else {
if(!pattern5.test(data14)){
const err18 = {instancePath:instancePath+"/command/policy/next/revision",schemaPath:"#/properties/command/oneOf/1/properties/policy/properties/next/properties/revision/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
}
}
}
else {
const err19 = {instancePath:instancePath+"/command/policy/next/revision",schemaPath:"#/properties/command/oneOf/1/properties/policy/properties/next/properties/revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
}
}
var valid6 = _errs39 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data13.publish !== undefined){
const _errs41 = errors;
if(typeof data13.publish !== "boolean"){
const err20 = {instancePath:instancePath+"/command/policy/next/publish",schemaPath:"#/properties/command/oneOf/1/properties/policy/properties/next/properties/publish/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err20];
}
else {
vErrors.push(err20);
}
errors++;
}
var valid6 = _errs41 === errors;
}
else {
var valid6 = true;
}
}
}
}
}
else {
const err21 = {instancePath:instancePath+"/command/policy/next",schemaPath:"#/properties/command/oneOf/1/properties/policy/properties/next/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
}
errors++;
}
}
var valid5 = _errs36 === errors;
}
else {
var valid5 = true;
}
}
}
}
}
}
else {
const err22 = {instancePath:instancePath+"/command/policy",schemaPath:"#/properties/command/oneOf/1/properties/policy/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
}
else {
const err23 = {instancePath:instancePath+"/command",schemaPath:"#/properties/command/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err23];
}
else {
vErrors.push(err23);
}
errors++;
}
}
var _valid0 = _errs26 === errors;
if(_valid0 && valid2){
valid2 = false;
passing0 = [passing0, 1];
}
else {
if(_valid0){
valid2 = true;
passing0 = 1;
if(props0 !== true){
props0 = true;
}
}
const _errs43 = errors;
if(errors === _errs43){
if(data8 && typeof data8 == "object" && !Array.isArray(data8)){
let missing6;
if((data8.begin === undefined) && (missing6 = "begin")){
const err24 = {instancePath:instancePath+"/command",schemaPath:"#/properties/command/oneOf/2/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
}
errors++;
}
else {
const _errs45 = errors;
for(const key6 in data8){
if(!(key6 === "begin")){
const err25 = {instancePath:instancePath+"/command",schemaPath:"#/properties/command/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
if(_errs45 === errors){
if(data8.begin !== undefined){
let data16 = data8.begin;
const _errs46 = errors;
if(errors === _errs46){
if(data16 && typeof data16 == "object" && !Array.isArray(data16)){
let missing7;
if(((((((data16.operation === undefined) && (missing7 = "operation")) || ((data16.record === undefined) && (missing7 = "record"))) || ((data16.expected === undefined) && (missing7 = "expected"))) || ((data16.expected_digest === undefined) && (missing7 = "expected_digest"))) || ((data16.revision === undefined) && (missing7 = "revision"))) || ((data16.spec === undefined) && (missing7 = "spec"))){
const err26 = {instancePath:instancePath+"/command/begin",schemaPath:"#/properties/command/oneOf/2/properties/begin/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
if(vErrors === null){
vErrors = [err26];
}
else {
vErrors.push(err26);
}
errors++;
}
else {
const _errs48 = errors;
for(const key7 in data16){
if(!((((((key7 === "operation") || (key7 === "record")) || (key7 === "expected")) || (key7 === "expected_digest")) || (key7 === "revision")) || (key7 === "spec"))){
const err27 = {instancePath:instancePath+"/command/begin",schemaPath:"#/properties/command/oneOf/2/properties/begin/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err27];
}
else {
vErrors.push(err27);
}
errors++;
break;
}
}
if(_errs48 === errors){
if(data16.operation !== undefined){
let data17 = data16.operation;
const _errs49 = errors;
if(errors === _errs49){
if(typeof data17 === "string"){
if(func2(data17) > 20){
const err28 = {instancePath:instancePath+"/command/begin/operation",schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/operation/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err28];
}
else {
vErrors.push(err28);
}
errors++;
}
else {
if(!pattern5.test(data17)){
const err29 = {instancePath:instancePath+"/command/begin/operation",schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/operation/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err30 = {instancePath:instancePath+"/command/begin/operation",schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/operation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
}
errors++;
}
}
var valid8 = _errs49 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data16.record !== undefined){
let data18 = data16.record;
const _errs51 = errors;
if(errors === _errs51){
if(typeof data18 === "string"){
if(func2(data18) > 20){
const err31 = {instancePath:instancePath+"/command/begin/record",schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/record/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err31];
}
else {
vErrors.push(err31);
}
errors++;
}
else {
if(!pattern5.test(data18)){
const err32 = {instancePath:instancePath+"/command/begin/record",schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/record/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err33 = {instancePath:instancePath+"/command/begin/record",schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/record/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
}
var valid8 = _errs51 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data16.expected !== undefined){
let data19 = data16.expected;
const _errs53 = errors;
if(errors === _errs53){
if(typeof data19 === "string"){
if(func2(data19) > 20){
const err34 = {instancePath:instancePath+"/command/begin/expected",schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/expected/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err34];
}
else {
vErrors.push(err34);
}
errors++;
}
else {
if(!pattern5.test(data19)){
const err35 = {instancePath:instancePath+"/command/begin/expected",schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/expected/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err36 = {instancePath:instancePath+"/command/begin/expected",schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/expected/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
}
}
var valid8 = _errs53 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data16.expected_digest !== undefined){
let data20 = data16.expected_digest;
const _errs55 = errors;
if(errors === _errs55){
if(Array.isArray(data20)){
if(data20.length > 32){
const err37 = {instancePath:instancePath+"/command/begin/expected_digest",schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/expected_digest/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err37];
}
else {
vErrors.push(err37);
}
errors++;
}
else {
if(data20.length < 32){
const err38 = {instancePath:instancePath+"/command/begin/expected_digest",schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/expected_digest/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err38];
}
else {
vErrors.push(err38);
}
errors++;
}
else {
var valid9 = true;
const len0 = data20.length;
for(let i0=0; i0<len0; i0++){
let data21 = data20[i0];
const _errs57 = errors;
if(!(((typeof data21 == "number") && (!(data21 % 1) && !isNaN(data21))) && (isFinite(data21)))){
const err39 = {instancePath:instancePath+"/command/begin/expected_digest/" + i0,schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/expected_digest/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err39];
}
else {
vErrors.push(err39);
}
errors++;
}
if(errors === _errs57){
if((typeof data21 == "number") && (isFinite(data21))){
if(data21 > 255 || isNaN(data21)){
const err40 = {instancePath:instancePath+"/command/begin/expected_digest/" + i0,schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/expected_digest/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err40];
}
else {
vErrors.push(err40);
}
errors++;
}
else {
if(data21 < 0 || isNaN(data21)){
const err41 = {instancePath:instancePath+"/command/begin/expected_digest/" + i0,schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/expected_digest/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err41];
}
else {
vErrors.push(err41);
}
errors++;
}
}
}
}
var valid9 = _errs57 === errors;
if(!valid9){
break;
}
}
}
}
}
else {
const err42 = {instancePath:instancePath+"/command/begin/expected_digest",schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/expected_digest/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err42];
}
else {
vErrors.push(err42);
}
errors++;
}
}
var valid8 = _errs55 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data16.revision !== undefined){
let data22 = data16.revision;
const _errs59 = errors;
if(errors === _errs59){
if(typeof data22 === "string"){
if(func2(data22) > 20){
const err43 = {instancePath:instancePath+"/command/begin/revision",schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/revision/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err43];
}
else {
vErrors.push(err43);
}
errors++;
}
else {
if(!pattern5.test(data22)){
const err44 = {instancePath:instancePath+"/command/begin/revision",schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/revision/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
const err45 = {instancePath:instancePath+"/command/begin/revision",schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err45];
}
else {
vErrors.push(err45);
}
errors++;
}
}
var valid8 = _errs59 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data16.spec !== undefined){
let data23 = data16.spec;
const _errs61 = errors;
if(errors === _errs61){
if(data23 && typeof data23 == "object" && !Array.isArray(data23)){
let missing8;
if((((data23.format === undefined) && (missing8 = "format")) || ((data23.length === undefined) && (missing8 = "length"))) || ((data23.digest === undefined) && (missing8 = "digest"))){
const err46 = {instancePath:instancePath+"/command/begin/spec",schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/spec/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
if(vErrors === null){
vErrors = [err46];
}
else {
vErrors.push(err46);
}
errors++;
}
else {
const _errs63 = errors;
for(const key8 in data23){
if(!(((key8 === "format") || (key8 === "length")) || (key8 === "digest"))){
const err47 = {instancePath:instancePath+"/command/begin/spec",schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/spec/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
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
if(_errs63 === errors){
if(data23.format !== undefined){
let data24 = data23.format;
const _errs64 = errors;
if(!(((typeof data24 == "number") && (!(data24 % 1) && !isNaN(data24))) && (isFinite(data24)))){
const err48 = {instancePath:instancePath+"/command/begin/spec/format",schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/spec/properties/format/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err48];
}
else {
vErrors.push(err48);
}
errors++;
}
if(errors === _errs64){
if((typeof data24 == "number") && (isFinite(data24))){
if(data24 > 4294967295 || isNaN(data24)){
const err49 = {instancePath:instancePath+"/command/begin/spec/format",schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/spec/properties/format/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err49];
}
else {
vErrors.push(err49);
}
errors++;
}
else {
if(data24 < 0 || isNaN(data24)){
const err50 = {instancePath:instancePath+"/command/begin/spec/format",schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/spec/properties/format/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
}
var valid10 = _errs64 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data23.length !== undefined){
let data25 = data23.length;
const _errs66 = errors;
if(!(((typeof data25 == "number") && (!(data25 % 1) && !isNaN(data25))) && (isFinite(data25)))){
const err51 = {instancePath:instancePath+"/command/begin/spec/length",schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/spec/properties/length/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err51];
}
else {
vErrors.push(err51);
}
errors++;
}
if(errors === _errs66){
if((typeof data25 == "number") && (isFinite(data25))){
if(data25 > 4294967295 || isNaN(data25)){
const err52 = {instancePath:instancePath+"/command/begin/spec/length",schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/spec/properties/length/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err52];
}
else {
vErrors.push(err52);
}
errors++;
}
else {
if(data25 < 0 || isNaN(data25)){
const err53 = {instancePath:instancePath+"/command/begin/spec/length",schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/spec/properties/length/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid10 = _errs66 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data23.digest !== undefined){
let data26 = data23.digest;
const _errs68 = errors;
if(errors === _errs68){
if(Array.isArray(data26)){
if(data26.length > 32){
const err54 = {instancePath:instancePath+"/command/begin/spec/digest",schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/spec/properties/digest/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err54];
}
else {
vErrors.push(err54);
}
errors++;
}
else {
if(data26.length < 32){
const err55 = {instancePath:instancePath+"/command/begin/spec/digest",schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/spec/properties/digest/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err55];
}
else {
vErrors.push(err55);
}
errors++;
}
else {
var valid11 = true;
const len1 = data26.length;
for(let i1=0; i1<len1; i1++){
let data27 = data26[i1];
const _errs70 = errors;
if(!(((typeof data27 == "number") && (!(data27 % 1) && !isNaN(data27))) && (isFinite(data27)))){
const err56 = {instancePath:instancePath+"/command/begin/spec/digest/" + i1,schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/spec/properties/digest/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err56];
}
else {
vErrors.push(err56);
}
errors++;
}
if(errors === _errs70){
if((typeof data27 == "number") && (isFinite(data27))){
if(data27 > 255 || isNaN(data27)){
const err57 = {instancePath:instancePath+"/command/begin/spec/digest/" + i1,schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/spec/properties/digest/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err57];
}
else {
vErrors.push(err57);
}
errors++;
}
else {
if(data27 < 0 || isNaN(data27)){
const err58 = {instancePath:instancePath+"/command/begin/spec/digest/" + i1,schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/spec/properties/digest/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid11 = _errs70 === errors;
if(!valid11){
break;
}
}
}
}
}
else {
const err59 = {instancePath:instancePath+"/command/begin/spec/digest",schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/spec/properties/digest/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err59];
}
else {
vErrors.push(err59);
}
errors++;
}
}
var valid10 = _errs68 === errors;
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
const err60 = {instancePath:instancePath+"/command/begin/spec",schemaPath:"#/properties/command/oneOf/2/properties/begin/properties/spec/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err60];
}
else {
vErrors.push(err60);
}
errors++;
}
}
var valid8 = _errs61 === errors;
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
else {
const err61 = {instancePath:instancePath+"/command/begin",schemaPath:"#/properties/command/oneOf/2/properties/begin/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err61];
}
else {
vErrors.push(err61);
}
errors++;
}
}
}
}
}
}
else {
const err62 = {instancePath:instancePath+"/command",schemaPath:"#/properties/command/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err62];
}
else {
vErrors.push(err62);
}
errors++;
}
}
var _valid0 = _errs43 === errors;
if(_valid0 && valid2){
valid2 = false;
passing0 = [passing0, 2];
}
else {
if(_valid0){
valid2 = true;
passing0 = 2;
if(props0 !== true){
props0 = true;
}
}
const _errs72 = errors;
if(errors === _errs72){
if(data8 && typeof data8 == "object" && !Array.isArray(data8)){
let missing9;
if((data8.part === undefined) && (missing9 = "part")){
const err63 = {instancePath:instancePath+"/command",schemaPath:"#/properties/command/oneOf/3/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
if(vErrors === null){
vErrors = [err63];
}
else {
vErrors.push(err63);
}
errors++;
}
else {
const _errs74 = errors;
for(const key9 in data8){
if(!(key9 === "part")){
const err64 = {instancePath:instancePath+"/command",schemaPath:"#/properties/command/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
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
if(_errs74 === errors){
if(data8.part !== undefined){
let data28 = data8.part;
const _errs75 = errors;
if(errors === _errs75){
if(data28 && typeof data28 == "object" && !Array.isArray(data28)){
let missing10;
if(((((data28.operation === undefined) && (missing10 = "operation")) || ((data28.ordinal === undefined) && (missing10 = "ordinal"))) || ((data28.second === undefined) && (missing10 = "second"))) || ((data28.bytes === undefined) && (missing10 = "bytes"))){
const err65 = {instancePath:instancePath+"/command/part",schemaPath:"#/properties/command/oneOf/3/properties/part/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"};
if(vErrors === null){
vErrors = [err65];
}
else {
vErrors.push(err65);
}
errors++;
}
else {
const _errs77 = errors;
for(const key10 in data28){
if(!((((key10 === "operation") || (key10 === "ordinal")) || (key10 === "second")) || (key10 === "bytes"))){
const err66 = {instancePath:instancePath+"/command/part",schemaPath:"#/properties/command/oneOf/3/properties/part/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"};
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
if(_errs77 === errors){
if(data28.operation !== undefined){
let data29 = data28.operation;
const _errs78 = errors;
if(errors === _errs78){
if(typeof data29 === "string"){
if(func2(data29) > 20){
const err67 = {instancePath:instancePath+"/command/part/operation",schemaPath:"#/properties/command/oneOf/3/properties/part/properties/operation/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err67];
}
else {
vErrors.push(err67);
}
errors++;
}
else {
if(!pattern5.test(data29)){
const err68 = {instancePath:instancePath+"/command/part/operation",schemaPath:"#/properties/command/oneOf/3/properties/part/properties/operation/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err69 = {instancePath:instancePath+"/command/part/operation",schemaPath:"#/properties/command/oneOf/3/properties/part/properties/operation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err69];
}
else {
vErrors.push(err69);
}
errors++;
}
}
var valid13 = _errs78 === errors;
}
else {
var valid13 = true;
}
if(valid13){
if(data28.ordinal !== undefined){
let data30 = data28.ordinal;
const _errs80 = errors;
if(!(((typeof data30 == "number") && (!(data30 % 1) && !isNaN(data30))) && (isFinite(data30)))){
const err70 = {instancePath:instancePath+"/command/part/ordinal",schemaPath:"#/properties/command/oneOf/3/properties/part/properties/ordinal/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err70];
}
else {
vErrors.push(err70);
}
errors++;
}
if(errors === _errs80){
if((typeof data30 == "number") && (isFinite(data30))){
if(data30 > 4294967295 || isNaN(data30)){
const err71 = {instancePath:instancePath+"/command/part/ordinal",schemaPath:"#/properties/command/oneOf/3/properties/part/properties/ordinal/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err71];
}
else {
vErrors.push(err71);
}
errors++;
}
else {
if(data30 < 0 || isNaN(data30)){
const err72 = {instancePath:instancePath+"/command/part/ordinal",schemaPath:"#/properties/command/oneOf/3/properties/part/properties/ordinal/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err72];
}
else {
vErrors.push(err72);
}
errors++;
}
}
}
}
var valid13 = _errs80 === errors;
}
else {
var valid13 = true;
}
if(valid13){
if(data28.second !== undefined){
const _errs82 = errors;
if(typeof data28.second !== "boolean"){
const err73 = {instancePath:instancePath+"/command/part/second",schemaPath:"#/properties/command/oneOf/3/properties/part/properties/second/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err73];
}
else {
vErrors.push(err73);
}
errors++;
}
var valid13 = _errs82 === errors;
}
else {
var valid13 = true;
}
if(valid13){
if(data28.bytes !== undefined){
let data32 = data28.bytes;
const _errs84 = errors;
if(errors === _errs84){
if(typeof data32 === "string"){
if(func2(data32) > 256){
const err74 = {instancePath:instancePath+"/command/part/bytes",schemaPath:"#/properties/command/oneOf/3/properties/part/properties/bytes/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err74];
}
else {
vErrors.push(err74);
}
errors++;
}
else {
if(!pattern53.test(data32)){
const err75 = {instancePath:instancePath+"/command/part/bytes",schemaPath:"#/properties/command/oneOf/3/properties/part/properties/bytes/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})+$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})+$"+"\""};
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
else {
const err76 = {instancePath:instancePath+"/command/part/bytes",schemaPath:"#/properties/command/oneOf/3/properties/part/properties/bytes/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err76];
}
else {
vErrors.push(err76);
}
errors++;
}
}
var valid13 = _errs84 === errors;
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
const err77 = {instancePath:instancePath+"/command/part",schemaPath:"#/properties/command/oneOf/3/properties/part/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err77];
}
else {
vErrors.push(err77);
}
errors++;
}
}
}
}
}
}
else {
const err78 = {instancePath:instancePath+"/command",schemaPath:"#/properties/command/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err78];
}
else {
vErrors.push(err78);
}
errors++;
}
}
var _valid0 = _errs72 === errors;
if(_valid0 && valid2){
valid2 = false;
passing0 = [passing0, 3];
}
else {
if(_valid0){
valid2 = true;
passing0 = 3;
if(props0 !== true){
props0 = true;
}
}
const _errs86 = errors;
if(errors === _errs86){
if(data8 && typeof data8 == "object" && !Array.isArray(data8)){
let missing11;
if((data8.publish === undefined) && (missing11 = "publish")){
const err79 = {instancePath:instancePath+"/command",schemaPath:"#/properties/command/oneOf/4/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
if(vErrors === null){
vErrors = [err79];
}
else {
vErrors.push(err79);
}
errors++;
}
else {
const _errs88 = errors;
for(const key11 in data8){
if(!(key11 === "publish")){
const err80 = {instancePath:instancePath+"/command",schemaPath:"#/properties/command/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
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
if(_errs88 === errors){
if(data8.publish !== undefined){
let data33 = data8.publish;
const _errs89 = errors;
if(errors === _errs89){
if(typeof data33 === "string"){
if(func2(data33) > 20){
const err81 = {instancePath:instancePath+"/command/publish",schemaPath:"#/properties/command/oneOf/4/properties/publish/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err81];
}
else {
vErrors.push(err81);
}
errors++;
}
else {
if(!pattern5.test(data33)){
const err82 = {instancePath:instancePath+"/command/publish",schemaPath:"#/properties/command/oneOf/4/properties/publish/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err83 = {instancePath:instancePath+"/command/publish",schemaPath:"#/properties/command/oneOf/4/properties/publish/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err83];
}
else {
vErrors.push(err83);
}
errors++;
}
}
}
}
}
}
else {
const err84 = {instancePath:instancePath+"/command",schemaPath:"#/properties/command/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err84];
}
else {
vErrors.push(err84);
}
errors++;
}
}
var _valid0 = _errs86 === errors;
if(_valid0 && valid2){
valid2 = false;
passing0 = [passing0, 4];
}
else {
if(_valid0){
valid2 = true;
passing0 = 4;
if(props0 !== true){
props0 = true;
}
}
const _errs91 = errors;
if(errors === _errs91){
if(data8 && typeof data8 == "object" && !Array.isArray(data8)){
let missing12;
if((data8.abandon === undefined) && (missing12 = "abandon")){
const err85 = {instancePath:instancePath+"/command",schemaPath:"#/properties/command/oneOf/5/required",keyword:"required",params:{missingProperty: missing12},message:"must have required property '"+missing12+"'"};
if(vErrors === null){
vErrors = [err85];
}
else {
vErrors.push(err85);
}
errors++;
}
else {
const _errs93 = errors;
for(const key12 in data8){
if(!(key12 === "abandon")){
const err86 = {instancePath:instancePath+"/command",schemaPath:"#/properties/command/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key12},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err86];
}
else {
vErrors.push(err86);
}
errors++;
break;
}
}
if(_errs93 === errors){
if(data8.abandon !== undefined){
let data34 = data8.abandon;
const _errs94 = errors;
if(errors === _errs94){
if(typeof data34 === "string"){
if(func2(data34) > 20){
const err87 = {instancePath:instancePath+"/command/abandon",schemaPath:"#/properties/command/oneOf/5/properties/abandon/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err87];
}
else {
vErrors.push(err87);
}
errors++;
}
else {
if(!pattern5.test(data34)){
const err88 = {instancePath:instancePath+"/command/abandon",schemaPath:"#/properties/command/oneOf/5/properties/abandon/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err89 = {instancePath:instancePath+"/command/abandon",schemaPath:"#/properties/command/oneOf/5/properties/abandon/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err89];
}
else {
vErrors.push(err89);
}
errors++;
}
}
}
}
}
}
else {
const err90 = {instancePath:instancePath+"/command",schemaPath:"#/properties/command/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err90];
}
else {
vErrors.push(err90);
}
errors++;
}
}
var _valid0 = _errs91 === errors;
if(_valid0 && valid2){
valid2 = false;
passing0 = [passing0, 5];
}
else {
if(_valid0){
valid2 = true;
passing0 = 5;
if(props0 !== true){
props0 = true;
}
}
const _errs96 = errors;
if(errors === _errs96){
if(data8 && typeof data8 == "object" && !Array.isArray(data8)){
let missing13;
if((data8.collect === undefined) && (missing13 = "collect")){
const err91 = {instancePath:instancePath+"/command",schemaPath:"#/properties/command/oneOf/6/required",keyword:"required",params:{missingProperty: missing13},message:"must have required property '"+missing13+"'"};
if(vErrors === null){
vErrors = [err91];
}
else {
vErrors.push(err91);
}
errors++;
}
else {
const _errs98 = errors;
for(const key13 in data8){
if(!(key13 === "collect")){
const err92 = {instancePath:instancePath+"/command",schemaPath:"#/properties/command/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key13},message:"must NOT have additional properties"};
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
if(_errs98 === errors){
if(data8.collect !== undefined){
let data35 = data8.collect;
const _errs99 = errors;
if(errors === _errs99){
if(typeof data35 === "string"){
if(func2(data35) > 20){
const err93 = {instancePath:instancePath+"/command/collect",schemaPath:"#/properties/command/oneOf/6/properties/collect/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err93];
}
else {
vErrors.push(err93);
}
errors++;
}
else {
if(!pattern5.test(data35)){
const err94 = {instancePath:instancePath+"/command/collect",schemaPath:"#/properties/command/oneOf/6/properties/collect/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err95 = {instancePath:instancePath+"/command/collect",schemaPath:"#/properties/command/oneOf/6/properties/collect/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
const err96 = {instancePath:instancePath+"/command",schemaPath:"#/properties/command/oneOf/6/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err96];
}
else {
vErrors.push(err96);
}
errors++;
}
}
var _valid0 = _errs96 === errors;
if(_valid0 && valid2){
valid2 = false;
passing0 = [passing0, 6];
}
else {
if(_valid0){
valid2 = true;
passing0 = 6;
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
if(!valid2){
const err97 = {instancePath:instancePath+"/command",schemaPath:"#/properties/command/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err97];
}
else {
vErrors.push(err97);
}
errors++;
validate35.errors = vErrors;
return false;
}
else {
errors = _errs20;
if(vErrors !== null){
if(_errs20){
vErrors.length = _errs20;
}
else {
vErrors = null;
}
}
}
var valid0 = _errs19 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.digest !== undefined){
let data36 = data.digest;
const _errs101 = errors;
if(errors === _errs101){
if(Array.isArray(data36)){
if(data36.length > 32){
validate35.errors = [{instancePath:instancePath+"/digest",schemaPath:"#/properties/digest/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"}];
return false;
}
else {
if(data36.length < 32){
validate35.errors = [{instancePath:instancePath+"/digest",schemaPath:"#/properties/digest/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"}];
return false;
}
else {
var valid17 = true;
const len2 = data36.length;
for(let i2=0; i2<len2; i2++){
let data37 = data36[i2];
const _errs103 = errors;
if(!(((typeof data37 == "number") && (!(data37 % 1) && !isNaN(data37))) && (isFinite(data37)))){
validate35.errors = [{instancePath:instancePath+"/digest/" + i2,schemaPath:"#/properties/digest/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs103){
if((typeof data37 == "number") && (isFinite(data37))){
if(data37 > 255 || isNaN(data37)){
validate35.errors = [{instancePath:instancePath+"/digest/" + i2,schemaPath:"#/properties/digest/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"}];
return false;
}
else {
if(data37 < 0 || isNaN(data37)){
validate35.errors = [{instancePath:instancePath+"/digest/" + i2,schemaPath:"#/properties/digest/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid17 = _errs103 === errors;
if(!valid17){
break;
}
}
}
}
}
else {
validate35.errors = [{instancePath:instancePath+"/digest",schemaPath:"#/properties/digest/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid0 = _errs101 === errors;
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
validate35.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate35.errors = vErrors;
return errors === 0;
}
validate35.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Signed = validate36;
const schema54 = {"type":"object","additionalProperties":false,"properties":{"prepared":{"type":"object","additionalProperties":false,"properties":{"scope":{"type":"object","additionalProperties":false,"properties":{"realm":{"type":"integer","minimum":0,"maximum":9007199254740991},"application":{"type":"integer","minimum":0,"maximum":9007199254740991},"pid":{"type":"integer","minimum":0,"maximum":9007199254740991},"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"namespace":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20}},"required":["realm","application","pid","resource","namespace"]},"principal":{"type":"integer","minimum":0,"maximum":9007199254740991},"sequence":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"command":{"oneOf":[{"type":"object","additionalProperties":false,"required":["initialize"],"properties":{"initialize":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["policy"],"properties":{"policy":{"type":"object","additionalProperties":false,"properties":{"principal":{"type":"integer","minimum":0,"maximum":9007199254740991},"expected":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"next":{"type":"object","additionalProperties":false,"properties":{"revision":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"publish":{"type":"boolean"}},"required":["revision","publish"]}},"required":["principal","expected","next"]}}},{"type":"object","additionalProperties":false,"required":["begin"],"properties":{"begin":{"type":"object","additionalProperties":false,"properties":{"operation":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"record":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"expected":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"expected_digest":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"revision":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"spec":{"type":"object","additionalProperties":false,"properties":{"format":{"type":"integer","minimum":0,"maximum":4294967295},"length":{"type":"integer","minimum":0,"maximum":4294967295},"digest":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}}},"required":["format","length","digest"]}},"required":["operation","record","expected","expected_digest","revision","spec"]}}},{"type":"object","additionalProperties":false,"required":["part"],"properties":{"part":{"type":"object","additionalProperties":false,"properties":{"operation":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"ordinal":{"type":"integer","minimum":0,"maximum":4294967295},"second":{"type":"boolean"},"bytes":{"type":"string","pattern":"^(?:[0-9a-f]{2})+$","maxLength":256}},"required":["operation","ordinal","second","bytes"]}}},{"type":"object","additionalProperties":false,"required":["publish"],"properties":{"publish":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20}}},{"type":"object","additionalProperties":false,"required":["abandon"],"properties":{"abandon":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20}}},{"type":"object","additionalProperties":false,"required":["collect"],"properties":{"collect":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20}}}]},"digest":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}}},"required":["scope","principal","sequence","command","digest"]},"signature":{"type":"array","minItems":64,"maxItems":64,"items":{"type":"integer","minimum":0,"maximum":255}}},"required":["prepared","signature"]};

function validate36(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate36.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.prepared === undefined) && (missing0 = "prepared")) || ((data.signature === undefined) && (missing0 = "signature"))){
validate36.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "prepared") || (key0 === "signature"))){
validate36.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.prepared !== undefined){
let data0 = data.prepared;
const _errs2 = errors;
if(errors === _errs2){
if(data0 && typeof data0 == "object" && !Array.isArray(data0)){
let missing1;
if((((((data0.scope === undefined) && (missing1 = "scope")) || ((data0.principal === undefined) && (missing1 = "principal"))) || ((data0.sequence === undefined) && (missing1 = "sequence"))) || ((data0.command === undefined) && (missing1 = "command"))) || ((data0.digest === undefined) && (missing1 = "digest"))){
validate36.errors = [{instancePath:instancePath+"/prepared",schemaPath:"#/properties/prepared/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"}];
return false;
}
else {
const _errs4 = errors;
for(const key1 in data0){
if(!(((((key1 === "scope") || (key1 === "principal")) || (key1 === "sequence")) || (key1 === "command")) || (key1 === "digest"))){
validate36.errors = [{instancePath:instancePath+"/prepared",schemaPath:"#/properties/prepared/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs4 === errors){
if(data0.scope !== undefined){
let data1 = data0.scope;
const _errs5 = errors;
if(errors === _errs5){
if(data1 && typeof data1 == "object" && !Array.isArray(data1)){
let missing2;
if((((((data1.realm === undefined) && (missing2 = "realm")) || ((data1.application === undefined) && (missing2 = "application"))) || ((data1.pid === undefined) && (missing2 = "pid"))) || ((data1.resource === undefined) && (missing2 = "resource"))) || ((data1.namespace === undefined) && (missing2 = "namespace"))){
validate36.errors = [{instancePath:instancePath+"/prepared/scope",schemaPath:"#/properties/prepared/properties/scope/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"}];
return false;
}
else {
const _errs7 = errors;
for(const key2 in data1){
if(!(((((key2 === "realm") || (key2 === "application")) || (key2 === "pid")) || (key2 === "resource")) || (key2 === "namespace"))){
validate36.errors = [{instancePath:instancePath+"/prepared/scope",schemaPath:"#/properties/prepared/properties/scope/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs7 === errors){
if(data1.realm !== undefined){
let data2 = data1.realm;
const _errs8 = errors;
if(!(((typeof data2 == "number") && (!(data2 % 1) && !isNaN(data2))) && (isFinite(data2)))){
validate36.errors = [{instancePath:instancePath+"/prepared/scope/realm",schemaPath:"#/properties/prepared/properties/scope/properties/realm/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs8){
if((typeof data2 == "number") && (isFinite(data2))){
if(data2 > 9007199254740991 || isNaN(data2)){
validate36.errors = [{instancePath:instancePath+"/prepared/scope/realm",schemaPath:"#/properties/prepared/properties/scope/properties/realm/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data2 < 0 || isNaN(data2)){
validate36.errors = [{instancePath:instancePath+"/prepared/scope/realm",schemaPath:"#/properties/prepared/properties/scope/properties/realm/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid2 = _errs8 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data1.application !== undefined){
let data3 = data1.application;
const _errs10 = errors;
if(!(((typeof data3 == "number") && (!(data3 % 1) && !isNaN(data3))) && (isFinite(data3)))){
validate36.errors = [{instancePath:instancePath+"/prepared/scope/application",schemaPath:"#/properties/prepared/properties/scope/properties/application/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs10){
if((typeof data3 == "number") && (isFinite(data3))){
if(data3 > 9007199254740991 || isNaN(data3)){
validate36.errors = [{instancePath:instancePath+"/prepared/scope/application",schemaPath:"#/properties/prepared/properties/scope/properties/application/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data3 < 0 || isNaN(data3)){
validate36.errors = [{instancePath:instancePath+"/prepared/scope/application",schemaPath:"#/properties/prepared/properties/scope/properties/application/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid2 = _errs10 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data1.pid !== undefined){
let data4 = data1.pid;
const _errs12 = errors;
if(!(((typeof data4 == "number") && (!(data4 % 1) && !isNaN(data4))) && (isFinite(data4)))){
validate36.errors = [{instancePath:instancePath+"/prepared/scope/pid",schemaPath:"#/properties/prepared/properties/scope/properties/pid/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs12){
if((typeof data4 == "number") && (isFinite(data4))){
if(data4 > 9007199254740991 || isNaN(data4)){
validate36.errors = [{instancePath:instancePath+"/prepared/scope/pid",schemaPath:"#/properties/prepared/properties/scope/properties/pid/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data4 < 0 || isNaN(data4)){
validate36.errors = [{instancePath:instancePath+"/prepared/scope/pid",schemaPath:"#/properties/prepared/properties/scope/properties/pid/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid2 = _errs12 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data1.resource !== undefined){
let data5 = data1.resource;
const _errs14 = errors;
if(!(((typeof data5 == "number") && (!(data5 % 1) && !isNaN(data5))) && (isFinite(data5)))){
validate36.errors = [{instancePath:instancePath+"/prepared/scope/resource",schemaPath:"#/properties/prepared/properties/scope/properties/resource/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs14){
if((typeof data5 == "number") && (isFinite(data5))){
if(data5 > 9007199254740991 || isNaN(data5)){
validate36.errors = [{instancePath:instancePath+"/prepared/scope/resource",schemaPath:"#/properties/prepared/properties/scope/properties/resource/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data5 < 0 || isNaN(data5)){
validate36.errors = [{instancePath:instancePath+"/prepared/scope/resource",schemaPath:"#/properties/prepared/properties/scope/properties/resource/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid2 = _errs14 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data1.namespace !== undefined){
let data6 = data1.namespace;
const _errs16 = errors;
if(errors === _errs16){
if(typeof data6 === "string"){
if(func2(data6) > 20){
validate36.errors = [{instancePath:instancePath+"/prepared/scope/namespace",schemaPath:"#/properties/prepared/properties/scope/properties/namespace/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern5.test(data6)){
validate36.errors = [{instancePath:instancePath+"/prepared/scope/namespace",schemaPath:"#/properties/prepared/properties/scope/properties/namespace/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate36.errors = [{instancePath:instancePath+"/prepared/scope/namespace",schemaPath:"#/properties/prepared/properties/scope/properties/namespace/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid2 = _errs16 === errors;
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
else {
validate36.errors = [{instancePath:instancePath+"/prepared/scope",schemaPath:"#/properties/prepared/properties/scope/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
var valid1 = _errs5 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.principal !== undefined){
let data7 = data0.principal;
const _errs18 = errors;
if(!(((typeof data7 == "number") && (!(data7 % 1) && !isNaN(data7))) && (isFinite(data7)))){
validate36.errors = [{instancePath:instancePath+"/prepared/principal",schemaPath:"#/properties/prepared/properties/principal/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs18){
if((typeof data7 == "number") && (isFinite(data7))){
if(data7 > 9007199254740991 || isNaN(data7)){
validate36.errors = [{instancePath:instancePath+"/prepared/principal",schemaPath:"#/properties/prepared/properties/principal/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data7 < 0 || isNaN(data7)){
validate36.errors = [{instancePath:instancePath+"/prepared/principal",schemaPath:"#/properties/prepared/properties/principal/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid1 = _errs18 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.sequence !== undefined){
let data8 = data0.sequence;
const _errs20 = errors;
if(errors === _errs20){
if(typeof data8 === "string"){
if(func2(data8) > 20){
validate36.errors = [{instancePath:instancePath+"/prepared/sequence",schemaPath:"#/properties/prepared/properties/sequence/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern5.test(data8)){
validate36.errors = [{instancePath:instancePath+"/prepared/sequence",schemaPath:"#/properties/prepared/properties/sequence/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate36.errors = [{instancePath:instancePath+"/prepared/sequence",schemaPath:"#/properties/prepared/properties/sequence/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid1 = _errs20 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.command !== undefined){
let data9 = data0.command;
const _errs22 = errors;
const _errs23 = errors;
let valid3 = false;
let passing0 = null;
const _errs24 = errors;
if(errors === _errs24){
if(data9 && typeof data9 == "object" && !Array.isArray(data9)){
let missing3;
if((data9.initialize === undefined) && (missing3 = "initialize")){
const err0 = {instancePath:instancePath+"/prepared/command",schemaPath:"#/properties/prepared/properties/command/oneOf/0/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
}
else {
const _errs26 = errors;
for(const key3 in data9){
if(!(key3 === "initialize")){
const err1 = {instancePath:instancePath+"/prepared/command",schemaPath:"#/properties/prepared/properties/command/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(_errs26 === errors){
if(data9.initialize !== undefined){
let data10 = data9.initialize;
const _errs27 = errors;
if(errors === _errs27){
if(data10 && typeof data10 == "object" && !Array.isArray(data10)){
if(Object.keys(data10).length > 0){
const err2 = {instancePath:instancePath+"/prepared/command/initialize",schemaPath:"#/properties/prepared/properties/command/oneOf/0/properties/initialize/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
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
const err3 = {instancePath:instancePath+"/prepared/command/initialize",schemaPath:"#/properties/prepared/properties/command/oneOf/0/properties/initialize/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err4 = {instancePath:instancePath+"/prepared/command",schemaPath:"#/properties/prepared/properties/command/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
}
}
var _valid0 = _errs24 === errors;
if(_valid0){
valid3 = true;
passing0 = 0;
var props0 = true;
}
const _errs29 = errors;
if(errors === _errs29){
if(data9 && typeof data9 == "object" && !Array.isArray(data9)){
let missing4;
if((data9.policy === undefined) && (missing4 = "policy")){
const err5 = {instancePath:instancePath+"/prepared/command",schemaPath:"#/properties/prepared/properties/command/oneOf/1/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
if(vErrors === null){
vErrors = [err5];
}
else {
vErrors.push(err5);
}
errors++;
}
else {
const _errs31 = errors;
for(const key4 in data9){
if(!(key4 === "policy")){
const err6 = {instancePath:instancePath+"/prepared/command",schemaPath:"#/properties/prepared/properties/command/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(_errs31 === errors){
if(data9.policy !== undefined){
let data11 = data9.policy;
const _errs32 = errors;
if(errors === _errs32){
if(data11 && typeof data11 == "object" && !Array.isArray(data11)){
let missing5;
if((((data11.principal === undefined) && (missing5 = "principal")) || ((data11.expected === undefined) && (missing5 = "expected"))) || ((data11.next === undefined) && (missing5 = "next"))){
const err7 = {instancePath:instancePath+"/prepared/command/policy",schemaPath:"#/properties/prepared/properties/command/oneOf/1/properties/policy/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
if(vErrors === null){
vErrors = [err7];
}
else {
vErrors.push(err7);
}
errors++;
}
else {
const _errs34 = errors;
for(const key5 in data11){
if(!(((key5 === "principal") || (key5 === "expected")) || (key5 === "next"))){
const err8 = {instancePath:instancePath+"/prepared/command/policy",schemaPath:"#/properties/prepared/properties/command/oneOf/1/properties/policy/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(_errs34 === errors){
if(data11.principal !== undefined){
let data12 = data11.principal;
const _errs35 = errors;
if(!(((typeof data12 == "number") && (!(data12 % 1) && !isNaN(data12))) && (isFinite(data12)))){
const err9 = {instancePath:instancePath+"/prepared/command/policy/principal",schemaPath:"#/properties/prepared/properties/command/oneOf/1/properties/policy/properties/principal/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
}
if(errors === _errs35){
if((typeof data12 == "number") && (isFinite(data12))){
if(data12 > 9007199254740991 || isNaN(data12)){
const err10 = {instancePath:instancePath+"/prepared/command/policy/principal",schemaPath:"#/properties/prepared/properties/command/oneOf/1/properties/policy/properties/principal/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
}
else {
if(data12 < 0 || isNaN(data12)){
const err11 = {instancePath:instancePath+"/prepared/command/policy/principal",schemaPath:"#/properties/prepared/properties/command/oneOf/1/properties/policy/properties/principal/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid6 = _errs35 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data11.expected !== undefined){
let data13 = data11.expected;
const _errs37 = errors;
if(errors === _errs37){
if(typeof data13 === "string"){
if(func2(data13) > 20){
const err12 = {instancePath:instancePath+"/prepared/command/policy/expected",schemaPath:"#/properties/prepared/properties/command/oneOf/1/properties/policy/properties/expected/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
}
else {
if(!pattern5.test(data13)){
const err13 = {instancePath:instancePath+"/prepared/command/policy/expected",schemaPath:"#/properties/prepared/properties/command/oneOf/1/properties/policy/properties/expected/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err14 = {instancePath:instancePath+"/prepared/command/policy/expected",schemaPath:"#/properties/prepared/properties/command/oneOf/1/properties/policy/properties/expected/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err14];
}
else {
vErrors.push(err14);
}
errors++;
}
}
var valid6 = _errs37 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data11.next !== undefined){
let data14 = data11.next;
const _errs39 = errors;
if(errors === _errs39){
if(data14 && typeof data14 == "object" && !Array.isArray(data14)){
let missing6;
if(((data14.revision === undefined) && (missing6 = "revision")) || ((data14.publish === undefined) && (missing6 = "publish"))){
const err15 = {instancePath:instancePath+"/prepared/command/policy/next",schemaPath:"#/properties/prepared/properties/command/oneOf/1/properties/policy/properties/next/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
}
else {
const _errs41 = errors;
for(const key6 in data14){
if(!((key6 === "revision") || (key6 === "publish"))){
const err16 = {instancePath:instancePath+"/prepared/command/policy/next",schemaPath:"#/properties/prepared/properties/command/oneOf/1/properties/policy/properties/next/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
if(_errs41 === errors){
if(data14.revision !== undefined){
let data15 = data14.revision;
const _errs42 = errors;
if(errors === _errs42){
if(typeof data15 === "string"){
if(func2(data15) > 20){
const err17 = {instancePath:instancePath+"/prepared/command/policy/next/revision",schemaPath:"#/properties/prepared/properties/command/oneOf/1/properties/policy/properties/next/properties/revision/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err17];
}
else {
vErrors.push(err17);
}
errors++;
}
else {
if(!pattern5.test(data15)){
const err18 = {instancePath:instancePath+"/prepared/command/policy/next/revision",schemaPath:"#/properties/prepared/properties/command/oneOf/1/properties/policy/properties/next/properties/revision/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
}
}
}
else {
const err19 = {instancePath:instancePath+"/prepared/command/policy/next/revision",schemaPath:"#/properties/prepared/properties/command/oneOf/1/properties/policy/properties/next/properties/revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
}
}
var valid7 = _errs42 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data14.publish !== undefined){
const _errs44 = errors;
if(typeof data14.publish !== "boolean"){
const err20 = {instancePath:instancePath+"/prepared/command/policy/next/publish",schemaPath:"#/properties/prepared/properties/command/oneOf/1/properties/policy/properties/next/properties/publish/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err20];
}
else {
vErrors.push(err20);
}
errors++;
}
var valid7 = _errs44 === errors;
}
else {
var valid7 = true;
}
}
}
}
}
else {
const err21 = {instancePath:instancePath+"/prepared/command/policy/next",schemaPath:"#/properties/prepared/properties/command/oneOf/1/properties/policy/properties/next/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
}
errors++;
}
}
var valid6 = _errs39 === errors;
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
const err22 = {instancePath:instancePath+"/prepared/command/policy",schemaPath:"#/properties/prepared/properties/command/oneOf/1/properties/policy/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
}
else {
const err23 = {instancePath:instancePath+"/prepared/command",schemaPath:"#/properties/prepared/properties/command/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if(_valid0 && valid3){
valid3 = false;
passing0 = [passing0, 1];
}
else {
if(_valid0){
valid3 = true;
passing0 = 1;
if(props0 !== true){
props0 = true;
}
}
const _errs46 = errors;
if(errors === _errs46){
if(data9 && typeof data9 == "object" && !Array.isArray(data9)){
let missing7;
if((data9.begin === undefined) && (missing7 = "begin")){
const err24 = {instancePath:instancePath+"/prepared/command",schemaPath:"#/properties/prepared/properties/command/oneOf/2/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
}
errors++;
}
else {
const _errs48 = errors;
for(const key7 in data9){
if(!(key7 === "begin")){
const err25 = {instancePath:instancePath+"/prepared/command",schemaPath:"#/properties/prepared/properties/command/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
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
if(_errs48 === errors){
if(data9.begin !== undefined){
let data17 = data9.begin;
const _errs49 = errors;
if(errors === _errs49){
if(data17 && typeof data17 == "object" && !Array.isArray(data17)){
let missing8;
if(((((((data17.operation === undefined) && (missing8 = "operation")) || ((data17.record === undefined) && (missing8 = "record"))) || ((data17.expected === undefined) && (missing8 = "expected"))) || ((data17.expected_digest === undefined) && (missing8 = "expected_digest"))) || ((data17.revision === undefined) && (missing8 = "revision"))) || ((data17.spec === undefined) && (missing8 = "spec"))){
const err26 = {instancePath:instancePath+"/prepared/command/begin",schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
if(vErrors === null){
vErrors = [err26];
}
else {
vErrors.push(err26);
}
errors++;
}
else {
const _errs51 = errors;
for(const key8 in data17){
if(!((((((key8 === "operation") || (key8 === "record")) || (key8 === "expected")) || (key8 === "expected_digest")) || (key8 === "revision")) || (key8 === "spec"))){
const err27 = {instancePath:instancePath+"/prepared/command/begin",schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err27];
}
else {
vErrors.push(err27);
}
errors++;
break;
}
}
if(_errs51 === errors){
if(data17.operation !== undefined){
let data18 = data17.operation;
const _errs52 = errors;
if(errors === _errs52){
if(typeof data18 === "string"){
if(func2(data18) > 20){
const err28 = {instancePath:instancePath+"/prepared/command/begin/operation",schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/operation/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err28];
}
else {
vErrors.push(err28);
}
errors++;
}
else {
if(!pattern5.test(data18)){
const err29 = {instancePath:instancePath+"/prepared/command/begin/operation",schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/operation/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err30 = {instancePath:instancePath+"/prepared/command/begin/operation",schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/operation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
}
errors++;
}
}
var valid9 = _errs52 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data17.record !== undefined){
let data19 = data17.record;
const _errs54 = errors;
if(errors === _errs54){
if(typeof data19 === "string"){
if(func2(data19) > 20){
const err31 = {instancePath:instancePath+"/prepared/command/begin/record",schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/record/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err31];
}
else {
vErrors.push(err31);
}
errors++;
}
else {
if(!pattern5.test(data19)){
const err32 = {instancePath:instancePath+"/prepared/command/begin/record",schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/record/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err33 = {instancePath:instancePath+"/prepared/command/begin/record",schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/record/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
}
var valid9 = _errs54 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data17.expected !== undefined){
let data20 = data17.expected;
const _errs56 = errors;
if(errors === _errs56){
if(typeof data20 === "string"){
if(func2(data20) > 20){
const err34 = {instancePath:instancePath+"/prepared/command/begin/expected",schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/expected/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err34];
}
else {
vErrors.push(err34);
}
errors++;
}
else {
if(!pattern5.test(data20)){
const err35 = {instancePath:instancePath+"/prepared/command/begin/expected",schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/expected/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err36 = {instancePath:instancePath+"/prepared/command/begin/expected",schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/expected/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
}
}
var valid9 = _errs56 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data17.expected_digest !== undefined){
let data21 = data17.expected_digest;
const _errs58 = errors;
if(errors === _errs58){
if(Array.isArray(data21)){
if(data21.length > 32){
const err37 = {instancePath:instancePath+"/prepared/command/begin/expected_digest",schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/expected_digest/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err37];
}
else {
vErrors.push(err37);
}
errors++;
}
else {
if(data21.length < 32){
const err38 = {instancePath:instancePath+"/prepared/command/begin/expected_digest",schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/expected_digest/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err38];
}
else {
vErrors.push(err38);
}
errors++;
}
else {
var valid10 = true;
const len0 = data21.length;
for(let i0=0; i0<len0; i0++){
let data22 = data21[i0];
const _errs60 = errors;
if(!(((typeof data22 == "number") && (!(data22 % 1) && !isNaN(data22))) && (isFinite(data22)))){
const err39 = {instancePath:instancePath+"/prepared/command/begin/expected_digest/" + i0,schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/expected_digest/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err39];
}
else {
vErrors.push(err39);
}
errors++;
}
if(errors === _errs60){
if((typeof data22 == "number") && (isFinite(data22))){
if(data22 > 255 || isNaN(data22)){
const err40 = {instancePath:instancePath+"/prepared/command/begin/expected_digest/" + i0,schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/expected_digest/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err40];
}
else {
vErrors.push(err40);
}
errors++;
}
else {
if(data22 < 0 || isNaN(data22)){
const err41 = {instancePath:instancePath+"/prepared/command/begin/expected_digest/" + i0,schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/expected_digest/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err41];
}
else {
vErrors.push(err41);
}
errors++;
}
}
}
}
var valid10 = _errs60 === errors;
if(!valid10){
break;
}
}
}
}
}
else {
const err42 = {instancePath:instancePath+"/prepared/command/begin/expected_digest",schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/expected_digest/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err42];
}
else {
vErrors.push(err42);
}
errors++;
}
}
var valid9 = _errs58 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data17.revision !== undefined){
let data23 = data17.revision;
const _errs62 = errors;
if(errors === _errs62){
if(typeof data23 === "string"){
if(func2(data23) > 20){
const err43 = {instancePath:instancePath+"/prepared/command/begin/revision",schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/revision/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err43];
}
else {
vErrors.push(err43);
}
errors++;
}
else {
if(!pattern5.test(data23)){
const err44 = {instancePath:instancePath+"/prepared/command/begin/revision",schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/revision/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
const err45 = {instancePath:instancePath+"/prepared/command/begin/revision",schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err45];
}
else {
vErrors.push(err45);
}
errors++;
}
}
var valid9 = _errs62 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data17.spec !== undefined){
let data24 = data17.spec;
const _errs64 = errors;
if(errors === _errs64){
if(data24 && typeof data24 == "object" && !Array.isArray(data24)){
let missing9;
if((((data24.format === undefined) && (missing9 = "format")) || ((data24.length === undefined) && (missing9 = "length"))) || ((data24.digest === undefined) && (missing9 = "digest"))){
const err46 = {instancePath:instancePath+"/prepared/command/begin/spec",schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/spec/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
if(vErrors === null){
vErrors = [err46];
}
else {
vErrors.push(err46);
}
errors++;
}
else {
const _errs66 = errors;
for(const key9 in data24){
if(!(((key9 === "format") || (key9 === "length")) || (key9 === "digest"))){
const err47 = {instancePath:instancePath+"/prepared/command/begin/spec",schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/spec/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
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
if(_errs66 === errors){
if(data24.format !== undefined){
let data25 = data24.format;
const _errs67 = errors;
if(!(((typeof data25 == "number") && (!(data25 % 1) && !isNaN(data25))) && (isFinite(data25)))){
const err48 = {instancePath:instancePath+"/prepared/command/begin/spec/format",schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/spec/properties/format/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err48];
}
else {
vErrors.push(err48);
}
errors++;
}
if(errors === _errs67){
if((typeof data25 == "number") && (isFinite(data25))){
if(data25 > 4294967295 || isNaN(data25)){
const err49 = {instancePath:instancePath+"/prepared/command/begin/spec/format",schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/spec/properties/format/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err49];
}
else {
vErrors.push(err49);
}
errors++;
}
else {
if(data25 < 0 || isNaN(data25)){
const err50 = {instancePath:instancePath+"/prepared/command/begin/spec/format",schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/spec/properties/format/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
}
var valid11 = _errs67 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data24.length !== undefined){
let data26 = data24.length;
const _errs69 = errors;
if(!(((typeof data26 == "number") && (!(data26 % 1) && !isNaN(data26))) && (isFinite(data26)))){
const err51 = {instancePath:instancePath+"/prepared/command/begin/spec/length",schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/spec/properties/length/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err51];
}
else {
vErrors.push(err51);
}
errors++;
}
if(errors === _errs69){
if((typeof data26 == "number") && (isFinite(data26))){
if(data26 > 4294967295 || isNaN(data26)){
const err52 = {instancePath:instancePath+"/prepared/command/begin/spec/length",schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/spec/properties/length/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err52];
}
else {
vErrors.push(err52);
}
errors++;
}
else {
if(data26 < 0 || isNaN(data26)){
const err53 = {instancePath:instancePath+"/prepared/command/begin/spec/length",schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/spec/properties/length/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid11 = _errs69 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data24.digest !== undefined){
let data27 = data24.digest;
const _errs71 = errors;
if(errors === _errs71){
if(Array.isArray(data27)){
if(data27.length > 32){
const err54 = {instancePath:instancePath+"/prepared/command/begin/spec/digest",schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/spec/properties/digest/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err54];
}
else {
vErrors.push(err54);
}
errors++;
}
else {
if(data27.length < 32){
const err55 = {instancePath:instancePath+"/prepared/command/begin/spec/digest",schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/spec/properties/digest/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err55];
}
else {
vErrors.push(err55);
}
errors++;
}
else {
var valid12 = true;
const len1 = data27.length;
for(let i1=0; i1<len1; i1++){
let data28 = data27[i1];
const _errs73 = errors;
if(!(((typeof data28 == "number") && (!(data28 % 1) && !isNaN(data28))) && (isFinite(data28)))){
const err56 = {instancePath:instancePath+"/prepared/command/begin/spec/digest/" + i1,schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/spec/properties/digest/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err56];
}
else {
vErrors.push(err56);
}
errors++;
}
if(errors === _errs73){
if((typeof data28 == "number") && (isFinite(data28))){
if(data28 > 255 || isNaN(data28)){
const err57 = {instancePath:instancePath+"/prepared/command/begin/spec/digest/" + i1,schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/spec/properties/digest/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err57];
}
else {
vErrors.push(err57);
}
errors++;
}
else {
if(data28 < 0 || isNaN(data28)){
const err58 = {instancePath:instancePath+"/prepared/command/begin/spec/digest/" + i1,schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/spec/properties/digest/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid12 = _errs73 === errors;
if(!valid12){
break;
}
}
}
}
}
else {
const err59 = {instancePath:instancePath+"/prepared/command/begin/spec/digest",schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/spec/properties/digest/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err59];
}
else {
vErrors.push(err59);
}
errors++;
}
}
var valid11 = _errs71 === errors;
}
else {
var valid11 = true;
}
}
}
}
}
}
else {
const err60 = {instancePath:instancePath+"/prepared/command/begin/spec",schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/properties/spec/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err60];
}
else {
vErrors.push(err60);
}
errors++;
}
}
var valid9 = _errs64 === errors;
}
else {
var valid9 = true;
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
const err61 = {instancePath:instancePath+"/prepared/command/begin",schemaPath:"#/properties/prepared/properties/command/oneOf/2/properties/begin/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err61];
}
else {
vErrors.push(err61);
}
errors++;
}
}
}
}
}
}
else {
const err62 = {instancePath:instancePath+"/prepared/command",schemaPath:"#/properties/prepared/properties/command/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err62];
}
else {
vErrors.push(err62);
}
errors++;
}
}
var _valid0 = _errs46 === errors;
if(_valid0 && valid3){
valid3 = false;
passing0 = [passing0, 2];
}
else {
if(_valid0){
valid3 = true;
passing0 = 2;
if(props0 !== true){
props0 = true;
}
}
const _errs75 = errors;
if(errors === _errs75){
if(data9 && typeof data9 == "object" && !Array.isArray(data9)){
let missing10;
if((data9.part === undefined) && (missing10 = "part")){
const err63 = {instancePath:instancePath+"/prepared/command",schemaPath:"#/properties/prepared/properties/command/oneOf/3/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"};
if(vErrors === null){
vErrors = [err63];
}
else {
vErrors.push(err63);
}
errors++;
}
else {
const _errs77 = errors;
for(const key10 in data9){
if(!(key10 === "part")){
const err64 = {instancePath:instancePath+"/prepared/command",schemaPath:"#/properties/prepared/properties/command/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"};
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
if(_errs77 === errors){
if(data9.part !== undefined){
let data29 = data9.part;
const _errs78 = errors;
if(errors === _errs78){
if(data29 && typeof data29 == "object" && !Array.isArray(data29)){
let missing11;
if(((((data29.operation === undefined) && (missing11 = "operation")) || ((data29.ordinal === undefined) && (missing11 = "ordinal"))) || ((data29.second === undefined) && (missing11 = "second"))) || ((data29.bytes === undefined) && (missing11 = "bytes"))){
const err65 = {instancePath:instancePath+"/prepared/command/part",schemaPath:"#/properties/prepared/properties/command/oneOf/3/properties/part/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
if(vErrors === null){
vErrors = [err65];
}
else {
vErrors.push(err65);
}
errors++;
}
else {
const _errs80 = errors;
for(const key11 in data29){
if(!((((key11 === "operation") || (key11 === "ordinal")) || (key11 === "second")) || (key11 === "bytes"))){
const err66 = {instancePath:instancePath+"/prepared/command/part",schemaPath:"#/properties/prepared/properties/command/oneOf/3/properties/part/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
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
if(_errs80 === errors){
if(data29.operation !== undefined){
let data30 = data29.operation;
const _errs81 = errors;
if(errors === _errs81){
if(typeof data30 === "string"){
if(func2(data30) > 20){
const err67 = {instancePath:instancePath+"/prepared/command/part/operation",schemaPath:"#/properties/prepared/properties/command/oneOf/3/properties/part/properties/operation/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err67];
}
else {
vErrors.push(err67);
}
errors++;
}
else {
if(!pattern5.test(data30)){
const err68 = {instancePath:instancePath+"/prepared/command/part/operation",schemaPath:"#/properties/prepared/properties/command/oneOf/3/properties/part/properties/operation/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err69 = {instancePath:instancePath+"/prepared/command/part/operation",schemaPath:"#/properties/prepared/properties/command/oneOf/3/properties/part/properties/operation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err69];
}
else {
vErrors.push(err69);
}
errors++;
}
}
var valid14 = _errs81 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data29.ordinal !== undefined){
let data31 = data29.ordinal;
const _errs83 = errors;
if(!(((typeof data31 == "number") && (!(data31 % 1) && !isNaN(data31))) && (isFinite(data31)))){
const err70 = {instancePath:instancePath+"/prepared/command/part/ordinal",schemaPath:"#/properties/prepared/properties/command/oneOf/3/properties/part/properties/ordinal/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err70];
}
else {
vErrors.push(err70);
}
errors++;
}
if(errors === _errs83){
if((typeof data31 == "number") && (isFinite(data31))){
if(data31 > 4294967295 || isNaN(data31)){
const err71 = {instancePath:instancePath+"/prepared/command/part/ordinal",schemaPath:"#/properties/prepared/properties/command/oneOf/3/properties/part/properties/ordinal/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err71];
}
else {
vErrors.push(err71);
}
errors++;
}
else {
if(data31 < 0 || isNaN(data31)){
const err72 = {instancePath:instancePath+"/prepared/command/part/ordinal",schemaPath:"#/properties/prepared/properties/command/oneOf/3/properties/part/properties/ordinal/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err72];
}
else {
vErrors.push(err72);
}
errors++;
}
}
}
}
var valid14 = _errs83 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data29.second !== undefined){
const _errs85 = errors;
if(typeof data29.second !== "boolean"){
const err73 = {instancePath:instancePath+"/prepared/command/part/second",schemaPath:"#/properties/prepared/properties/command/oneOf/3/properties/part/properties/second/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err73];
}
else {
vErrors.push(err73);
}
errors++;
}
var valid14 = _errs85 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data29.bytes !== undefined){
let data33 = data29.bytes;
const _errs87 = errors;
if(errors === _errs87){
if(typeof data33 === "string"){
if(func2(data33) > 256){
const err74 = {instancePath:instancePath+"/prepared/command/part/bytes",schemaPath:"#/properties/prepared/properties/command/oneOf/3/properties/part/properties/bytes/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err74];
}
else {
vErrors.push(err74);
}
errors++;
}
else {
if(!pattern53.test(data33)){
const err75 = {instancePath:instancePath+"/prepared/command/part/bytes",schemaPath:"#/properties/prepared/properties/command/oneOf/3/properties/part/properties/bytes/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})+$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})+$"+"\""};
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
else {
const err76 = {instancePath:instancePath+"/prepared/command/part/bytes",schemaPath:"#/properties/prepared/properties/command/oneOf/3/properties/part/properties/bytes/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err76];
}
else {
vErrors.push(err76);
}
errors++;
}
}
var valid14 = _errs87 === errors;
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
else {
const err77 = {instancePath:instancePath+"/prepared/command/part",schemaPath:"#/properties/prepared/properties/command/oneOf/3/properties/part/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err77];
}
else {
vErrors.push(err77);
}
errors++;
}
}
}
}
}
}
else {
const err78 = {instancePath:instancePath+"/prepared/command",schemaPath:"#/properties/prepared/properties/command/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err78];
}
else {
vErrors.push(err78);
}
errors++;
}
}
var _valid0 = _errs75 === errors;
if(_valid0 && valid3){
valid3 = false;
passing0 = [passing0, 3];
}
else {
if(_valid0){
valid3 = true;
passing0 = 3;
if(props0 !== true){
props0 = true;
}
}
const _errs89 = errors;
if(errors === _errs89){
if(data9 && typeof data9 == "object" && !Array.isArray(data9)){
let missing12;
if((data9.publish === undefined) && (missing12 = "publish")){
const err79 = {instancePath:instancePath+"/prepared/command",schemaPath:"#/properties/prepared/properties/command/oneOf/4/required",keyword:"required",params:{missingProperty: missing12},message:"must have required property '"+missing12+"'"};
if(vErrors === null){
vErrors = [err79];
}
else {
vErrors.push(err79);
}
errors++;
}
else {
const _errs91 = errors;
for(const key12 in data9){
if(!(key12 === "publish")){
const err80 = {instancePath:instancePath+"/prepared/command",schemaPath:"#/properties/prepared/properties/command/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key12},message:"must NOT have additional properties"};
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
if(_errs91 === errors){
if(data9.publish !== undefined){
let data34 = data9.publish;
const _errs92 = errors;
if(errors === _errs92){
if(typeof data34 === "string"){
if(func2(data34) > 20){
const err81 = {instancePath:instancePath+"/prepared/command/publish",schemaPath:"#/properties/prepared/properties/command/oneOf/4/properties/publish/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err81];
}
else {
vErrors.push(err81);
}
errors++;
}
else {
if(!pattern5.test(data34)){
const err82 = {instancePath:instancePath+"/prepared/command/publish",schemaPath:"#/properties/prepared/properties/command/oneOf/4/properties/publish/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err83 = {instancePath:instancePath+"/prepared/command/publish",schemaPath:"#/properties/prepared/properties/command/oneOf/4/properties/publish/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err83];
}
else {
vErrors.push(err83);
}
errors++;
}
}
}
}
}
}
else {
const err84 = {instancePath:instancePath+"/prepared/command",schemaPath:"#/properties/prepared/properties/command/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err84];
}
else {
vErrors.push(err84);
}
errors++;
}
}
var _valid0 = _errs89 === errors;
if(_valid0 && valid3){
valid3 = false;
passing0 = [passing0, 4];
}
else {
if(_valid0){
valid3 = true;
passing0 = 4;
if(props0 !== true){
props0 = true;
}
}
const _errs94 = errors;
if(errors === _errs94){
if(data9 && typeof data9 == "object" && !Array.isArray(data9)){
let missing13;
if((data9.abandon === undefined) && (missing13 = "abandon")){
const err85 = {instancePath:instancePath+"/prepared/command",schemaPath:"#/properties/prepared/properties/command/oneOf/5/required",keyword:"required",params:{missingProperty: missing13},message:"must have required property '"+missing13+"'"};
if(vErrors === null){
vErrors = [err85];
}
else {
vErrors.push(err85);
}
errors++;
}
else {
const _errs96 = errors;
for(const key13 in data9){
if(!(key13 === "abandon")){
const err86 = {instancePath:instancePath+"/prepared/command",schemaPath:"#/properties/prepared/properties/command/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key13},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err86];
}
else {
vErrors.push(err86);
}
errors++;
break;
}
}
if(_errs96 === errors){
if(data9.abandon !== undefined){
let data35 = data9.abandon;
const _errs97 = errors;
if(errors === _errs97){
if(typeof data35 === "string"){
if(func2(data35) > 20){
const err87 = {instancePath:instancePath+"/prepared/command/abandon",schemaPath:"#/properties/prepared/properties/command/oneOf/5/properties/abandon/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err87];
}
else {
vErrors.push(err87);
}
errors++;
}
else {
if(!pattern5.test(data35)){
const err88 = {instancePath:instancePath+"/prepared/command/abandon",schemaPath:"#/properties/prepared/properties/command/oneOf/5/properties/abandon/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err89 = {instancePath:instancePath+"/prepared/command/abandon",schemaPath:"#/properties/prepared/properties/command/oneOf/5/properties/abandon/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err89];
}
else {
vErrors.push(err89);
}
errors++;
}
}
}
}
}
}
else {
const err90 = {instancePath:instancePath+"/prepared/command",schemaPath:"#/properties/prepared/properties/command/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err90];
}
else {
vErrors.push(err90);
}
errors++;
}
}
var _valid0 = _errs94 === errors;
if(_valid0 && valid3){
valid3 = false;
passing0 = [passing0, 5];
}
else {
if(_valid0){
valid3 = true;
passing0 = 5;
if(props0 !== true){
props0 = true;
}
}
const _errs99 = errors;
if(errors === _errs99){
if(data9 && typeof data9 == "object" && !Array.isArray(data9)){
let missing14;
if((data9.collect === undefined) && (missing14 = "collect")){
const err91 = {instancePath:instancePath+"/prepared/command",schemaPath:"#/properties/prepared/properties/command/oneOf/6/required",keyword:"required",params:{missingProperty: missing14},message:"must have required property '"+missing14+"'"};
if(vErrors === null){
vErrors = [err91];
}
else {
vErrors.push(err91);
}
errors++;
}
else {
const _errs101 = errors;
for(const key14 in data9){
if(!(key14 === "collect")){
const err92 = {instancePath:instancePath+"/prepared/command",schemaPath:"#/properties/prepared/properties/command/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key14},message:"must NOT have additional properties"};
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
if(_errs101 === errors){
if(data9.collect !== undefined){
let data36 = data9.collect;
const _errs102 = errors;
if(errors === _errs102){
if(typeof data36 === "string"){
if(func2(data36) > 20){
const err93 = {instancePath:instancePath+"/prepared/command/collect",schemaPath:"#/properties/prepared/properties/command/oneOf/6/properties/collect/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err93];
}
else {
vErrors.push(err93);
}
errors++;
}
else {
if(!pattern5.test(data36)){
const err94 = {instancePath:instancePath+"/prepared/command/collect",schemaPath:"#/properties/prepared/properties/command/oneOf/6/properties/collect/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err95 = {instancePath:instancePath+"/prepared/command/collect",schemaPath:"#/properties/prepared/properties/command/oneOf/6/properties/collect/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
const err96 = {instancePath:instancePath+"/prepared/command",schemaPath:"#/properties/prepared/properties/command/oneOf/6/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err96];
}
else {
vErrors.push(err96);
}
errors++;
}
}
var _valid0 = _errs99 === errors;
if(_valid0 && valid3){
valid3 = false;
passing0 = [passing0, 6];
}
else {
if(_valid0){
valid3 = true;
passing0 = 6;
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
if(!valid3){
const err97 = {instancePath:instancePath+"/prepared/command",schemaPath:"#/properties/prepared/properties/command/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err97];
}
else {
vErrors.push(err97);
}
errors++;
validate36.errors = vErrors;
return false;
}
else {
errors = _errs23;
if(vErrors !== null){
if(_errs23){
vErrors.length = _errs23;
}
else {
vErrors = null;
}
}
}
var valid1 = _errs22 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.digest !== undefined){
let data37 = data0.digest;
const _errs104 = errors;
if(errors === _errs104){
if(Array.isArray(data37)){
if(data37.length > 32){
validate36.errors = [{instancePath:instancePath+"/prepared/digest",schemaPath:"#/properties/prepared/properties/digest/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"}];
return false;
}
else {
if(data37.length < 32){
validate36.errors = [{instancePath:instancePath+"/prepared/digest",schemaPath:"#/properties/prepared/properties/digest/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"}];
return false;
}
else {
var valid18 = true;
const len2 = data37.length;
for(let i2=0; i2<len2; i2++){
let data38 = data37[i2];
const _errs106 = errors;
if(!(((typeof data38 == "number") && (!(data38 % 1) && !isNaN(data38))) && (isFinite(data38)))){
validate36.errors = [{instancePath:instancePath+"/prepared/digest/" + i2,schemaPath:"#/properties/prepared/properties/digest/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs106){
if((typeof data38 == "number") && (isFinite(data38))){
if(data38 > 255 || isNaN(data38)){
validate36.errors = [{instancePath:instancePath+"/prepared/digest/" + i2,schemaPath:"#/properties/prepared/properties/digest/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"}];
return false;
}
else {
if(data38 < 0 || isNaN(data38)){
validate36.errors = [{instancePath:instancePath+"/prepared/digest/" + i2,schemaPath:"#/properties/prepared/properties/digest/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid18 = _errs106 === errors;
if(!valid18){
break;
}
}
}
}
}
else {
validate36.errors = [{instancePath:instancePath+"/prepared/digest",schemaPath:"#/properties/prepared/properties/digest/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid1 = _errs104 === errors;
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
else {
validate36.errors = [{instancePath:instancePath+"/prepared",schemaPath:"#/properties/prepared/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.signature !== undefined){
let data39 = data.signature;
const _errs108 = errors;
if(errors === _errs108){
if(Array.isArray(data39)){
if(data39.length > 64){
validate36.errors = [{instancePath:instancePath+"/signature",schemaPath:"#/properties/signature/maxItems",keyword:"maxItems",params:{limit: 64},message:"must NOT have more than 64 items"}];
return false;
}
else {
if(data39.length < 64){
validate36.errors = [{instancePath:instancePath+"/signature",schemaPath:"#/properties/signature/minItems",keyword:"minItems",params:{limit: 64},message:"must NOT have fewer than 64 items"}];
return false;
}
else {
var valid19 = true;
const len3 = data39.length;
for(let i3=0; i3<len3; i3++){
let data40 = data39[i3];
const _errs110 = errors;
if(!(((typeof data40 == "number") && (!(data40 % 1) && !isNaN(data40))) && (isFinite(data40)))){
validate36.errors = [{instancePath:instancePath+"/signature/" + i3,schemaPath:"#/properties/signature/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs110){
if((typeof data40 == "number") && (isFinite(data40))){
if(data40 > 255 || isNaN(data40)){
validate36.errors = [{instancePath:instancePath+"/signature/" + i3,schemaPath:"#/properties/signature/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"}];
return false;
}
else {
if(data40 < 0 || isNaN(data40)){
validate36.errors = [{instancePath:instancePath+"/signature/" + i3,schemaPath:"#/properties/signature/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid19 = _errs110 === errors;
if(!valid19){
break;
}
}
}
}
}
else {
validate36.errors = [{instancePath:instancePath+"/signature",schemaPath:"#/properties/signature/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid0 = _errs108 === errors;
}
else {
var valid0 = true;
}
}
}
}
}
else {
validate36.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate36.errors = vErrors;
return errors === 0;
}
validate36.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const PreparedRead = validate37;
const schema55 = {"type":"object","additionalProperties":false,"properties":{"scope":{"type":"object","additionalProperties":false,"properties":{"realm":{"type":"integer","minimum":0,"maximum":9007199254740991},"application":{"type":"integer","minimum":0,"maximum":9007199254740991},"pid":{"type":"integer","minimum":0,"maximum":9007199254740991},"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"namespace":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20}},"required":["realm","application","pid","resource","namespace"]},"principal":{"type":"integer","minimum":0,"maximum":9007199254740991},"selection":{"oneOf":[{"type":"object","additionalProperties":false,"required":["identity"],"properties":{"identity":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["state"],"properties":{"state":{"type":"object","additionalProperties":false,"properties":{"operation":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"record":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"input":{"type":"integer","minimum":0,"maximum":9007199254740991}},"required":[]}}}]},"digest":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}}},"required":["scope","principal","selection","digest"]};

function validate37(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate37.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.scope === undefined) && (missing0 = "scope")) || ((data.principal === undefined) && (missing0 = "principal"))) || ((data.selection === undefined) && (missing0 = "selection"))) || ((data.digest === undefined) && (missing0 = "digest"))){
validate37.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "scope") || (key0 === "principal")) || (key0 === "selection")) || (key0 === "digest"))){
validate37.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
let data0 = data.scope;
const _errs2 = errors;
if(errors === _errs2){
if(data0 && typeof data0 == "object" && !Array.isArray(data0)){
let missing1;
if((((((data0.realm === undefined) && (missing1 = "realm")) || ((data0.application === undefined) && (missing1 = "application"))) || ((data0.pid === undefined) && (missing1 = "pid"))) || ((data0.resource === undefined) && (missing1 = "resource"))) || ((data0.namespace === undefined) && (missing1 = "namespace"))){
validate37.errors = [{instancePath:instancePath+"/scope",schemaPath:"#/properties/scope/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"}];
return false;
}
else {
const _errs4 = errors;
for(const key1 in data0){
if(!(((((key1 === "realm") || (key1 === "application")) || (key1 === "pid")) || (key1 === "resource")) || (key1 === "namespace"))){
validate37.errors = [{instancePath:instancePath+"/scope",schemaPath:"#/properties/scope/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs4 === errors){
if(data0.realm !== undefined){
let data1 = data0.realm;
const _errs5 = errors;
if(!(((typeof data1 == "number") && (!(data1 % 1) && !isNaN(data1))) && (isFinite(data1)))){
validate37.errors = [{instancePath:instancePath+"/scope/realm",schemaPath:"#/properties/scope/properties/realm/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs5){
if((typeof data1 == "number") && (isFinite(data1))){
if(data1 > 9007199254740991 || isNaN(data1)){
validate37.errors = [{instancePath:instancePath+"/scope/realm",schemaPath:"#/properties/scope/properties/realm/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data1 < 0 || isNaN(data1)){
validate37.errors = [{instancePath:instancePath+"/scope/realm",schemaPath:"#/properties/scope/properties/realm/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid1 = _errs5 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.application !== undefined){
let data2 = data0.application;
const _errs7 = errors;
if(!(((typeof data2 == "number") && (!(data2 % 1) && !isNaN(data2))) && (isFinite(data2)))){
validate37.errors = [{instancePath:instancePath+"/scope/application",schemaPath:"#/properties/scope/properties/application/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs7){
if((typeof data2 == "number") && (isFinite(data2))){
if(data2 > 9007199254740991 || isNaN(data2)){
validate37.errors = [{instancePath:instancePath+"/scope/application",schemaPath:"#/properties/scope/properties/application/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data2 < 0 || isNaN(data2)){
validate37.errors = [{instancePath:instancePath+"/scope/application",schemaPath:"#/properties/scope/properties/application/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid1 = _errs7 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.pid !== undefined){
let data3 = data0.pid;
const _errs9 = errors;
if(!(((typeof data3 == "number") && (!(data3 % 1) && !isNaN(data3))) && (isFinite(data3)))){
validate37.errors = [{instancePath:instancePath+"/scope/pid",schemaPath:"#/properties/scope/properties/pid/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs9){
if((typeof data3 == "number") && (isFinite(data3))){
if(data3 > 9007199254740991 || isNaN(data3)){
validate37.errors = [{instancePath:instancePath+"/scope/pid",schemaPath:"#/properties/scope/properties/pid/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data3 < 0 || isNaN(data3)){
validate37.errors = [{instancePath:instancePath+"/scope/pid",schemaPath:"#/properties/scope/properties/pid/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
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
if(data0.resource !== undefined){
let data4 = data0.resource;
const _errs11 = errors;
if(!(((typeof data4 == "number") && (!(data4 % 1) && !isNaN(data4))) && (isFinite(data4)))){
validate37.errors = [{instancePath:instancePath+"/scope/resource",schemaPath:"#/properties/scope/properties/resource/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs11){
if((typeof data4 == "number") && (isFinite(data4))){
if(data4 > 9007199254740991 || isNaN(data4)){
validate37.errors = [{instancePath:instancePath+"/scope/resource",schemaPath:"#/properties/scope/properties/resource/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data4 < 0 || isNaN(data4)){
validate37.errors = [{instancePath:instancePath+"/scope/resource",schemaPath:"#/properties/scope/properties/resource/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
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
if(data0.namespace !== undefined){
let data5 = data0.namespace;
const _errs13 = errors;
if(errors === _errs13){
if(typeof data5 === "string"){
if(func2(data5) > 20){
validate37.errors = [{instancePath:instancePath+"/scope/namespace",schemaPath:"#/properties/scope/properties/namespace/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern5.test(data5)){
validate37.errors = [{instancePath:instancePath+"/scope/namespace",schemaPath:"#/properties/scope/properties/namespace/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate37.errors = [{instancePath:instancePath+"/scope/namespace",schemaPath:"#/properties/scope/properties/namespace/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
}
}
else {
validate37.errors = [{instancePath:instancePath+"/scope",schemaPath:"#/properties/scope/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.principal !== undefined){
let data6 = data.principal;
const _errs15 = errors;
if(!(((typeof data6 == "number") && (!(data6 % 1) && !isNaN(data6))) && (isFinite(data6)))){
validate37.errors = [{instancePath:instancePath+"/principal",schemaPath:"#/properties/principal/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs15){
if((typeof data6 == "number") && (isFinite(data6))){
if(data6 > 9007199254740991 || isNaN(data6)){
validate37.errors = [{instancePath:instancePath+"/principal",schemaPath:"#/properties/principal/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data6 < 0 || isNaN(data6)){
validate37.errors = [{instancePath:instancePath+"/principal",schemaPath:"#/properties/principal/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid0 = _errs15 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.selection !== undefined){
let data7 = data.selection;
const _errs17 = errors;
const _errs18 = errors;
let valid2 = false;
let passing0 = null;
const _errs19 = errors;
if(errors === _errs19){
if(data7 && typeof data7 == "object" && !Array.isArray(data7)){
let missing2;
if((data7.identity === undefined) && (missing2 = "identity")){
const err0 = {instancePath:instancePath+"/selection",schemaPath:"#/properties/selection/oneOf/0/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
}
else {
const _errs21 = errors;
for(const key2 in data7){
if(!(key2 === "identity")){
const err1 = {instancePath:instancePath+"/selection",schemaPath:"#/properties/selection/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(_errs21 === errors){
if(data7.identity !== undefined){
let data8 = data7.identity;
const _errs22 = errors;
if(errors === _errs22){
if(data8 && typeof data8 == "object" && !Array.isArray(data8)){
if(Object.keys(data8).length > 0){
const err2 = {instancePath:instancePath+"/selection/identity",schemaPath:"#/properties/selection/oneOf/0/properties/identity/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
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
const err3 = {instancePath:instancePath+"/selection/identity",schemaPath:"#/properties/selection/oneOf/0/properties/identity/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err4 = {instancePath:instancePath+"/selection",schemaPath:"#/properties/selection/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
}
}
var _valid0 = _errs19 === errors;
if(_valid0){
valid2 = true;
passing0 = 0;
var props0 = true;
}
const _errs24 = errors;
if(errors === _errs24){
if(data7 && typeof data7 == "object" && !Array.isArray(data7)){
let missing3;
if((data7.state === undefined) && (missing3 = "state")){
const err5 = {instancePath:instancePath+"/selection",schemaPath:"#/properties/selection/oneOf/1/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
if(vErrors === null){
vErrors = [err5];
}
else {
vErrors.push(err5);
}
errors++;
}
else {
const _errs26 = errors;
for(const key3 in data7){
if(!(key3 === "state")){
const err6 = {instancePath:instancePath+"/selection",schemaPath:"#/properties/selection/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(_errs26 === errors){
if(data7.state !== undefined){
let data9 = data7.state;
const _errs27 = errors;
if(errors === _errs27){
if(data9 && typeof data9 == "object" && !Array.isArray(data9)){
const _errs29 = errors;
for(const key4 in data9){
if(!(((key4 === "operation") || (key4 === "record")) || (key4 === "input"))){
const err7 = {instancePath:instancePath+"/selection/state",schemaPath:"#/properties/selection/oneOf/1/properties/state/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(_errs29 === errors){
if(data9.operation !== undefined){
let data10 = data9.operation;
const _errs30 = errors;
if(errors === _errs30){
if(typeof data10 === "string"){
if(func2(data10) > 20){
const err8 = {instancePath:instancePath+"/selection/state/operation",schemaPath:"#/properties/selection/oneOf/1/properties/state/properties/operation/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err8];
}
else {
vErrors.push(err8);
}
errors++;
}
else {
if(!pattern5.test(data10)){
const err9 = {instancePath:instancePath+"/selection/state/operation",schemaPath:"#/properties/selection/oneOf/1/properties/state/properties/operation/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
const err10 = {instancePath:instancePath+"/selection/state/operation",schemaPath:"#/properties/selection/oneOf/1/properties/state/properties/operation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
}
}
var valid5 = _errs30 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data9.record !== undefined){
let data11 = data9.record;
const _errs32 = errors;
if(errors === _errs32){
if(typeof data11 === "string"){
if(func2(data11) > 20){
const err11 = {instancePath:instancePath+"/selection/state/record",schemaPath:"#/properties/selection/oneOf/1/properties/state/properties/record/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err11];
}
else {
vErrors.push(err11);
}
errors++;
}
else {
if(!pattern5.test(data11)){
const err12 = {instancePath:instancePath+"/selection/state/record",schemaPath:"#/properties/selection/oneOf/1/properties/state/properties/record/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
const err13 = {instancePath:instancePath+"/selection/state/record",schemaPath:"#/properties/selection/oneOf/1/properties/state/properties/record/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err13];
}
else {
vErrors.push(err13);
}
errors++;
}
}
var valid5 = _errs32 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data9.input !== undefined){
let data12 = data9.input;
const _errs34 = errors;
if(!(((typeof data12 == "number") && (!(data12 % 1) && !isNaN(data12))) && (isFinite(data12)))){
const err14 = {instancePath:instancePath+"/selection/state/input",schemaPath:"#/properties/selection/oneOf/1/properties/state/properties/input/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err14];
}
else {
vErrors.push(err14);
}
errors++;
}
if(errors === _errs34){
if((typeof data12 == "number") && (isFinite(data12))){
if(data12 > 9007199254740991 || isNaN(data12)){
const err15 = {instancePath:instancePath+"/selection/state/input",schemaPath:"#/properties/selection/oneOf/1/properties/state/properties/input/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
}
else {
if(data12 < 0 || isNaN(data12)){
const err16 = {instancePath:instancePath+"/selection/state/input",schemaPath:"#/properties/selection/oneOf/1/properties/state/properties/input/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid5 = _errs34 === errors;
}
else {
var valid5 = true;
}
}
}
}
}
else {
const err17 = {instancePath:instancePath+"/selection/state",schemaPath:"#/properties/selection/oneOf/1/properties/state/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err18 = {instancePath:instancePath+"/selection",schemaPath:"#/properties/selection/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
}
}
var _valid0 = _errs24 === errors;
if(_valid0 && valid2){
valid2 = false;
passing0 = [passing0, 1];
}
else {
if(_valid0){
valid2 = true;
passing0 = 1;
if(props0 !== true){
props0 = true;
}
}
}
if(!valid2){
const err19 = {instancePath:instancePath+"/selection",schemaPath:"#/properties/selection/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
validate37.errors = vErrors;
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
if(data.digest !== undefined){
let data13 = data.digest;
const _errs36 = errors;
if(errors === _errs36){
if(Array.isArray(data13)){
if(data13.length > 32){
validate37.errors = [{instancePath:instancePath+"/digest",schemaPath:"#/properties/digest/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"}];
return false;
}
else {
if(data13.length < 32){
validate37.errors = [{instancePath:instancePath+"/digest",schemaPath:"#/properties/digest/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"}];
return false;
}
else {
var valid6 = true;
const len0 = data13.length;
for(let i0=0; i0<len0; i0++){
let data14 = data13[i0];
const _errs38 = errors;
if(!(((typeof data14 == "number") && (!(data14 % 1) && !isNaN(data14))) && (isFinite(data14)))){
validate37.errors = [{instancePath:instancePath+"/digest/" + i0,schemaPath:"#/properties/digest/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs38){
if((typeof data14 == "number") && (isFinite(data14))){
if(data14 > 255 || isNaN(data14)){
validate37.errors = [{instancePath:instancePath+"/digest/" + i0,schemaPath:"#/properties/digest/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"}];
return false;
}
else {
if(data14 < 0 || isNaN(data14)){
validate37.errors = [{instancePath:instancePath+"/digest/" + i0,schemaPath:"#/properties/digest/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid6 = _errs38 === errors;
if(!valid6){
break;
}
}
}
}
}
else {
validate37.errors = [{instancePath:instancePath+"/digest",schemaPath:"#/properties/digest/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid0 = _errs36 === errors;
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
validate37.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate37.errors = vErrors;
return errors === 0;
}
validate37.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const SignedRead = validate38;
const schema56 = {"type":"object","additionalProperties":false,"properties":{"prepared":{"type":"object","additionalProperties":false,"properties":{"scope":{"type":"object","additionalProperties":false,"properties":{"realm":{"type":"integer","minimum":0,"maximum":9007199254740991},"application":{"type":"integer","minimum":0,"maximum":9007199254740991},"pid":{"type":"integer","minimum":0,"maximum":9007199254740991},"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"namespace":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20}},"required":["realm","application","pid","resource","namespace"]},"principal":{"type":"integer","minimum":0,"maximum":9007199254740991},"selection":{"oneOf":[{"type":"object","additionalProperties":false,"required":["identity"],"properties":{"identity":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["state"],"properties":{"state":{"type":"object","additionalProperties":false,"properties":{"operation":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"record":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"input":{"type":"integer","minimum":0,"maximum":9007199254740991}},"required":[]}}}]},"digest":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}}},"required":["scope","principal","selection","digest"]},"signature":{"type":"array","minItems":64,"maxItems":64,"items":{"type":"integer","minimum":0,"maximum":255}}},"required":["prepared","signature"]};

function validate38(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate38.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.prepared === undefined) && (missing0 = "prepared")) || ((data.signature === undefined) && (missing0 = "signature"))){
validate38.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "prepared") || (key0 === "signature"))){
validate38.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.prepared !== undefined){
let data0 = data.prepared;
const _errs2 = errors;
if(errors === _errs2){
if(data0 && typeof data0 == "object" && !Array.isArray(data0)){
let missing1;
if(((((data0.scope === undefined) && (missing1 = "scope")) || ((data0.principal === undefined) && (missing1 = "principal"))) || ((data0.selection === undefined) && (missing1 = "selection"))) || ((data0.digest === undefined) && (missing1 = "digest"))){
validate38.errors = [{instancePath:instancePath+"/prepared",schemaPath:"#/properties/prepared/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"}];
return false;
}
else {
const _errs4 = errors;
for(const key1 in data0){
if(!((((key1 === "scope") || (key1 === "principal")) || (key1 === "selection")) || (key1 === "digest"))){
validate38.errors = [{instancePath:instancePath+"/prepared",schemaPath:"#/properties/prepared/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs4 === errors){
if(data0.scope !== undefined){
let data1 = data0.scope;
const _errs5 = errors;
if(errors === _errs5){
if(data1 && typeof data1 == "object" && !Array.isArray(data1)){
let missing2;
if((((((data1.realm === undefined) && (missing2 = "realm")) || ((data1.application === undefined) && (missing2 = "application"))) || ((data1.pid === undefined) && (missing2 = "pid"))) || ((data1.resource === undefined) && (missing2 = "resource"))) || ((data1.namespace === undefined) && (missing2 = "namespace"))){
validate38.errors = [{instancePath:instancePath+"/prepared/scope",schemaPath:"#/properties/prepared/properties/scope/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"}];
return false;
}
else {
const _errs7 = errors;
for(const key2 in data1){
if(!(((((key2 === "realm") || (key2 === "application")) || (key2 === "pid")) || (key2 === "resource")) || (key2 === "namespace"))){
validate38.errors = [{instancePath:instancePath+"/prepared/scope",schemaPath:"#/properties/prepared/properties/scope/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs7 === errors){
if(data1.realm !== undefined){
let data2 = data1.realm;
const _errs8 = errors;
if(!(((typeof data2 == "number") && (!(data2 % 1) && !isNaN(data2))) && (isFinite(data2)))){
validate38.errors = [{instancePath:instancePath+"/prepared/scope/realm",schemaPath:"#/properties/prepared/properties/scope/properties/realm/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs8){
if((typeof data2 == "number") && (isFinite(data2))){
if(data2 > 9007199254740991 || isNaN(data2)){
validate38.errors = [{instancePath:instancePath+"/prepared/scope/realm",schemaPath:"#/properties/prepared/properties/scope/properties/realm/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data2 < 0 || isNaN(data2)){
validate38.errors = [{instancePath:instancePath+"/prepared/scope/realm",schemaPath:"#/properties/prepared/properties/scope/properties/realm/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid2 = _errs8 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data1.application !== undefined){
let data3 = data1.application;
const _errs10 = errors;
if(!(((typeof data3 == "number") && (!(data3 % 1) && !isNaN(data3))) && (isFinite(data3)))){
validate38.errors = [{instancePath:instancePath+"/prepared/scope/application",schemaPath:"#/properties/prepared/properties/scope/properties/application/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs10){
if((typeof data3 == "number") && (isFinite(data3))){
if(data3 > 9007199254740991 || isNaN(data3)){
validate38.errors = [{instancePath:instancePath+"/prepared/scope/application",schemaPath:"#/properties/prepared/properties/scope/properties/application/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data3 < 0 || isNaN(data3)){
validate38.errors = [{instancePath:instancePath+"/prepared/scope/application",schemaPath:"#/properties/prepared/properties/scope/properties/application/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid2 = _errs10 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data1.pid !== undefined){
let data4 = data1.pid;
const _errs12 = errors;
if(!(((typeof data4 == "number") && (!(data4 % 1) && !isNaN(data4))) && (isFinite(data4)))){
validate38.errors = [{instancePath:instancePath+"/prepared/scope/pid",schemaPath:"#/properties/prepared/properties/scope/properties/pid/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs12){
if((typeof data4 == "number") && (isFinite(data4))){
if(data4 > 9007199254740991 || isNaN(data4)){
validate38.errors = [{instancePath:instancePath+"/prepared/scope/pid",schemaPath:"#/properties/prepared/properties/scope/properties/pid/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data4 < 0 || isNaN(data4)){
validate38.errors = [{instancePath:instancePath+"/prepared/scope/pid",schemaPath:"#/properties/prepared/properties/scope/properties/pid/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid2 = _errs12 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data1.resource !== undefined){
let data5 = data1.resource;
const _errs14 = errors;
if(!(((typeof data5 == "number") && (!(data5 % 1) && !isNaN(data5))) && (isFinite(data5)))){
validate38.errors = [{instancePath:instancePath+"/prepared/scope/resource",schemaPath:"#/properties/prepared/properties/scope/properties/resource/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs14){
if((typeof data5 == "number") && (isFinite(data5))){
if(data5 > 9007199254740991 || isNaN(data5)){
validate38.errors = [{instancePath:instancePath+"/prepared/scope/resource",schemaPath:"#/properties/prepared/properties/scope/properties/resource/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data5 < 0 || isNaN(data5)){
validate38.errors = [{instancePath:instancePath+"/prepared/scope/resource",schemaPath:"#/properties/prepared/properties/scope/properties/resource/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid2 = _errs14 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data1.namespace !== undefined){
let data6 = data1.namespace;
const _errs16 = errors;
if(errors === _errs16){
if(typeof data6 === "string"){
if(func2(data6) > 20){
validate38.errors = [{instancePath:instancePath+"/prepared/scope/namespace",schemaPath:"#/properties/prepared/properties/scope/properties/namespace/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern5.test(data6)){
validate38.errors = [{instancePath:instancePath+"/prepared/scope/namespace",schemaPath:"#/properties/prepared/properties/scope/properties/namespace/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate38.errors = [{instancePath:instancePath+"/prepared/scope/namespace",schemaPath:"#/properties/prepared/properties/scope/properties/namespace/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid2 = _errs16 === errors;
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
else {
validate38.errors = [{instancePath:instancePath+"/prepared/scope",schemaPath:"#/properties/prepared/properties/scope/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
var valid1 = _errs5 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.principal !== undefined){
let data7 = data0.principal;
const _errs18 = errors;
if(!(((typeof data7 == "number") && (!(data7 % 1) && !isNaN(data7))) && (isFinite(data7)))){
validate38.errors = [{instancePath:instancePath+"/prepared/principal",schemaPath:"#/properties/prepared/properties/principal/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs18){
if((typeof data7 == "number") && (isFinite(data7))){
if(data7 > 9007199254740991 || isNaN(data7)){
validate38.errors = [{instancePath:instancePath+"/prepared/principal",schemaPath:"#/properties/prepared/properties/principal/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data7 < 0 || isNaN(data7)){
validate38.errors = [{instancePath:instancePath+"/prepared/principal",schemaPath:"#/properties/prepared/properties/principal/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid1 = _errs18 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.selection !== undefined){
let data8 = data0.selection;
const _errs20 = errors;
const _errs21 = errors;
let valid3 = false;
let passing0 = null;
const _errs22 = errors;
if(errors === _errs22){
if(data8 && typeof data8 == "object" && !Array.isArray(data8)){
let missing3;
if((data8.identity === undefined) && (missing3 = "identity")){
const err0 = {instancePath:instancePath+"/prepared/selection",schemaPath:"#/properties/prepared/properties/selection/oneOf/0/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
}
else {
const _errs24 = errors;
for(const key3 in data8){
if(!(key3 === "identity")){
const err1 = {instancePath:instancePath+"/prepared/selection",schemaPath:"#/properties/prepared/properties/selection/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(_errs24 === errors){
if(data8.identity !== undefined){
let data9 = data8.identity;
const _errs25 = errors;
if(errors === _errs25){
if(data9 && typeof data9 == "object" && !Array.isArray(data9)){
if(Object.keys(data9).length > 0){
const err2 = {instancePath:instancePath+"/prepared/selection/identity",schemaPath:"#/properties/prepared/properties/selection/oneOf/0/properties/identity/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
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
const err3 = {instancePath:instancePath+"/prepared/selection/identity",schemaPath:"#/properties/prepared/properties/selection/oneOf/0/properties/identity/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err4 = {instancePath:instancePath+"/prepared/selection",schemaPath:"#/properties/prepared/properties/selection/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
}
}
var _valid0 = _errs22 === errors;
if(_valid0){
valid3 = true;
passing0 = 0;
var props0 = true;
}
const _errs27 = errors;
if(errors === _errs27){
if(data8 && typeof data8 == "object" && !Array.isArray(data8)){
let missing4;
if((data8.state === undefined) && (missing4 = "state")){
const err5 = {instancePath:instancePath+"/prepared/selection",schemaPath:"#/properties/prepared/properties/selection/oneOf/1/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
if(vErrors === null){
vErrors = [err5];
}
else {
vErrors.push(err5);
}
errors++;
}
else {
const _errs29 = errors;
for(const key4 in data8){
if(!(key4 === "state")){
const err6 = {instancePath:instancePath+"/prepared/selection",schemaPath:"#/properties/prepared/properties/selection/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(_errs29 === errors){
if(data8.state !== undefined){
let data10 = data8.state;
const _errs30 = errors;
if(errors === _errs30){
if(data10 && typeof data10 == "object" && !Array.isArray(data10)){
const _errs32 = errors;
for(const key5 in data10){
if(!(((key5 === "operation") || (key5 === "record")) || (key5 === "input"))){
const err7 = {instancePath:instancePath+"/prepared/selection/state",schemaPath:"#/properties/prepared/properties/selection/oneOf/1/properties/state/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(_errs32 === errors){
if(data10.operation !== undefined){
let data11 = data10.operation;
const _errs33 = errors;
if(errors === _errs33){
if(typeof data11 === "string"){
if(func2(data11) > 20){
const err8 = {instancePath:instancePath+"/prepared/selection/state/operation",schemaPath:"#/properties/prepared/properties/selection/oneOf/1/properties/state/properties/operation/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err8];
}
else {
vErrors.push(err8);
}
errors++;
}
else {
if(!pattern5.test(data11)){
const err9 = {instancePath:instancePath+"/prepared/selection/state/operation",schemaPath:"#/properties/prepared/properties/selection/oneOf/1/properties/state/properties/operation/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
const err10 = {instancePath:instancePath+"/prepared/selection/state/operation",schemaPath:"#/properties/prepared/properties/selection/oneOf/1/properties/state/properties/operation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
}
}
var valid6 = _errs33 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data10.record !== undefined){
let data12 = data10.record;
const _errs35 = errors;
if(errors === _errs35){
if(typeof data12 === "string"){
if(func2(data12) > 20){
const err11 = {instancePath:instancePath+"/prepared/selection/state/record",schemaPath:"#/properties/prepared/properties/selection/oneOf/1/properties/state/properties/record/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err11];
}
else {
vErrors.push(err11);
}
errors++;
}
else {
if(!pattern5.test(data12)){
const err12 = {instancePath:instancePath+"/prepared/selection/state/record",schemaPath:"#/properties/prepared/properties/selection/oneOf/1/properties/state/properties/record/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
const err13 = {instancePath:instancePath+"/prepared/selection/state/record",schemaPath:"#/properties/prepared/properties/selection/oneOf/1/properties/state/properties/record/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err13];
}
else {
vErrors.push(err13);
}
errors++;
}
}
var valid6 = _errs35 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data10.input !== undefined){
let data13 = data10.input;
const _errs37 = errors;
if(!(((typeof data13 == "number") && (!(data13 % 1) && !isNaN(data13))) && (isFinite(data13)))){
const err14 = {instancePath:instancePath+"/prepared/selection/state/input",schemaPath:"#/properties/prepared/properties/selection/oneOf/1/properties/state/properties/input/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err14];
}
else {
vErrors.push(err14);
}
errors++;
}
if(errors === _errs37){
if((typeof data13 == "number") && (isFinite(data13))){
if(data13 > 9007199254740991 || isNaN(data13)){
const err15 = {instancePath:instancePath+"/prepared/selection/state/input",schemaPath:"#/properties/prepared/properties/selection/oneOf/1/properties/state/properties/input/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
}
else {
if(data13 < 0 || isNaN(data13)){
const err16 = {instancePath:instancePath+"/prepared/selection/state/input",schemaPath:"#/properties/prepared/properties/selection/oneOf/1/properties/state/properties/input/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid6 = _errs37 === errors;
}
else {
var valid6 = true;
}
}
}
}
}
else {
const err17 = {instancePath:instancePath+"/prepared/selection/state",schemaPath:"#/properties/prepared/properties/selection/oneOf/1/properties/state/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err18 = {instancePath:instancePath+"/prepared/selection",schemaPath:"#/properties/prepared/properties/selection/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
}
}
var _valid0 = _errs27 === errors;
if(_valid0 && valid3){
valid3 = false;
passing0 = [passing0, 1];
}
else {
if(_valid0){
valid3 = true;
passing0 = 1;
if(props0 !== true){
props0 = true;
}
}
}
if(!valid3){
const err19 = {instancePath:instancePath+"/prepared/selection",schemaPath:"#/properties/prepared/properties/selection/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
validate38.errors = vErrors;
return false;
}
else {
errors = _errs21;
if(vErrors !== null){
if(_errs21){
vErrors.length = _errs21;
}
else {
vErrors = null;
}
}
}
var valid1 = _errs20 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.digest !== undefined){
let data14 = data0.digest;
const _errs39 = errors;
if(errors === _errs39){
if(Array.isArray(data14)){
if(data14.length > 32){
validate38.errors = [{instancePath:instancePath+"/prepared/digest",schemaPath:"#/properties/prepared/properties/digest/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"}];
return false;
}
else {
if(data14.length < 32){
validate38.errors = [{instancePath:instancePath+"/prepared/digest",schemaPath:"#/properties/prepared/properties/digest/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"}];
return false;
}
else {
var valid7 = true;
const len0 = data14.length;
for(let i0=0; i0<len0; i0++){
let data15 = data14[i0];
const _errs41 = errors;
if(!(((typeof data15 == "number") && (!(data15 % 1) && !isNaN(data15))) && (isFinite(data15)))){
validate38.errors = [{instancePath:instancePath+"/prepared/digest/" + i0,schemaPath:"#/properties/prepared/properties/digest/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs41){
if((typeof data15 == "number") && (isFinite(data15))){
if(data15 > 255 || isNaN(data15)){
validate38.errors = [{instancePath:instancePath+"/prepared/digest/" + i0,schemaPath:"#/properties/prepared/properties/digest/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"}];
return false;
}
else {
if(data15 < 0 || isNaN(data15)){
validate38.errors = [{instancePath:instancePath+"/prepared/digest/" + i0,schemaPath:"#/properties/prepared/properties/digest/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid7 = _errs41 === errors;
if(!valid7){
break;
}
}
}
}
}
else {
validate38.errors = [{instancePath:instancePath+"/prepared/digest",schemaPath:"#/properties/prepared/properties/digest/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid1 = _errs39 === errors;
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
else {
validate38.errors = [{instancePath:instancePath+"/prepared",schemaPath:"#/properties/prepared/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.signature !== undefined){
let data16 = data.signature;
const _errs43 = errors;
if(errors === _errs43){
if(Array.isArray(data16)){
if(data16.length > 64){
validate38.errors = [{instancePath:instancePath+"/signature",schemaPath:"#/properties/signature/maxItems",keyword:"maxItems",params:{limit: 64},message:"must NOT have more than 64 items"}];
return false;
}
else {
if(data16.length < 64){
validate38.errors = [{instancePath:instancePath+"/signature",schemaPath:"#/properties/signature/minItems",keyword:"minItems",params:{limit: 64},message:"must NOT have fewer than 64 items"}];
return false;
}
else {
var valid8 = true;
const len1 = data16.length;
for(let i1=0; i1<len1; i1++){
let data17 = data16[i1];
const _errs45 = errors;
if(!(((typeof data17 == "number") && (!(data17 % 1) && !isNaN(data17))) && (isFinite(data17)))){
validate38.errors = [{instancePath:instancePath+"/signature/" + i1,schemaPath:"#/properties/signature/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs45){
if((typeof data17 == "number") && (isFinite(data17))){
if(data17 > 255 || isNaN(data17)){
validate38.errors = [{instancePath:instancePath+"/signature/" + i1,schemaPath:"#/properties/signature/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"}];
return false;
}
else {
if(data17 < 0 || isNaN(data17)){
validate38.errors = [{instancePath:instancePath+"/signature/" + i1,schemaPath:"#/properties/signature/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid8 = _errs45 === errors;
if(!valid8){
break;
}
}
}
}
}
else {
validate38.errors = [{instancePath:instancePath+"/signature",schemaPath:"#/properties/signature/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid0 = _errs43 === errors;
}
else {
var valid0 = true;
}
}
}
}
}
else {
validate38.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate38.errors = vErrors;
return errors === 0;
}
validate38.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Observation = validate39;
const schema57 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["identity"],"properties":{"identity":{"type":"object","additionalProperties":false,"properties":{"principal":{"type":"integer","minimum":0,"maximum":9007199254740991},"sequence":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"permissions":{"type":"integer","minimum":0,"maximum":65535},"pid":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"policy_revision":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20}},"required":["principal","sequence","permissions","pid","policy_revision"]}}},{"type":"object","additionalProperties":false,"required":["state"],"properties":{"state":{"type":"object","additionalProperties":false,"properties":{"revision":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"configuration":{"type":"object","additionalProperties":false,"properties":{"application":{"type":"integer","minimum":0,"maximum":9007199254740991},"namespace":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"realm":{"type":"integer","minimum":0,"maximum":9007199254740991},"administrator":{"type":"integer","minimum":0,"maximum":9007199254740991},"name_digest":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}}},"required":["application","namespace","realm","administrator","name_digest"]},"policy":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"revision":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"publish":{"type":"boolean"}},"required":["revision","publish"]},{"type":"null"}]},"head":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"revision":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"record":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"spec":{"type":"object","additionalProperties":false,"properties":{"format":{"type":"integer","minimum":0,"maximum":4294967295},"length":{"type":"integer","minimum":0,"maximum":4294967295},"digest":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}}},"required":["format","length","digest"]},"principal":{"type":"integer","minimum":0,"maximum":9007199254740991},"operation":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"input":{"type":"integer","minimum":0,"maximum":9007199254740991}},"required":["revision","record","spec","principal","operation","input"]},{"type":"null"}]},"receipt":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"proposal":{"type":"object","additionalProperties":false,"properties":{"operation":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"record":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"expected":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"expected_digest":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"revision":{"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20},"spec":{"type":"object","additionalProperties":false,"properties":{"format":{"type":"integer","minimum":0,"maximum":4294967295},"length":{"type":"integer","minimum":0,"maximum":4294967295},"digest":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}}},"required":["format","length","digest"]}},"required":["operation","record","expected","expected_digest","revision","spec"]},"phase":{"type":"string","enum":["staging","applied","conflict","abandoned"]},"input":{"type":"integer","minimum":0,"maximum":9007199254740991},"owns_record":{"type":"boolean"}},"required":["proposal","phase","input","owns_record"]},{"type":"null"}]},"upload":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"written":{"type":"integer","minimum":0,"maximum":4294967295},"first_half":{"type":"boolean"},"state":{"type":"string","enum":["staging","published","abandoned","retired"]}},"required":["written","first_half","state"]},{"type":"null"}]},"disposition":{"anyOf":[{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512},{"type":"null"}]}},"required":["revision","configuration","policy","head","receipt","upload","disposition"]}}}]};
const pattern102 = new RegExp("^(?:[0-9a-f]{2})*$", "u");

function validate39(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate39.evaluated;
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
if((data.identity === undefined) && (missing0 = "identity")){
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
if(!(key0 === "identity")){
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
if(data.identity !== undefined){
let data0 = data.identity;
const _errs4 = errors;
if(errors === _errs4){
if(data0 && typeof data0 == "object" && !Array.isArray(data0)){
let missing1;
if((((((data0.principal === undefined) && (missing1 = "principal")) || ((data0.sequence === undefined) && (missing1 = "sequence"))) || ((data0.permissions === undefined) && (missing1 = "permissions"))) || ((data0.pid === undefined) && (missing1 = "pid"))) || ((data0.policy_revision === undefined) && (missing1 = "policy_revision"))){
const err2 = {instancePath:instancePath+"/identity",schemaPath:"#/oneOf/0/properties/identity/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
if(!(((((key1 === "principal") || (key1 === "sequence")) || (key1 === "permissions")) || (key1 === "pid")) || (key1 === "policy_revision"))){
const err3 = {instancePath:instancePath+"/identity",schemaPath:"#/oneOf/0/properties/identity/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(data0.principal !== undefined){
let data1 = data0.principal;
const _errs7 = errors;
if(!(((typeof data1 == "number") && (!(data1 % 1) && !isNaN(data1))) && (isFinite(data1)))){
const err4 = {instancePath:instancePath+"/identity/principal",schemaPath:"#/oneOf/0/properties/identity/properties/principal/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
}
if(errors === _errs7){
if((typeof data1 == "number") && (isFinite(data1))){
if(data1 > 9007199254740991 || isNaN(data1)){
const err5 = {instancePath:instancePath+"/identity/principal",schemaPath:"#/oneOf/0/properties/identity/properties/principal/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err5];
}
else {
vErrors.push(err5);
}
errors++;
}
else {
if(data1 < 0 || isNaN(data1)){
const err6 = {instancePath:instancePath+"/identity/principal",schemaPath:"#/oneOf/0/properties/identity/properties/principal/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err6];
}
else {
vErrors.push(err6);
}
errors++;
}
}
}
}
var valid2 = _errs7 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data0.sequence !== undefined){
let data2 = data0.sequence;
const _errs9 = errors;
if(errors === _errs9){
if(typeof data2 === "string"){
if(func2(data2) > 20){
const err7 = {instancePath:instancePath+"/identity/sequence",schemaPath:"#/oneOf/0/properties/identity/properties/sequence/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err7];
}
else {
vErrors.push(err7);
}
errors++;
}
else {
if(!pattern5.test(data2)){
const err8 = {instancePath:instancePath+"/identity/sequence",schemaPath:"#/oneOf/0/properties/identity/properties/sequence/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err9 = {instancePath:instancePath+"/identity/sequence",schemaPath:"#/oneOf/0/properties/identity/properties/sequence/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
}
}
var valid2 = _errs9 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data0.permissions !== undefined){
let data3 = data0.permissions;
const _errs11 = errors;
if(!(((typeof data3 == "number") && (!(data3 % 1) && !isNaN(data3))) && (isFinite(data3)))){
const err10 = {instancePath:instancePath+"/identity/permissions",schemaPath:"#/oneOf/0/properties/identity/properties/permissions/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
}
if(errors === _errs11){
if((typeof data3 == "number") && (isFinite(data3))){
if(data3 > 65535 || isNaN(data3)){
const err11 = {instancePath:instancePath+"/identity/permissions",schemaPath:"#/oneOf/0/properties/identity/properties/permissions/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
if(vErrors === null){
vErrors = [err11];
}
else {
vErrors.push(err11);
}
errors++;
}
else {
if(data3 < 0 || isNaN(data3)){
const err12 = {instancePath:instancePath+"/identity/permissions",schemaPath:"#/oneOf/0/properties/identity/properties/permissions/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
}
var valid2 = _errs11 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data0.pid !== undefined){
let data4 = data0.pid;
const _errs13 = errors;
const _errs14 = errors;
let valid3 = false;
const _errs15 = errors;
if(!(((typeof data4 == "number") && (!(data4 % 1) && !isNaN(data4))) && (isFinite(data4)))){
const err13 = {instancePath:instancePath+"/identity/pid",schemaPath:"#/oneOf/0/properties/identity/properties/pid/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err13];
}
else {
vErrors.push(err13);
}
errors++;
}
if(errors === _errs15){
if((typeof data4 == "number") && (isFinite(data4))){
if(data4 > 9007199254740991 || isNaN(data4)){
const err14 = {instancePath:instancePath+"/identity/pid",schemaPath:"#/oneOf/0/properties/identity/properties/pid/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err14];
}
else {
vErrors.push(err14);
}
errors++;
}
else {
if(data4 < 0 || isNaN(data4)){
const err15 = {instancePath:instancePath+"/identity/pid",schemaPath:"#/oneOf/0/properties/identity/properties/pid/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var _valid1 = _errs15 === errors;
valid3 = valid3 || _valid1;
const _errs17 = errors;
if(data4 !== null){
const err16 = {instancePath:instancePath+"/identity/pid",schemaPath:"#/oneOf/0/properties/identity/properties/pid/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err16];
}
else {
vErrors.push(err16);
}
errors++;
}
var _valid1 = _errs17 === errors;
valid3 = valid3 || _valid1;
if(!valid3){
const err17 = {instancePath:instancePath+"/identity/pid",schemaPath:"#/oneOf/0/properties/identity/properties/pid/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err17];
}
else {
vErrors.push(err17);
}
errors++;
}
else {
errors = _errs14;
if(vErrors !== null){
if(_errs14){
vErrors.length = _errs14;
}
else {
vErrors = null;
}
}
}
var valid2 = _errs13 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data0.policy_revision !== undefined){
let data5 = data0.policy_revision;
const _errs19 = errors;
if(errors === _errs19){
if(typeof data5 === "string"){
if(func2(data5) > 20){
const err18 = {instancePath:instancePath+"/identity/policy_revision",schemaPath:"#/oneOf/0/properties/identity/properties/policy_revision/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
}
else {
if(!pattern5.test(data5)){
const err19 = {instancePath:instancePath+"/identity/policy_revision",schemaPath:"#/oneOf/0/properties/identity/properties/policy_revision/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
}
}
}
else {
const err20 = {instancePath:instancePath+"/identity/policy_revision",schemaPath:"#/oneOf/0/properties/identity/properties/policy_revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err20];
}
else {
vErrors.push(err20);
}
errors++;
}
}
var valid2 = _errs19 === errors;
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
else {
const err21 = {instancePath:instancePath+"/identity",schemaPath:"#/oneOf/0/properties/identity/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err22 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err22];
}
else {
vErrors.push(err22);
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
const _errs21 = errors;
if(errors === _errs21){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing2;
if((data.state === undefined) && (missing2 = "state")){
const err23 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
if(vErrors === null){
vErrors = [err23];
}
else {
vErrors.push(err23);
}
errors++;
}
else {
const _errs23 = errors;
for(const key2 in data){
if(!(key2 === "state")){
const err24 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(_errs23 === errors){
if(data.state !== undefined){
let data6 = data.state;
const _errs24 = errors;
if(errors === _errs24){
if(data6 && typeof data6 == "object" && !Array.isArray(data6)){
let missing3;
if((((((((data6.revision === undefined) && (missing3 = "revision")) || ((data6.configuration === undefined) && (missing3 = "configuration"))) || ((data6.policy === undefined) && (missing3 = "policy"))) || ((data6.head === undefined) && (missing3 = "head"))) || ((data6.receipt === undefined) && (missing3 = "receipt"))) || ((data6.upload === undefined) && (missing3 = "upload"))) || ((data6.disposition === undefined) && (missing3 = "disposition"))){
const err25 = {instancePath:instancePath+"/state",schemaPath:"#/oneOf/1/properties/state/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
if(vErrors === null){
vErrors = [err25];
}
else {
vErrors.push(err25);
}
errors++;
}
else {
const _errs26 = errors;
for(const key3 in data6){
if(!(((((((key3 === "revision") || (key3 === "configuration")) || (key3 === "policy")) || (key3 === "head")) || (key3 === "receipt")) || (key3 === "upload")) || (key3 === "disposition"))){
const err26 = {instancePath:instancePath+"/state",schemaPath:"#/oneOf/1/properties/state/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(_errs26 === errors){
if(data6.revision !== undefined){
let data7 = data6.revision;
const _errs27 = errors;
if(errors === _errs27){
if(typeof data7 === "string"){
if(func2(data7) > 20){
const err27 = {instancePath:instancePath+"/state/revision",schemaPath:"#/oneOf/1/properties/state/properties/revision/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err27];
}
else {
vErrors.push(err27);
}
errors++;
}
else {
if(!pattern5.test(data7)){
const err28 = {instancePath:instancePath+"/state/revision",schemaPath:"#/oneOf/1/properties/state/properties/revision/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err29 = {instancePath:instancePath+"/state/revision",schemaPath:"#/oneOf/1/properties/state/properties/revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err29];
}
else {
vErrors.push(err29);
}
errors++;
}
}
var valid5 = _errs27 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data6.configuration !== undefined){
let data8 = data6.configuration;
const _errs29 = errors;
if(errors === _errs29){
if(data8 && typeof data8 == "object" && !Array.isArray(data8)){
let missing4;
if((((((data8.application === undefined) && (missing4 = "application")) || ((data8.namespace === undefined) && (missing4 = "namespace"))) || ((data8.realm === undefined) && (missing4 = "realm"))) || ((data8.administrator === undefined) && (missing4 = "administrator"))) || ((data8.name_digest === undefined) && (missing4 = "name_digest"))){
const err30 = {instancePath:instancePath+"/state/configuration",schemaPath:"#/oneOf/1/properties/state/properties/configuration/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
}
errors++;
}
else {
const _errs31 = errors;
for(const key4 in data8){
if(!(((((key4 === "application") || (key4 === "namespace")) || (key4 === "realm")) || (key4 === "administrator")) || (key4 === "name_digest"))){
const err31 = {instancePath:instancePath+"/state/configuration",schemaPath:"#/oneOf/1/properties/state/properties/configuration/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(_errs31 === errors){
if(data8.application !== undefined){
let data9 = data8.application;
const _errs32 = errors;
if(!(((typeof data9 == "number") && (!(data9 % 1) && !isNaN(data9))) && (isFinite(data9)))){
const err32 = {instancePath:instancePath+"/state/configuration/application",schemaPath:"#/oneOf/1/properties/state/properties/configuration/properties/application/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err32];
}
else {
vErrors.push(err32);
}
errors++;
}
if(errors === _errs32){
if((typeof data9 == "number") && (isFinite(data9))){
if(data9 > 9007199254740991 || isNaN(data9)){
const err33 = {instancePath:instancePath+"/state/configuration/application",schemaPath:"#/oneOf/1/properties/state/properties/configuration/properties/application/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
else {
if(data9 < 0 || isNaN(data9)){
const err34 = {instancePath:instancePath+"/state/configuration/application",schemaPath:"#/oneOf/1/properties/state/properties/configuration/properties/application/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid6 = _errs32 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data8.namespace !== undefined){
let data10 = data8.namespace;
const _errs34 = errors;
if(errors === _errs34){
if(typeof data10 === "string"){
if(func2(data10) > 20){
const err35 = {instancePath:instancePath+"/state/configuration/namespace",schemaPath:"#/oneOf/1/properties/state/properties/configuration/properties/namespace/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err35];
}
else {
vErrors.push(err35);
}
errors++;
}
else {
if(!pattern5.test(data10)){
const err36 = {instancePath:instancePath+"/state/configuration/namespace",schemaPath:"#/oneOf/1/properties/state/properties/configuration/properties/namespace/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err37 = {instancePath:instancePath+"/state/configuration/namespace",schemaPath:"#/oneOf/1/properties/state/properties/configuration/properties/namespace/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err37];
}
else {
vErrors.push(err37);
}
errors++;
}
}
var valid6 = _errs34 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data8.realm !== undefined){
let data11 = data8.realm;
const _errs36 = errors;
if(!(((typeof data11 == "number") && (!(data11 % 1) && !isNaN(data11))) && (isFinite(data11)))){
const err38 = {instancePath:instancePath+"/state/configuration/realm",schemaPath:"#/oneOf/1/properties/state/properties/configuration/properties/realm/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err38];
}
else {
vErrors.push(err38);
}
errors++;
}
if(errors === _errs36){
if((typeof data11 == "number") && (isFinite(data11))){
if(data11 > 9007199254740991 || isNaN(data11)){
const err39 = {instancePath:instancePath+"/state/configuration/realm",schemaPath:"#/oneOf/1/properties/state/properties/configuration/properties/realm/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err39];
}
else {
vErrors.push(err39);
}
errors++;
}
else {
if(data11 < 0 || isNaN(data11)){
const err40 = {instancePath:instancePath+"/state/configuration/realm",schemaPath:"#/oneOf/1/properties/state/properties/configuration/properties/realm/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid6 = _errs36 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data8.administrator !== undefined){
let data12 = data8.administrator;
const _errs38 = errors;
if(!(((typeof data12 == "number") && (!(data12 % 1) && !isNaN(data12))) && (isFinite(data12)))){
const err41 = {instancePath:instancePath+"/state/configuration/administrator",schemaPath:"#/oneOf/1/properties/state/properties/configuration/properties/administrator/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err41];
}
else {
vErrors.push(err41);
}
errors++;
}
if(errors === _errs38){
if((typeof data12 == "number") && (isFinite(data12))){
if(data12 > 9007199254740991 || isNaN(data12)){
const err42 = {instancePath:instancePath+"/state/configuration/administrator",schemaPath:"#/oneOf/1/properties/state/properties/configuration/properties/administrator/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
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
const err43 = {instancePath:instancePath+"/state/configuration/administrator",schemaPath:"#/oneOf/1/properties/state/properties/configuration/properties/administrator/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid6 = _errs38 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data8.name_digest !== undefined){
let data13 = data8.name_digest;
const _errs40 = errors;
if(errors === _errs40){
if(Array.isArray(data13)){
if(data13.length > 32){
const err44 = {instancePath:instancePath+"/state/configuration/name_digest",schemaPath:"#/oneOf/1/properties/state/properties/configuration/properties/name_digest/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err44];
}
else {
vErrors.push(err44);
}
errors++;
}
else {
if(data13.length < 32){
const err45 = {instancePath:instancePath+"/state/configuration/name_digest",schemaPath:"#/oneOf/1/properties/state/properties/configuration/properties/name_digest/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err45];
}
else {
vErrors.push(err45);
}
errors++;
}
else {
var valid7 = true;
const len0 = data13.length;
for(let i0=0; i0<len0; i0++){
let data14 = data13[i0];
const _errs42 = errors;
if(!(((typeof data14 == "number") && (!(data14 % 1) && !isNaN(data14))) && (isFinite(data14)))){
const err46 = {instancePath:instancePath+"/state/configuration/name_digest/" + i0,schemaPath:"#/oneOf/1/properties/state/properties/configuration/properties/name_digest/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err46];
}
else {
vErrors.push(err46);
}
errors++;
}
if(errors === _errs42){
if((typeof data14 == "number") && (isFinite(data14))){
if(data14 > 255 || isNaN(data14)){
const err47 = {instancePath:instancePath+"/state/configuration/name_digest/" + i0,schemaPath:"#/oneOf/1/properties/state/properties/configuration/properties/name_digest/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err47];
}
else {
vErrors.push(err47);
}
errors++;
}
else {
if(data14 < 0 || isNaN(data14)){
const err48 = {instancePath:instancePath+"/state/configuration/name_digest/" + i0,schemaPath:"#/oneOf/1/properties/state/properties/configuration/properties/name_digest/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid7 = _errs42 === errors;
if(!valid7){
break;
}
}
}
}
}
else {
const err49 = {instancePath:instancePath+"/state/configuration/name_digest",schemaPath:"#/oneOf/1/properties/state/properties/configuration/properties/name_digest/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err49];
}
else {
vErrors.push(err49);
}
errors++;
}
}
var valid6 = _errs40 === errors;
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
else {
const err50 = {instancePath:instancePath+"/state/configuration",schemaPath:"#/oneOf/1/properties/state/properties/configuration/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err50];
}
else {
vErrors.push(err50);
}
errors++;
}
}
var valid5 = _errs29 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data6.policy !== undefined){
let data15 = data6.policy;
const _errs44 = errors;
const _errs45 = errors;
let valid8 = false;
const _errs46 = errors;
if(errors === _errs46){
if(data15 && typeof data15 == "object" && !Array.isArray(data15)){
let missing5;
if(((data15.revision === undefined) && (missing5 = "revision")) || ((data15.publish === undefined) && (missing5 = "publish"))){
const err51 = {instancePath:instancePath+"/state/policy",schemaPath:"#/oneOf/1/properties/state/properties/policy/anyOf/0/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
if(vErrors === null){
vErrors = [err51];
}
else {
vErrors.push(err51);
}
errors++;
}
else {
const _errs48 = errors;
for(const key5 in data15){
if(!((key5 === "revision") || (key5 === "publish"))){
const err52 = {instancePath:instancePath+"/state/policy",schemaPath:"#/oneOf/1/properties/state/properties/policy/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(_errs48 === errors){
if(data15.revision !== undefined){
let data16 = data15.revision;
const _errs49 = errors;
if(errors === _errs49){
if(typeof data16 === "string"){
if(func2(data16) > 20){
const err53 = {instancePath:instancePath+"/state/policy/revision",schemaPath:"#/oneOf/1/properties/state/properties/policy/anyOf/0/properties/revision/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err53];
}
else {
vErrors.push(err53);
}
errors++;
}
else {
if(!pattern5.test(data16)){
const err54 = {instancePath:instancePath+"/state/policy/revision",schemaPath:"#/oneOf/1/properties/state/properties/policy/anyOf/0/properties/revision/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err55 = {instancePath:instancePath+"/state/policy/revision",schemaPath:"#/oneOf/1/properties/state/properties/policy/anyOf/0/properties/revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err55];
}
else {
vErrors.push(err55);
}
errors++;
}
}
var valid9 = _errs49 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data15.publish !== undefined){
const _errs51 = errors;
if(typeof data15.publish !== "boolean"){
const err56 = {instancePath:instancePath+"/state/policy/publish",schemaPath:"#/oneOf/1/properties/state/properties/policy/anyOf/0/properties/publish/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err56];
}
else {
vErrors.push(err56);
}
errors++;
}
var valid9 = _errs51 === errors;
}
else {
var valid9 = true;
}
}
}
}
}
else {
const err57 = {instancePath:instancePath+"/state/policy",schemaPath:"#/oneOf/1/properties/state/properties/policy/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err57];
}
else {
vErrors.push(err57);
}
errors++;
}
}
var _valid2 = _errs46 === errors;
valid8 = valid8 || _valid2;
const _errs53 = errors;
if(data15 !== null){
const err58 = {instancePath:instancePath+"/state/policy",schemaPath:"#/oneOf/1/properties/state/properties/policy/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err58];
}
else {
vErrors.push(err58);
}
errors++;
}
var _valid2 = _errs53 === errors;
valid8 = valid8 || _valid2;
if(!valid8){
const err59 = {instancePath:instancePath+"/state/policy",schemaPath:"#/oneOf/1/properties/state/properties/policy/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err59];
}
else {
vErrors.push(err59);
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
var valid5 = _errs44 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data6.head !== undefined){
let data18 = data6.head;
const _errs55 = errors;
const _errs56 = errors;
let valid10 = false;
const _errs57 = errors;
if(errors === _errs57){
if(data18 && typeof data18 == "object" && !Array.isArray(data18)){
let missing6;
if(((((((data18.revision === undefined) && (missing6 = "revision")) || ((data18.record === undefined) && (missing6 = "record"))) || ((data18.spec === undefined) && (missing6 = "spec"))) || ((data18.principal === undefined) && (missing6 = "principal"))) || ((data18.operation === undefined) && (missing6 = "operation"))) || ((data18.input === undefined) && (missing6 = "input"))){
const err60 = {instancePath:instancePath+"/state/head",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
if(vErrors === null){
vErrors = [err60];
}
else {
vErrors.push(err60);
}
errors++;
}
else {
const _errs59 = errors;
for(const key6 in data18){
if(!((((((key6 === "revision") || (key6 === "record")) || (key6 === "spec")) || (key6 === "principal")) || (key6 === "operation")) || (key6 === "input"))){
const err61 = {instancePath:instancePath+"/state/head",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
if(_errs59 === errors){
if(data18.revision !== undefined){
let data19 = data18.revision;
const _errs60 = errors;
if(errors === _errs60){
if(typeof data19 === "string"){
if(func2(data19) > 20){
const err62 = {instancePath:instancePath+"/state/head/revision",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/properties/revision/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err62];
}
else {
vErrors.push(err62);
}
errors++;
}
else {
if(!pattern5.test(data19)){
const err63 = {instancePath:instancePath+"/state/head/revision",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/properties/revision/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err64 = {instancePath:instancePath+"/state/head/revision",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/properties/revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err64];
}
else {
vErrors.push(err64);
}
errors++;
}
}
var valid11 = _errs60 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data18.record !== undefined){
let data20 = data18.record;
const _errs62 = errors;
if(errors === _errs62){
if(typeof data20 === "string"){
if(func2(data20) > 20){
const err65 = {instancePath:instancePath+"/state/head/record",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/properties/record/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err65];
}
else {
vErrors.push(err65);
}
errors++;
}
else {
if(!pattern5.test(data20)){
const err66 = {instancePath:instancePath+"/state/head/record",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/properties/record/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err67 = {instancePath:instancePath+"/state/head/record",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/properties/record/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err67];
}
else {
vErrors.push(err67);
}
errors++;
}
}
var valid11 = _errs62 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data18.spec !== undefined){
let data21 = data18.spec;
const _errs64 = errors;
if(errors === _errs64){
if(data21 && typeof data21 == "object" && !Array.isArray(data21)){
let missing7;
if((((data21.format === undefined) && (missing7 = "format")) || ((data21.length === undefined) && (missing7 = "length"))) || ((data21.digest === undefined) && (missing7 = "digest"))){
const err68 = {instancePath:instancePath+"/state/head/spec",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/properties/spec/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
if(vErrors === null){
vErrors = [err68];
}
else {
vErrors.push(err68);
}
errors++;
}
else {
const _errs66 = errors;
for(const key7 in data21){
if(!(((key7 === "format") || (key7 === "length")) || (key7 === "digest"))){
const err69 = {instancePath:instancePath+"/state/head/spec",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/properties/spec/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err69];
}
else {
vErrors.push(err69);
}
errors++;
break;
}
}
if(_errs66 === errors){
if(data21.format !== undefined){
let data22 = data21.format;
const _errs67 = errors;
if(!(((typeof data22 == "number") && (!(data22 % 1) && !isNaN(data22))) && (isFinite(data22)))){
const err70 = {instancePath:instancePath+"/state/head/spec/format",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/properties/spec/properties/format/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err70];
}
else {
vErrors.push(err70);
}
errors++;
}
if(errors === _errs67){
if((typeof data22 == "number") && (isFinite(data22))){
if(data22 > 4294967295 || isNaN(data22)){
const err71 = {instancePath:instancePath+"/state/head/spec/format",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/properties/spec/properties/format/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err71];
}
else {
vErrors.push(err71);
}
errors++;
}
else {
if(data22 < 0 || isNaN(data22)){
const err72 = {instancePath:instancePath+"/state/head/spec/format",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/properties/spec/properties/format/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err72];
}
else {
vErrors.push(err72);
}
errors++;
}
}
}
}
var valid12 = _errs67 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data21.length !== undefined){
let data23 = data21.length;
const _errs69 = errors;
if(!(((typeof data23 == "number") && (!(data23 % 1) && !isNaN(data23))) && (isFinite(data23)))){
const err73 = {instancePath:instancePath+"/state/head/spec/length",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/properties/spec/properties/length/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err73];
}
else {
vErrors.push(err73);
}
errors++;
}
if(errors === _errs69){
if((typeof data23 == "number") && (isFinite(data23))){
if(data23 > 4294967295 || isNaN(data23)){
const err74 = {instancePath:instancePath+"/state/head/spec/length",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/properties/spec/properties/length/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err74];
}
else {
vErrors.push(err74);
}
errors++;
}
else {
if(data23 < 0 || isNaN(data23)){
const err75 = {instancePath:instancePath+"/state/head/spec/length",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/properties/spec/properties/length/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid12 = _errs69 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data21.digest !== undefined){
let data24 = data21.digest;
const _errs71 = errors;
if(errors === _errs71){
if(Array.isArray(data24)){
if(data24.length > 32){
const err76 = {instancePath:instancePath+"/state/head/spec/digest",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/properties/spec/properties/digest/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err76];
}
else {
vErrors.push(err76);
}
errors++;
}
else {
if(data24.length < 32){
const err77 = {instancePath:instancePath+"/state/head/spec/digest",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/properties/spec/properties/digest/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err77];
}
else {
vErrors.push(err77);
}
errors++;
}
else {
var valid13 = true;
const len1 = data24.length;
for(let i1=0; i1<len1; i1++){
let data25 = data24[i1];
const _errs73 = errors;
if(!(((typeof data25 == "number") && (!(data25 % 1) && !isNaN(data25))) && (isFinite(data25)))){
const err78 = {instancePath:instancePath+"/state/head/spec/digest/" + i1,schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/properties/spec/properties/digest/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err78];
}
else {
vErrors.push(err78);
}
errors++;
}
if(errors === _errs73){
if((typeof data25 == "number") && (isFinite(data25))){
if(data25 > 255 || isNaN(data25)){
const err79 = {instancePath:instancePath+"/state/head/spec/digest/" + i1,schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/properties/spec/properties/digest/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err79];
}
else {
vErrors.push(err79);
}
errors++;
}
else {
if(data25 < 0 || isNaN(data25)){
const err80 = {instancePath:instancePath+"/state/head/spec/digest/" + i1,schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/properties/spec/properties/digest/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid13 = _errs73 === errors;
if(!valid13){
break;
}
}
}
}
}
else {
const err81 = {instancePath:instancePath+"/state/head/spec/digest",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/properties/spec/properties/digest/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err81];
}
else {
vErrors.push(err81);
}
errors++;
}
}
var valid12 = _errs71 === errors;
}
else {
var valid12 = true;
}
}
}
}
}
}
else {
const err82 = {instancePath:instancePath+"/state/head/spec",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/properties/spec/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err82];
}
else {
vErrors.push(err82);
}
errors++;
}
}
var valid11 = _errs64 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data18.principal !== undefined){
let data26 = data18.principal;
const _errs75 = errors;
if(!(((typeof data26 == "number") && (!(data26 % 1) && !isNaN(data26))) && (isFinite(data26)))){
const err83 = {instancePath:instancePath+"/state/head/principal",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/properties/principal/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err83];
}
else {
vErrors.push(err83);
}
errors++;
}
if(errors === _errs75){
if((typeof data26 == "number") && (isFinite(data26))){
if(data26 > 9007199254740991 || isNaN(data26)){
const err84 = {instancePath:instancePath+"/state/head/principal",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/properties/principal/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err84];
}
else {
vErrors.push(err84);
}
errors++;
}
else {
if(data26 < 0 || isNaN(data26)){
const err85 = {instancePath:instancePath+"/state/head/principal",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/properties/principal/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid11 = _errs75 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data18.operation !== undefined){
let data27 = data18.operation;
const _errs77 = errors;
if(errors === _errs77){
if(typeof data27 === "string"){
if(func2(data27) > 20){
const err86 = {instancePath:instancePath+"/state/head/operation",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/properties/operation/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err86];
}
else {
vErrors.push(err86);
}
errors++;
}
else {
if(!pattern5.test(data27)){
const err87 = {instancePath:instancePath+"/state/head/operation",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/properties/operation/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err88 = {instancePath:instancePath+"/state/head/operation",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/properties/operation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err88];
}
else {
vErrors.push(err88);
}
errors++;
}
}
var valid11 = _errs77 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data18.input !== undefined){
let data28 = data18.input;
const _errs79 = errors;
if(!(((typeof data28 == "number") && (!(data28 % 1) && !isNaN(data28))) && (isFinite(data28)))){
const err89 = {instancePath:instancePath+"/state/head/input",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/properties/input/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err89];
}
else {
vErrors.push(err89);
}
errors++;
}
if(errors === _errs79){
if((typeof data28 == "number") && (isFinite(data28))){
if(data28 > 9007199254740991 || isNaN(data28)){
const err90 = {instancePath:instancePath+"/state/head/input",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/properties/input/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err90];
}
else {
vErrors.push(err90);
}
errors++;
}
else {
if(data28 < 0 || isNaN(data28)){
const err91 = {instancePath:instancePath+"/state/head/input",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/properties/input/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err91];
}
else {
vErrors.push(err91);
}
errors++;
}
}
}
}
var valid11 = _errs79 === errors;
}
else {
var valid11 = true;
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
const err92 = {instancePath:instancePath+"/state/head",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err92];
}
else {
vErrors.push(err92);
}
errors++;
}
}
var _valid3 = _errs57 === errors;
valid10 = valid10 || _valid3;
const _errs81 = errors;
if(data18 !== null){
const err93 = {instancePath:instancePath+"/state/head",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err93];
}
else {
vErrors.push(err93);
}
errors++;
}
var _valid3 = _errs81 === errors;
valid10 = valid10 || _valid3;
if(!valid10){
const err94 = {instancePath:instancePath+"/state/head",schemaPath:"#/oneOf/1/properties/state/properties/head/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err94];
}
else {
vErrors.push(err94);
}
errors++;
}
else {
errors = _errs56;
if(vErrors !== null){
if(_errs56){
vErrors.length = _errs56;
}
else {
vErrors = null;
}
}
}
var valid5 = _errs55 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data6.receipt !== undefined){
let data29 = data6.receipt;
const _errs83 = errors;
const _errs84 = errors;
let valid14 = false;
const _errs85 = errors;
if(errors === _errs85){
if(data29 && typeof data29 == "object" && !Array.isArray(data29)){
let missing8;
if(((((data29.proposal === undefined) && (missing8 = "proposal")) || ((data29.phase === undefined) && (missing8 = "phase"))) || ((data29.input === undefined) && (missing8 = "input"))) || ((data29.owns_record === undefined) && (missing8 = "owns_record"))){
const err95 = {instancePath:instancePath+"/state/receipt",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
if(vErrors === null){
vErrors = [err95];
}
else {
vErrors.push(err95);
}
errors++;
}
else {
const _errs87 = errors;
for(const key8 in data29){
if(!((((key8 === "proposal") || (key8 === "phase")) || (key8 === "input")) || (key8 === "owns_record"))){
const err96 = {instancePath:instancePath+"/state/receipt",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
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
if(_errs87 === errors){
if(data29.proposal !== undefined){
let data30 = data29.proposal;
const _errs88 = errors;
if(errors === _errs88){
if(data30 && typeof data30 == "object" && !Array.isArray(data30)){
let missing9;
if(((((((data30.operation === undefined) && (missing9 = "operation")) || ((data30.record === undefined) && (missing9 = "record"))) || ((data30.expected === undefined) && (missing9 = "expected"))) || ((data30.expected_digest === undefined) && (missing9 = "expected_digest"))) || ((data30.revision === undefined) && (missing9 = "revision"))) || ((data30.spec === undefined) && (missing9 = "spec"))){
const err97 = {instancePath:instancePath+"/state/receipt/proposal",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
if(vErrors === null){
vErrors = [err97];
}
else {
vErrors.push(err97);
}
errors++;
}
else {
const _errs90 = errors;
for(const key9 in data30){
if(!((((((key9 === "operation") || (key9 === "record")) || (key9 === "expected")) || (key9 === "expected_digest")) || (key9 === "revision")) || (key9 === "spec"))){
const err98 = {instancePath:instancePath+"/state/receipt/proposal",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
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
if(_errs90 === errors){
if(data30.operation !== undefined){
let data31 = data30.operation;
const _errs91 = errors;
if(errors === _errs91){
if(typeof data31 === "string"){
if(func2(data31) > 20){
const err99 = {instancePath:instancePath+"/state/receipt/proposal/operation",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/operation/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err99];
}
else {
vErrors.push(err99);
}
errors++;
}
else {
if(!pattern5.test(data31)){
const err100 = {instancePath:instancePath+"/state/receipt/proposal/operation",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/operation/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err101 = {instancePath:instancePath+"/state/receipt/proposal/operation",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/operation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err101];
}
else {
vErrors.push(err101);
}
errors++;
}
}
var valid16 = _errs91 === errors;
}
else {
var valid16 = true;
}
if(valid16){
if(data30.record !== undefined){
let data32 = data30.record;
const _errs93 = errors;
if(errors === _errs93){
if(typeof data32 === "string"){
if(func2(data32) > 20){
const err102 = {instancePath:instancePath+"/state/receipt/proposal/record",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/record/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err102];
}
else {
vErrors.push(err102);
}
errors++;
}
else {
if(!pattern5.test(data32)){
const err103 = {instancePath:instancePath+"/state/receipt/proposal/record",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/record/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err104 = {instancePath:instancePath+"/state/receipt/proposal/record",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/record/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err104];
}
else {
vErrors.push(err104);
}
errors++;
}
}
var valid16 = _errs93 === errors;
}
else {
var valid16 = true;
}
if(valid16){
if(data30.expected !== undefined){
let data33 = data30.expected;
const _errs95 = errors;
if(errors === _errs95){
if(typeof data33 === "string"){
if(func2(data33) > 20){
const err105 = {instancePath:instancePath+"/state/receipt/proposal/expected",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/expected/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err105];
}
else {
vErrors.push(err105);
}
errors++;
}
else {
if(!pattern5.test(data33)){
const err106 = {instancePath:instancePath+"/state/receipt/proposal/expected",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/expected/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err106];
}
else {
vErrors.push(err106);
}
errors++;
}
}
}
else {
const err107 = {instancePath:instancePath+"/state/receipt/proposal/expected",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/expected/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err107];
}
else {
vErrors.push(err107);
}
errors++;
}
}
var valid16 = _errs95 === errors;
}
else {
var valid16 = true;
}
if(valid16){
if(data30.expected_digest !== undefined){
let data34 = data30.expected_digest;
const _errs97 = errors;
if(errors === _errs97){
if(Array.isArray(data34)){
if(data34.length > 32){
const err108 = {instancePath:instancePath+"/state/receipt/proposal/expected_digest",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/expected_digest/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err108];
}
else {
vErrors.push(err108);
}
errors++;
}
else {
if(data34.length < 32){
const err109 = {instancePath:instancePath+"/state/receipt/proposal/expected_digest",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/expected_digest/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err109];
}
else {
vErrors.push(err109);
}
errors++;
}
else {
var valid17 = true;
const len2 = data34.length;
for(let i2=0; i2<len2; i2++){
let data35 = data34[i2];
const _errs99 = errors;
if(!(((typeof data35 == "number") && (!(data35 % 1) && !isNaN(data35))) && (isFinite(data35)))){
const err110 = {instancePath:instancePath+"/state/receipt/proposal/expected_digest/" + i2,schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/expected_digest/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err110];
}
else {
vErrors.push(err110);
}
errors++;
}
if(errors === _errs99){
if((typeof data35 == "number") && (isFinite(data35))){
if(data35 > 255 || isNaN(data35)){
const err111 = {instancePath:instancePath+"/state/receipt/proposal/expected_digest/" + i2,schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/expected_digest/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err111];
}
else {
vErrors.push(err111);
}
errors++;
}
else {
if(data35 < 0 || isNaN(data35)){
const err112 = {instancePath:instancePath+"/state/receipt/proposal/expected_digest/" + i2,schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/expected_digest/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err112];
}
else {
vErrors.push(err112);
}
errors++;
}
}
}
}
var valid17 = _errs99 === errors;
if(!valid17){
break;
}
}
}
}
}
else {
const err113 = {instancePath:instancePath+"/state/receipt/proposal/expected_digest",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/expected_digest/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err113];
}
else {
vErrors.push(err113);
}
errors++;
}
}
var valid16 = _errs97 === errors;
}
else {
var valid16 = true;
}
if(valid16){
if(data30.revision !== undefined){
let data36 = data30.revision;
const _errs101 = errors;
if(errors === _errs101){
if(typeof data36 === "string"){
if(func2(data36) > 20){
const err114 = {instancePath:instancePath+"/state/receipt/proposal/revision",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/revision/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err114];
}
else {
vErrors.push(err114);
}
errors++;
}
else {
if(!pattern5.test(data36)){
const err115 = {instancePath:instancePath+"/state/receipt/proposal/revision",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/revision/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err116 = {instancePath:instancePath+"/state/receipt/proposal/revision",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err116];
}
else {
vErrors.push(err116);
}
errors++;
}
}
var valid16 = _errs101 === errors;
}
else {
var valid16 = true;
}
if(valid16){
if(data30.spec !== undefined){
let data37 = data30.spec;
const _errs103 = errors;
if(errors === _errs103){
if(data37 && typeof data37 == "object" && !Array.isArray(data37)){
let missing10;
if((((data37.format === undefined) && (missing10 = "format")) || ((data37.length === undefined) && (missing10 = "length"))) || ((data37.digest === undefined) && (missing10 = "digest"))){
const err117 = {instancePath:instancePath+"/state/receipt/proposal/spec",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/spec/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"};
if(vErrors === null){
vErrors = [err117];
}
else {
vErrors.push(err117);
}
errors++;
}
else {
const _errs105 = errors;
for(const key10 in data37){
if(!(((key10 === "format") || (key10 === "length")) || (key10 === "digest"))){
const err118 = {instancePath:instancePath+"/state/receipt/proposal/spec",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/spec/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"};
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
if(_errs105 === errors){
if(data37.format !== undefined){
let data38 = data37.format;
const _errs106 = errors;
if(!(((typeof data38 == "number") && (!(data38 % 1) && !isNaN(data38))) && (isFinite(data38)))){
const err119 = {instancePath:instancePath+"/state/receipt/proposal/spec/format",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/spec/properties/format/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err119];
}
else {
vErrors.push(err119);
}
errors++;
}
if(errors === _errs106){
if((typeof data38 == "number") && (isFinite(data38))){
if(data38 > 4294967295 || isNaN(data38)){
const err120 = {instancePath:instancePath+"/state/receipt/proposal/spec/format",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/spec/properties/format/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err120];
}
else {
vErrors.push(err120);
}
errors++;
}
else {
if(data38 < 0 || isNaN(data38)){
const err121 = {instancePath:instancePath+"/state/receipt/proposal/spec/format",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/spec/properties/format/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err121];
}
else {
vErrors.push(err121);
}
errors++;
}
}
}
}
var valid18 = _errs106 === errors;
}
else {
var valid18 = true;
}
if(valid18){
if(data37.length !== undefined){
let data39 = data37.length;
const _errs108 = errors;
if(!(((typeof data39 == "number") && (!(data39 % 1) && !isNaN(data39))) && (isFinite(data39)))){
const err122 = {instancePath:instancePath+"/state/receipt/proposal/spec/length",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/spec/properties/length/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err122];
}
else {
vErrors.push(err122);
}
errors++;
}
if(errors === _errs108){
if((typeof data39 == "number") && (isFinite(data39))){
if(data39 > 4294967295 || isNaN(data39)){
const err123 = {instancePath:instancePath+"/state/receipt/proposal/spec/length",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/spec/properties/length/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err123];
}
else {
vErrors.push(err123);
}
errors++;
}
else {
if(data39 < 0 || isNaN(data39)){
const err124 = {instancePath:instancePath+"/state/receipt/proposal/spec/length",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/spec/properties/length/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid18 = _errs108 === errors;
}
else {
var valid18 = true;
}
if(valid18){
if(data37.digest !== undefined){
let data40 = data37.digest;
const _errs110 = errors;
if(errors === _errs110){
if(Array.isArray(data40)){
if(data40.length > 32){
const err125 = {instancePath:instancePath+"/state/receipt/proposal/spec/digest",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/spec/properties/digest/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err125];
}
else {
vErrors.push(err125);
}
errors++;
}
else {
if(data40.length < 32){
const err126 = {instancePath:instancePath+"/state/receipt/proposal/spec/digest",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/spec/properties/digest/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err126];
}
else {
vErrors.push(err126);
}
errors++;
}
else {
var valid19 = true;
const len3 = data40.length;
for(let i3=0; i3<len3; i3++){
let data41 = data40[i3];
const _errs112 = errors;
if(!(((typeof data41 == "number") && (!(data41 % 1) && !isNaN(data41))) && (isFinite(data41)))){
const err127 = {instancePath:instancePath+"/state/receipt/proposal/spec/digest/" + i3,schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/spec/properties/digest/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err127];
}
else {
vErrors.push(err127);
}
errors++;
}
if(errors === _errs112){
if((typeof data41 == "number") && (isFinite(data41))){
if(data41 > 255 || isNaN(data41)){
const err128 = {instancePath:instancePath+"/state/receipt/proposal/spec/digest/" + i3,schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/spec/properties/digest/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err128];
}
else {
vErrors.push(err128);
}
errors++;
}
else {
if(data41 < 0 || isNaN(data41)){
const err129 = {instancePath:instancePath+"/state/receipt/proposal/spec/digest/" + i3,schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/spec/properties/digest/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid19 = _errs112 === errors;
if(!valid19){
break;
}
}
}
}
}
else {
const err130 = {instancePath:instancePath+"/state/receipt/proposal/spec/digest",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/spec/properties/digest/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err130];
}
else {
vErrors.push(err130);
}
errors++;
}
}
var valid18 = _errs110 === errors;
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
const err131 = {instancePath:instancePath+"/state/receipt/proposal/spec",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/properties/spec/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err131];
}
else {
vErrors.push(err131);
}
errors++;
}
}
var valid16 = _errs103 === errors;
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
}
}
else {
const err132 = {instancePath:instancePath+"/state/receipt/proposal",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/proposal/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err132];
}
else {
vErrors.push(err132);
}
errors++;
}
}
var valid15 = _errs88 === errors;
}
else {
var valid15 = true;
}
if(valid15){
if(data29.phase !== undefined){
let data42 = data29.phase;
const _errs114 = errors;
if(typeof data42 !== "string"){
const err133 = {instancePath:instancePath+"/state/receipt/phase",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/phase/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err133];
}
else {
vErrors.push(err133);
}
errors++;
}
if(!((((data42 === "staging") || (data42 === "applied")) || (data42 === "conflict")) || (data42 === "abandoned"))){
const err134 = {instancePath:instancePath+"/state/receipt/phase",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/phase/enum",keyword:"enum",params:{allowedValues: schema57.oneOf[1].properties.state.properties.receipt.anyOf[0].properties.phase.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err134];
}
else {
vErrors.push(err134);
}
errors++;
}
var valid15 = _errs114 === errors;
}
else {
var valid15 = true;
}
if(valid15){
if(data29.input !== undefined){
let data43 = data29.input;
const _errs116 = errors;
if(!(((typeof data43 == "number") && (!(data43 % 1) && !isNaN(data43))) && (isFinite(data43)))){
const err135 = {instancePath:instancePath+"/state/receipt/input",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/input/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err135];
}
else {
vErrors.push(err135);
}
errors++;
}
if(errors === _errs116){
if((typeof data43 == "number") && (isFinite(data43))){
if(data43 > 9007199254740991 || isNaN(data43)){
const err136 = {instancePath:instancePath+"/state/receipt/input",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/input/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err136];
}
else {
vErrors.push(err136);
}
errors++;
}
else {
if(data43 < 0 || isNaN(data43)){
const err137 = {instancePath:instancePath+"/state/receipt/input",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/input/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err137];
}
else {
vErrors.push(err137);
}
errors++;
}
}
}
}
var valid15 = _errs116 === errors;
}
else {
var valid15 = true;
}
if(valid15){
if(data29.owns_record !== undefined){
const _errs118 = errors;
if(typeof data29.owns_record !== "boolean"){
const err138 = {instancePath:instancePath+"/state/receipt/owns_record",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/properties/owns_record/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err138];
}
else {
vErrors.push(err138);
}
errors++;
}
var valid15 = _errs118 === errors;
}
else {
var valid15 = true;
}
}
}
}
}
}
}
else {
const err139 = {instancePath:instancePath+"/state/receipt",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err139];
}
else {
vErrors.push(err139);
}
errors++;
}
}
var _valid4 = _errs85 === errors;
valid14 = valid14 || _valid4;
const _errs120 = errors;
if(data29 !== null){
const err140 = {instancePath:instancePath+"/state/receipt",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err140];
}
else {
vErrors.push(err140);
}
errors++;
}
var _valid4 = _errs120 === errors;
valid14 = valid14 || _valid4;
if(!valid14){
const err141 = {instancePath:instancePath+"/state/receipt",schemaPath:"#/oneOf/1/properties/state/properties/receipt/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err141];
}
else {
vErrors.push(err141);
}
errors++;
}
else {
errors = _errs84;
if(vErrors !== null){
if(_errs84){
vErrors.length = _errs84;
}
else {
vErrors = null;
}
}
}
var valid5 = _errs83 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data6.upload !== undefined){
let data45 = data6.upload;
const _errs122 = errors;
const _errs123 = errors;
let valid20 = false;
const _errs124 = errors;
if(errors === _errs124){
if(data45 && typeof data45 == "object" && !Array.isArray(data45)){
let missing11;
if((((data45.written === undefined) && (missing11 = "written")) || ((data45.first_half === undefined) && (missing11 = "first_half"))) || ((data45.state === undefined) && (missing11 = "state"))){
const err142 = {instancePath:instancePath+"/state/upload",schemaPath:"#/oneOf/1/properties/state/properties/upload/anyOf/0/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
if(vErrors === null){
vErrors = [err142];
}
else {
vErrors.push(err142);
}
errors++;
}
else {
const _errs126 = errors;
for(const key11 in data45){
if(!(((key11 === "written") || (key11 === "first_half")) || (key11 === "state"))){
const err143 = {instancePath:instancePath+"/state/upload",schemaPath:"#/oneOf/1/properties/state/properties/upload/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err143];
}
else {
vErrors.push(err143);
}
errors++;
break;
}
}
if(_errs126 === errors){
if(data45.written !== undefined){
let data46 = data45.written;
const _errs127 = errors;
if(!(((typeof data46 == "number") && (!(data46 % 1) && !isNaN(data46))) && (isFinite(data46)))){
const err144 = {instancePath:instancePath+"/state/upload/written",schemaPath:"#/oneOf/1/properties/state/properties/upload/anyOf/0/properties/written/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err144];
}
else {
vErrors.push(err144);
}
errors++;
}
if(errors === _errs127){
if((typeof data46 == "number") && (isFinite(data46))){
if(data46 > 4294967295 || isNaN(data46)){
const err145 = {instancePath:instancePath+"/state/upload/written",schemaPath:"#/oneOf/1/properties/state/properties/upload/anyOf/0/properties/written/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err145];
}
else {
vErrors.push(err145);
}
errors++;
}
else {
if(data46 < 0 || isNaN(data46)){
const err146 = {instancePath:instancePath+"/state/upload/written",schemaPath:"#/oneOf/1/properties/state/properties/upload/anyOf/0/properties/written/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid21 = _errs127 === errors;
}
else {
var valid21 = true;
}
if(valid21){
if(data45.first_half !== undefined){
const _errs129 = errors;
if(typeof data45.first_half !== "boolean"){
const err147 = {instancePath:instancePath+"/state/upload/first_half",schemaPath:"#/oneOf/1/properties/state/properties/upload/anyOf/0/properties/first_half/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err147];
}
else {
vErrors.push(err147);
}
errors++;
}
var valid21 = _errs129 === errors;
}
else {
var valid21 = true;
}
if(valid21){
if(data45.state !== undefined){
let data48 = data45.state;
const _errs131 = errors;
if(typeof data48 !== "string"){
const err148 = {instancePath:instancePath+"/state/upload/state",schemaPath:"#/oneOf/1/properties/state/properties/upload/anyOf/0/properties/state/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err148];
}
else {
vErrors.push(err148);
}
errors++;
}
if(!((((data48 === "staging") || (data48 === "published")) || (data48 === "abandoned")) || (data48 === "retired"))){
const err149 = {instancePath:instancePath+"/state/upload/state",schemaPath:"#/oneOf/1/properties/state/properties/upload/anyOf/0/properties/state/enum",keyword:"enum",params:{allowedValues: schema57.oneOf[1].properties.state.properties.upload.anyOf[0].properties.state.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err149];
}
else {
vErrors.push(err149);
}
errors++;
}
var valid21 = _errs131 === errors;
}
else {
var valid21 = true;
}
}
}
}
}
}
else {
const err150 = {instancePath:instancePath+"/state/upload",schemaPath:"#/oneOf/1/properties/state/properties/upload/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err150];
}
else {
vErrors.push(err150);
}
errors++;
}
}
var _valid5 = _errs124 === errors;
valid20 = valid20 || _valid5;
const _errs133 = errors;
if(data45 !== null){
const err151 = {instancePath:instancePath+"/state/upload",schemaPath:"#/oneOf/1/properties/state/properties/upload/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err151];
}
else {
vErrors.push(err151);
}
errors++;
}
var _valid5 = _errs133 === errors;
valid20 = valid20 || _valid5;
if(!valid20){
const err152 = {instancePath:instancePath+"/state/upload",schemaPath:"#/oneOf/1/properties/state/properties/upload/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err152];
}
else {
vErrors.push(err152);
}
errors++;
}
else {
errors = _errs123;
if(vErrors !== null){
if(_errs123){
vErrors.length = _errs123;
}
else {
vErrors = null;
}
}
}
var valid5 = _errs122 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data6.disposition !== undefined){
let data49 = data6.disposition;
const _errs135 = errors;
const _errs136 = errors;
let valid22 = false;
const _errs137 = errors;
if(errors === _errs137){
if(typeof data49 === "string"){
if(func2(data49) > 512){
const err153 = {instancePath:instancePath+"/state/disposition",schemaPath:"#/oneOf/1/properties/state/properties/disposition/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err153];
}
else {
vErrors.push(err153);
}
errors++;
}
else {
if(!pattern102.test(data49)){
const err154 = {instancePath:instancePath+"/state/disposition",schemaPath:"#/oneOf/1/properties/state/properties/disposition/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
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
const err155 = {instancePath:instancePath+"/state/disposition",schemaPath:"#/oneOf/1/properties/state/properties/disposition/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err155];
}
else {
vErrors.push(err155);
}
errors++;
}
}
var _valid6 = _errs137 === errors;
valid22 = valid22 || _valid6;
const _errs139 = errors;
if(data49 !== null){
const err156 = {instancePath:instancePath+"/state/disposition",schemaPath:"#/oneOf/1/properties/state/properties/disposition/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err156];
}
else {
vErrors.push(err156);
}
errors++;
}
var _valid6 = _errs139 === errors;
valid22 = valid22 || _valid6;
if(!valid22){
const err157 = {instancePath:instancePath+"/state/disposition",schemaPath:"#/oneOf/1/properties/state/properties/disposition/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err157];
}
else {
vErrors.push(err157);
}
errors++;
}
else {
errors = _errs136;
if(vErrors !== null){
if(_errs136){
vErrors.length = _errs136;
}
else {
vErrors = null;
}
}
}
var valid5 = _errs135 === errors;
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
else {
const err158 = {instancePath:instancePath+"/state",schemaPath:"#/oneOf/1/properties/state/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err159 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err159];
}
else {
vErrors.push(err159);
}
errors++;
}
}
var _valid0 = _errs21 === errors;
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
const err160 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err160];
}
else {
vErrors.push(err160);
}
errors++;
validate39.errors = vErrors;
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
validate39.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate39.evaluated = {"dynamicProps":true,"dynamicItems":false};
