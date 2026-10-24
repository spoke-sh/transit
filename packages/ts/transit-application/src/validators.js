// Generated; no runtime code generation or eval.
import lengthModule from "ajv/dist/runtime/ucs2length.js";
const ucs2length = lengthModule.default ?? lengthModule;
"use strict";
export const Definition = validate93;
const schema20 = {"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","const":1},"name":{"$ref":"https://transit.invalid/generated-validator/0"},"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"revision":{"$ref":"https://transit.invalid/generated-validator/2"},"components":{"$ref":"https://transit.invalid/generated-validator/3"},"entry":{"$ref":"https://transit.invalid/generated-validator/0"},"theme":{"$ref":"https://transit.invalid/generated-validator/0"},"themes":{"type":"array","maxItems":2,"items":{"$ref":"#/$defs/Theme"}},"screens":{"type":"array","maxItems":16,"items":{"$ref":"#/$defs/Screen"}},"bindings":{"type":"array","maxItems":16,"items":{"$ref":"#/$defs/Binding"}},"actions":{"type":"array","maxItems":16,"items":{"$ref":"#/$defs/Action"}}},"required":["name","realm","revision","entry","theme","themes","screens","bindings","actions"]};
const func1 = Object.prototype.hasOwnProperty;
const schema21 = {"type":"string","minLength":1,"maxLength":64,"pattern":"^[A-Za-z_][A-Za-z_0-9]*$"};
const func2 = ucs2length;
const pattern3 = new RegExp("^[A-Za-z_][A-Za-z_0-9]*$", "u");

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
if(typeof data === "string"){
if(func2(data) > 64){
validate54.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 64},message:"must NOT have more than 64 characters"}];
return false;
}
else {
if(func2(data) < 1){
validate54.errors = [{instancePath,schemaPath:"#/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"}];
return false;
}
else {
if(!pattern3.test(data)){
validate54.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^[A-Za-z_][A-Za-z_0-9]*$"},message:"must match pattern \""+"^[A-Za-z_][A-Za-z_0-9]*$"+"\""}];
return false;
}
}
}
}
else {
validate54.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate54.errors = vErrors;
return errors === 0;
}
validate54.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema22 = {"type":"integer","minimum":0,"maximum":9007199254740991};

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
if(data > 9007199254740991 || isNaN(data)){
validate56.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
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

const schema23 = {"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20};
const pattern4 = new RegExp("^(0|[1-9][0-9]*)$", "u");

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
if(func2(data) > 20){
validate58.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern4.test(data)){
validate58.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
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

const schema24 = {"type":"integer","minimum":0,"maximum":65535};

function validate60(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate60.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate60.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 65535 || isNaN(data)){
validate60.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate60.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate60.errors = vErrors;
return errors === 0;
}
validate60.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema25 = {"type":"object","additionalProperties":false,"properties":{"name":{"$ref":"https://transit.invalid/generated-validator/0"},"density":{"type":"string","enum":["comfortable","compact"]}},"required":["name","density"]};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.name === undefined) && (missing0 = "name")) || ((data.density === undefined) && (missing0 = "density"))){
validate64.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "name") || (key0 === "density"))){
validate64.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.name !== undefined){
const _errs2 = errors;
if(!(validate54(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.density !== undefined){
let data1 = data.density;
const _errs3 = errors;
if(typeof data1 !== "string"){
validate64.errors = [{instancePath:instancePath+"/density",schemaPath:"#/properties/density/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((data1 === "comfortable") || (data1 === "compact"))){
validate64.errors = [{instancePath:instancePath+"/density",schemaPath:"#/properties/density/enum",keyword:"enum",params:{allowedValues: schema25.properties.density.enum},message:"must be equal to one of the allowed values"}];
return false;
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
validate64.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate64.errors = vErrors;
return errors === 0;
}
validate64.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema26 = {"type":"object","additionalProperties":false,"properties":{"name":{"$ref":"https://transit.invalid/generated-validator/0"},"path":{"type":"string","minLength":1,"maxLength":128,"pattern":"^/[A-Za-z_0-9/-]*$"},"label":{"$ref":"https://transit.invalid/generated-validator/4"},"area":{"type":"string","enum":["workspace","operations"]},"renderer":{"type":"string","enum":["atlas","worksheet","records","activity","definition","operations","work_items"]},"binding":{"$ref":"https://transit.invalid/generated-validator/0"}},"required":["name","path","label","area","renderer","binding"]};
const schema27 = {"type":"string","minLength":1,"maxLength":128};

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
if(typeof data === "string"){
if(func2(data) > 128){
validate69.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 128},message:"must NOT have more than 128 characters"}];
return false;
}
else {
if(func2(data) < 1){
validate69.errors = [{instancePath,schemaPath:"#/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"}];
return false;
}
}
}
else {
validate69.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate69.errors = vErrors;
return errors === 0;
}
validate69.evaluated = {"dynamicProps":false,"dynamicItems":false};

const pattern5 = new RegExp("^/[A-Za-z_0-9/-]*$", "u");

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
if(((((((data.name === undefined) && (missing0 = "name")) || ((data.path === undefined) && (missing0 = "path"))) || ((data.label === undefined) && (missing0 = "label"))) || ((data.area === undefined) && (missing0 = "area"))) || ((data.renderer === undefined) && (missing0 = "renderer"))) || ((data.binding === undefined) && (missing0 = "binding"))){
validate67.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "name") || (key0 === "path")) || (key0 === "label")) || (key0 === "area")) || (key0 === "renderer")) || (key0 === "binding"))){
validate67.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.name !== undefined){
const _errs2 = errors;
if(!(validate54(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.path !== undefined){
let data1 = data.path;
const _errs3 = errors;
if(errors === _errs3){
if(typeof data1 === "string"){
if(func2(data1) > 128){
validate67.errors = [{instancePath:instancePath+"/path",schemaPath:"#/properties/path/maxLength",keyword:"maxLength",params:{limit: 128},message:"must NOT have more than 128 characters"}];
return false;
}
else {
if(func2(data1) < 1){
validate67.errors = [{instancePath:instancePath+"/path",schemaPath:"#/properties/path/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"}];
return false;
}
else {
if(!pattern5.test(data1)){
validate67.errors = [{instancePath:instancePath+"/path",schemaPath:"#/properties/path/pattern",keyword:"pattern",params:{pattern: "^/[A-Za-z_0-9/-]*$"},message:"must match pattern \""+"^/[A-Za-z_0-9/-]*$"+"\""}];
return false;
}
}
}
}
else {
validate67.errors = [{instancePath:instancePath+"/path",schemaPath:"#/properties/path/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.label !== undefined){
const _errs5 = errors;
if(!(validate69(data.label, {instancePath:instancePath+"/label",parentData:data,parentDataProperty:"label",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate69.errors : vErrors.concat(validate69.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.area !== undefined){
let data3 = data.area;
const _errs6 = errors;
if(typeof data3 !== "string"){
validate67.errors = [{instancePath:instancePath+"/area",schemaPath:"#/properties/area/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((data3 === "workspace") || (data3 === "operations"))){
validate67.errors = [{instancePath:instancePath+"/area",schemaPath:"#/properties/area/enum",keyword:"enum",params:{allowedValues: schema26.properties.area.enum},message:"must be equal to one of the allowed values"}];
return false;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.renderer !== undefined){
let data4 = data.renderer;
const _errs8 = errors;
if(typeof data4 !== "string"){
validate67.errors = [{instancePath:instancePath+"/renderer",schemaPath:"#/properties/renderer/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((data4 === "atlas") || (data4 === "worksheet")) || (data4 === "records")) || (data4 === "activity")) || (data4 === "definition")) || (data4 === "operations")) || (data4 === "work_items"))){
validate67.errors = [{instancePath:instancePath+"/renderer",schemaPath:"#/properties/renderer/enum",keyword:"enum",params:{allowedValues: schema26.properties.renderer.enum},message:"must be equal to one of the allowed values"}];
return false;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.binding !== undefined){
const _errs10 = errors;
if(!(validate54(data.binding, {instancePath:instancePath+"/binding",parentData:data,parentDataProperty:"binding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
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
else {
validate67.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate67.errors = vErrors;
return errors === 0;
}
validate67.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema28 = {"type":"object","additionalProperties":false,"properties":{"name":{"$ref":"https://transit.invalid/generated-validator/0"},"source":{"oneOf":[{"type":"object","additionalProperties":false,"required":["inspection"],"properties":{"inspection":{"type":"object","additionalProperties":false,"properties":{"projection":{"type":"string","enum":["atlas","resources","processes","records","capabilities","activity"]},"page_budget":{"$ref":"https://transit.invalid/generated-validator/5"}},"required":["projection"]}}},{"type":"object","additionalProperties":false,"required":["query"],"properties":{"query":{"type":"object","additionalProperties":false,"properties":{"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"name":{"$ref":"https://transit.invalid/generated-validator/0"},"source_kind":{"type":"string","enum":["table","kv","document"]},"schema":{"$ref":"https://transit.invalid/generated-validator/6"},"profile":{"type":"string","enum":["unified_v1"]},"sql":{"type":"string","minLength":1,"maxLength":4096},"refresh":{"type":"string","enum":["snapshot","follow"]},"starts":{"$ref":"https://transit.invalid/generated-validator/5"}},"required":["resource","name","source_kind","schema","profile","sql"]}}},{"type":"object","additionalProperties":false,"required":["command"],"properties":{"command":{"type":"object","additionalProperties":false,"properties":{"service":{"$ref":"https://transit.invalid/generated-validator/1"},"target":{"$ref":"https://transit.invalid/generated-validator/1"},"revision":{"$ref":"https://transit.invalid/generated-validator/1"},"codec":{"$ref":"https://transit.invalid/generated-validator/3"}},"required":["service","target","revision","codec"]}}}]}},"required":["name","source"]};
const schema29 = {"type":"integer","minimum":0,"maximum":255};

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
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate75.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate75.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate75.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate75.errors = vErrors;
return errors === 0;
}
validate75.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema30 = {"type":"array","minItems":32,"maxItems":32,"items":{"$ref":"https://transit.invalid/generated-validator/5"}};

function validate79(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate79.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 32){
validate79.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"}];
return false;
}
else {
if(data.length < 32){
validate79.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate75(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate75.errors : vErrors.concat(validate75.errors);
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
validate79.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate79.errors = vErrors;
return errors === 0;
}
validate79.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate73(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate73.evaluated;
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
validate73.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "name") || (key0 === "source"))){
validate73.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.name !== undefined){
const _errs2 = errors;
if(!(validate54(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.source !== undefined){
let data1 = data.source;
const _errs3 = errors;
const _errs4 = errors;
let valid1 = false;
let passing0 = null;
const _errs5 = errors;
if(errors === _errs5){
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
const _errs7 = errors;
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
if(_errs7 === errors){
if(data1.inspection !== undefined){
let data2 = data1.inspection;
const _errs8 = errors;
if(errors === _errs8){
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
const _errs10 = errors;
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
if(_errs10 === errors){
if(data2.projection !== undefined){
let data3 = data2.projection;
const _errs11 = errors;
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
const err5 = {instancePath:instancePath+"/source/inspection/projection",schemaPath:"#/properties/source/oneOf/0/properties/inspection/properties/projection/enum",keyword:"enum",params:{allowedValues: schema28.properties.source.oneOf[0].properties.inspection.properties.projection.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err5];
}
else {
vErrors.push(err5);
}
errors++;
}
var valid3 = _errs11 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data2.page_budget !== undefined){
const _errs13 = errors;
if(!(validate75(data2.page_budget, {instancePath:instancePath+"/source/inspection/page_budget",parentData:data2,parentDataProperty:"page_budget",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate75.errors : vErrors.concat(validate75.errors);
errors = vErrors.length;
}
var valid3 = _errs13 === errors;
}
else {
var valid3 = true;
}
}
}
}
}
else {
const err6 = {instancePath:instancePath+"/source/inspection",schemaPath:"#/properties/source/oneOf/0/properties/inspection/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err7 = {instancePath:instancePath+"/source",schemaPath:"#/properties/source/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err7];
}
else {
vErrors.push(err7);
}
errors++;
}
}
var _valid0 = _errs5 === errors;
if(_valid0){
valid1 = true;
passing0 = 0;
var props0 = true;
}
const _errs14 = errors;
if(errors === _errs14){
if(data1 && typeof data1 == "object" && !Array.isArray(data1)){
let missing3;
if((data1.query === undefined) && (missing3 = "query")){
const err8 = {instancePath:instancePath+"/source",schemaPath:"#/properties/source/oneOf/1/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
if(vErrors === null){
vErrors = [err8];
}
else {
vErrors.push(err8);
}
errors++;
}
else {
const _errs16 = errors;
for(const key3 in data1){
if(!(key3 === "query")){
const err9 = {instancePath:instancePath+"/source",schemaPath:"#/properties/source/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
break;
}
}
if(_errs16 === errors){
if(data1.query !== undefined){
let data5 = data1.query;
const _errs17 = errors;
if(errors === _errs17){
if(data5 && typeof data5 == "object" && !Array.isArray(data5)){
let missing4;
if(((((((data5.resource === undefined) && (missing4 = "resource")) || ((data5.name === undefined) && (missing4 = "name"))) || ((data5.source_kind === undefined) && (missing4 = "source_kind"))) || ((data5.schema === undefined) && (missing4 = "schema"))) || ((data5.profile === undefined) && (missing4 = "profile"))) || ((data5.sql === undefined) && (missing4 = "sql"))){
const err10 = {instancePath:instancePath+"/source/query",schemaPath:"#/properties/source/oneOf/1/properties/query/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
}
else {
const _errs19 = errors;
for(const key4 in data5){
if(!((((((((key4 === "resource") || (key4 === "name")) || (key4 === "source_kind")) || (key4 === "schema")) || (key4 === "profile")) || (key4 === "sql")) || (key4 === "refresh")) || (key4 === "starts"))){
const err11 = {instancePath:instancePath+"/source/query",schemaPath:"#/properties/source/oneOf/1/properties/query/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(_errs19 === errors){
if(data5.resource !== undefined){
const _errs20 = errors;
if(!(validate56(data5.resource, {instancePath:instancePath+"/source/query/resource",parentData:data5,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid5 = _errs20 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data5.name !== undefined){
const _errs21 = errors;
if(!(validate54(data5.name, {instancePath:instancePath+"/source/query/name",parentData:data5,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid5 = _errs21 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data5.source_kind !== undefined){
let data8 = data5.source_kind;
const _errs22 = errors;
if(typeof data8 !== "string"){
const err12 = {instancePath:instancePath+"/source/query/source_kind",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/source_kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
}
if(!(((data8 === "table") || (data8 === "kv")) || (data8 === "document"))){
const err13 = {instancePath:instancePath+"/source/query/source_kind",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/source_kind/enum",keyword:"enum",params:{allowedValues: schema28.properties.source.oneOf[1].properties.query.properties.source_kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err13];
}
else {
vErrors.push(err13);
}
errors++;
}
var valid5 = _errs22 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data5.schema !== undefined){
const _errs24 = errors;
if(!(validate79(data5.schema, {instancePath:instancePath+"/source/query/schema",parentData:data5,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate79.errors : vErrors.concat(validate79.errors);
errors = vErrors.length;
}
var valid5 = _errs24 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data5.profile !== undefined){
let data10 = data5.profile;
const _errs25 = errors;
if(typeof data10 !== "string"){
const err14 = {instancePath:instancePath+"/source/query/profile",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/profile/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err14];
}
else {
vErrors.push(err14);
}
errors++;
}
if(!(data10 === "unified_v1")){
const err15 = {instancePath:instancePath+"/source/query/profile",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/profile/enum",keyword:"enum",params:{allowedValues: schema28.properties.source.oneOf[1].properties.query.properties.profile.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
}
var valid5 = _errs25 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data5.sql !== undefined){
let data11 = data5.sql;
const _errs27 = errors;
if(errors === _errs27){
if(typeof data11 === "string"){
if(func2(data11) > 4096){
const err16 = {instancePath:instancePath+"/source/query/sql",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/sql/maxLength",keyword:"maxLength",params:{limit: 4096},message:"must NOT have more than 4096 characters"};
if(vErrors === null){
vErrors = [err16];
}
else {
vErrors.push(err16);
}
errors++;
}
else {
if(func2(data11) < 1){
const err17 = {instancePath:instancePath+"/source/query/sql",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/sql/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"};
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
const err18 = {instancePath:instancePath+"/source/query/sql",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/sql/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
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
if(data5.refresh !== undefined){
let data12 = data5.refresh;
const _errs29 = errors;
if(typeof data12 !== "string"){
const err19 = {instancePath:instancePath+"/source/query/refresh",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/refresh/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
}
if(!((data12 === "snapshot") || (data12 === "follow"))){
const err20 = {instancePath:instancePath+"/source/query/refresh",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/refresh/enum",keyword:"enum",params:{allowedValues: schema28.properties.source.oneOf[1].properties.query.properties.refresh.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err20];
}
else {
vErrors.push(err20);
}
errors++;
}
var valid5 = _errs29 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data5.starts !== undefined){
const _errs31 = errors;
if(!(validate75(data5.starts, {instancePath:instancePath+"/source/query/starts",parentData:data5,parentDataProperty:"starts",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate75.errors : vErrors.concat(validate75.errors);
errors = vErrors.length;
}
var valid5 = _errs31 === errors;
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
const err21 = {instancePath:instancePath+"/source/query",schemaPath:"#/properties/source/oneOf/1/properties/query/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err22 = {instancePath:instancePath+"/source",schemaPath:"#/properties/source/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const _errs32 = errors;
if(errors === _errs32){
if(data1 && typeof data1 == "object" && !Array.isArray(data1)){
let missing5;
if((data1.command === undefined) && (missing5 = "command")){
const err23 = {instancePath:instancePath+"/source",schemaPath:"#/properties/source/oneOf/2/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
if(vErrors === null){
vErrors = [err23];
}
else {
vErrors.push(err23);
}
errors++;
}
else {
const _errs34 = errors;
for(const key5 in data1){
if(!(key5 === "command")){
const err24 = {instancePath:instancePath+"/source",schemaPath:"#/properties/source/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(_errs34 === errors){
if(data1.command !== undefined){
let data14 = data1.command;
const _errs35 = errors;
if(errors === _errs35){
if(data14 && typeof data14 == "object" && !Array.isArray(data14)){
let missing6;
if(((((data14.service === undefined) && (missing6 = "service")) || ((data14.target === undefined) && (missing6 = "target"))) || ((data14.revision === undefined) && (missing6 = "revision"))) || ((data14.codec === undefined) && (missing6 = "codec"))){
const err25 = {instancePath:instancePath+"/source/command",schemaPath:"#/properties/source/oneOf/2/properties/command/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
if(vErrors === null){
vErrors = [err25];
}
else {
vErrors.push(err25);
}
errors++;
}
else {
const _errs37 = errors;
for(const key6 in data14){
if(!((((key6 === "service") || (key6 === "target")) || (key6 === "revision")) || (key6 === "codec"))){
const err26 = {instancePath:instancePath+"/source/command",schemaPath:"#/properties/source/oneOf/2/properties/command/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
if(_errs37 === errors){
if(data14.service !== undefined){
const _errs38 = errors;
if(!(validate56(data14.service, {instancePath:instancePath+"/source/command/service",parentData:data14,parentDataProperty:"service",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid7 = _errs38 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data14.target !== undefined){
const _errs39 = errors;
if(!(validate56(data14.target, {instancePath:instancePath+"/source/command/target",parentData:data14,parentDataProperty:"target",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid7 = _errs39 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data14.revision !== undefined){
const _errs40 = errors;
if(!(validate56(data14.revision, {instancePath:instancePath+"/source/command/revision",parentData:data14,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid7 = _errs40 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data14.codec !== undefined){
const _errs41 = errors;
if(!(validate60(data14.codec, {instancePath:instancePath+"/source/command/codec",parentData:data14,parentDataProperty:"codec",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate60.errors : vErrors.concat(validate60.errors);
errors = vErrors.length;
}
var valid7 = _errs41 === errors;
}
else {
var valid7 = true;
}
}
}
}
}
}
}
else {
const err27 = {instancePath:instancePath+"/source/command",schemaPath:"#/properties/source/oneOf/2/properties/command/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err28 = {instancePath:instancePath+"/source",schemaPath:"#/properties/source/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err28];
}
else {
vErrors.push(err28);
}
errors++;
}
}
var _valid0 = _errs32 === errors;
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
const err29 = {instancePath:instancePath+"/source",schemaPath:"#/properties/source/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err29];
}
else {
vErrors.push(err29);
}
errors++;
validate73.errors = vErrors;
return false;
}
else {
errors = _errs4;
if(vErrors !== null){
if(_errs4){
vErrors.length = _errs4;
}
else {
vErrors = null;
}
}
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
validate73.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate73.errors = vErrors;
return errors === 0;
}
validate73.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema31 = {"type":"object","additionalProperties":false,"properties":{"name":{"$ref":"https://transit.invalid/generated-validator/0"},"label":{"$ref":"https://transit.invalid/generated-validator/4"},"target":{"oneOf":[{"type":"object","additionalProperties":false,"required":["navigate"],"properties":{"navigate":{"type":"string","maxLength":256}}},{"type":"object","additionalProperties":false,"required":["command"],"properties":{"command":{"type":"string","maxLength":256}}},{"type":"object","additionalProperties":false,"required":["follow"],"properties":{"follow":{"type":"string","maxLength":256}}}]}},"required":["name","label","target"]};

function validate88(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate88.evaluated;
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
validate88.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "name") || (key0 === "label")) || (key0 === "target"))){
validate88.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.name !== undefined){
const _errs2 = errors;
if(!(validate54(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.label !== undefined){
const _errs3 = errors;
if(!(validate69(data.label, {instancePath:instancePath+"/label",parentData:data,parentDataProperty:"label",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate69.errors : vErrors.concat(validate69.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.target !== undefined){
let data2 = data.target;
const _errs4 = errors;
const _errs5 = errors;
let valid1 = false;
let passing0 = null;
const _errs6 = errors;
if(errors === _errs6){
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
const _errs8 = errors;
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
if(_errs8 === errors){
if(data2.navigate !== undefined){
let data3 = data2.navigate;
const _errs9 = errors;
if(errors === _errs9){
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
var _valid0 = _errs6 === errors;
if(_valid0){
valid1 = true;
passing0 = 0;
var props0 = true;
}
const _errs11 = errors;
if(errors === _errs11){
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
const _errs13 = errors;
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
if(_errs13 === errors){
if(data2.command !== undefined){
let data4 = data2.command;
const _errs14 = errors;
if(errors === _errs14){
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
var _valid0 = _errs11 === errors;
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
const _errs16 = errors;
if(errors === _errs16){
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
const _errs18 = errors;
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
if(_errs18 === errors){
if(data2.follow !== undefined){
let data5 = data2.follow;
const _errs19 = errors;
if(errors === _errs19){
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
var _valid0 = _errs16 === errors;
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
validate88.errors = vErrors;
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
}
else {
validate88.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate88.errors = vErrors;
return errors === 0;
}
validate88.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate93(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate93.evaluated;
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
validate93.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema20.properties, key0))){
validate93.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
let data0 = data.version;
const _errs2 = errors;
if(!(((typeof data0 == "number") && (!(data0 % 1) && !isNaN(data0))) && (isFinite(data0)))){
validate93.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(1 !== data0){
validate93.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"}];
return false;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.name !== undefined){
const _errs4 = errors;
if(!(validate54(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.realm !== undefined){
const _errs5 = errors;
if(!(validate56(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate58(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.components !== undefined){
const _errs7 = errors;
if(!(validate60(data.components, {instancePath:instancePath+"/components",parentData:data,parentDataProperty:"components",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate60.errors : vErrors.concat(validate60.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.entry !== undefined){
const _errs8 = errors;
if(!(validate54(data.entry, {instancePath:instancePath+"/entry",parentData:data,parentDataProperty:"entry",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.theme !== undefined){
const _errs9 = errors;
if(!(validate54(data.theme, {instancePath:instancePath+"/theme",parentData:data,parentDataProperty:"theme",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.themes !== undefined){
let data7 = data.themes;
const _errs10 = errors;
if(errors === _errs10){
if(Array.isArray(data7)){
if(data7.length > 2){
validate93.errors = [{instancePath:instancePath+"/themes",schemaPath:"#/properties/themes/maxItems",keyword:"maxItems",params:{limit: 2},message:"must NOT have more than 2 items"}];
return false;
}
else {
var valid1 = true;
const len0 = data7.length;
for(let i0=0; i0<len0; i0++){
const _errs12 = errors;
if(!(validate64(data7[i0], {instancePath:instancePath+"/themes/" + i0,parentData:data7,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
errors = vErrors.length;
}
var valid1 = _errs12 === errors;
if(!valid1){
break;
}
}
}
}
else {
validate93.errors = [{instancePath:instancePath+"/themes",schemaPath:"#/properties/themes/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid0 = _errs10 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.screens !== undefined){
let data9 = data.screens;
const _errs13 = errors;
if(errors === _errs13){
if(Array.isArray(data9)){
if(data9.length > 16){
validate93.errors = [{instancePath:instancePath+"/screens",schemaPath:"#/properties/screens/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
var valid2 = true;
const len1 = data9.length;
for(let i1=0; i1<len1; i1++){
const _errs15 = errors;
if(!(validate67(data9[i1], {instancePath:instancePath+"/screens/" + i1,parentData:data9,parentDataProperty:i1,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate67.errors : vErrors.concat(validate67.errors);
errors = vErrors.length;
}
var valid2 = _errs15 === errors;
if(!valid2){
break;
}
}
}
}
else {
validate93.errors = [{instancePath:instancePath+"/screens",schemaPath:"#/properties/screens/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid0 = _errs13 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.bindings !== undefined){
let data11 = data.bindings;
const _errs16 = errors;
if(errors === _errs16){
if(Array.isArray(data11)){
if(data11.length > 16){
validate93.errors = [{instancePath:instancePath+"/bindings",schemaPath:"#/properties/bindings/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
var valid3 = true;
const len2 = data11.length;
for(let i2=0; i2<len2; i2++){
const _errs18 = errors;
if(!(validate73(data11[i2], {instancePath:instancePath+"/bindings/" + i2,parentData:data11,parentDataProperty:i2,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate73.errors : vErrors.concat(validate73.errors);
errors = vErrors.length;
}
var valid3 = _errs18 === errors;
if(!valid3){
break;
}
}
}
}
else {
validate93.errors = [{instancePath:instancePath+"/bindings",schemaPath:"#/properties/bindings/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid0 = _errs16 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.actions !== undefined){
let data13 = data.actions;
const _errs19 = errors;
if(errors === _errs19){
if(Array.isArray(data13)){
if(data13.length > 16){
validate93.errors = [{instancePath:instancePath+"/actions",schemaPath:"#/properties/actions/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
var valid4 = true;
const len3 = data13.length;
for(let i3=0; i3<len3; i3++){
const _errs21 = errors;
if(!(validate88(data13[i3], {instancePath:instancePath+"/actions/" + i3,parentData:data13,parentDataProperty:i3,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate88.errors : vErrors.concat(validate88.errors);
errors = vErrors.length;
}
var valid4 = _errs21 === errors;
if(!valid4){
break;
}
}
}
}
else {
validate93.errors = [{instancePath:instancePath+"/actions",schemaPath:"#/properties/actions/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid0 = _errs19 === errors;
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
validate93.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate93.errors = vErrors;
return errors === 0;
}
validate93.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Theme = validate104;

function validate104(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate104.evaluated;
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
validate104.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "name") || (key0 === "density"))){
validate104.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.name !== undefined){
const _errs2 = errors;
if(!(validate54(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.density !== undefined){
let data1 = data.density;
const _errs3 = errors;
if(typeof data1 !== "string"){
validate104.errors = [{instancePath:instancePath+"/density",schemaPath:"#/properties/density/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((data1 === "comfortable") || (data1 === "compact"))){
validate104.errors = [{instancePath:instancePath+"/density",schemaPath:"#/properties/density/enum",keyword:"enum",params:{allowedValues: schema25.properties.density.enum},message:"must be equal to one of the allowed values"}];
return false;
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
validate104.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate104.errors = vErrors;
return errors === 0;
}
validate104.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Screen = validate106;

function validate106(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate106.evaluated;
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
validate106.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "name") || (key0 === "path")) || (key0 === "label")) || (key0 === "area")) || (key0 === "renderer")) || (key0 === "binding"))){
validate106.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.name !== undefined){
const _errs2 = errors;
if(!(validate54(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.path !== undefined){
let data1 = data.path;
const _errs3 = errors;
if(errors === _errs3){
if(typeof data1 === "string"){
if(func2(data1) > 128){
validate106.errors = [{instancePath:instancePath+"/path",schemaPath:"#/properties/path/maxLength",keyword:"maxLength",params:{limit: 128},message:"must NOT have more than 128 characters"}];
return false;
}
else {
if(func2(data1) < 1){
validate106.errors = [{instancePath:instancePath+"/path",schemaPath:"#/properties/path/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"}];
return false;
}
else {
if(!pattern5.test(data1)){
validate106.errors = [{instancePath:instancePath+"/path",schemaPath:"#/properties/path/pattern",keyword:"pattern",params:{pattern: "^/[A-Za-z_0-9/-]*$"},message:"must match pattern \""+"^/[A-Za-z_0-9/-]*$"+"\""}];
return false;
}
}
}
}
else {
validate106.errors = [{instancePath:instancePath+"/path",schemaPath:"#/properties/path/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.label !== undefined){
const _errs5 = errors;
if(!(validate69(data.label, {instancePath:instancePath+"/label",parentData:data,parentDataProperty:"label",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate69.errors : vErrors.concat(validate69.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.area !== undefined){
let data3 = data.area;
const _errs6 = errors;
if(typeof data3 !== "string"){
validate106.errors = [{instancePath:instancePath+"/area",schemaPath:"#/properties/area/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((data3 === "workspace") || (data3 === "operations"))){
validate106.errors = [{instancePath:instancePath+"/area",schemaPath:"#/properties/area/enum",keyword:"enum",params:{allowedValues: schema26.properties.area.enum},message:"must be equal to one of the allowed values"}];
return false;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.renderer !== undefined){
let data4 = data.renderer;
const _errs8 = errors;
if(typeof data4 !== "string"){
validate106.errors = [{instancePath:instancePath+"/renderer",schemaPath:"#/properties/renderer/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((data4 === "atlas") || (data4 === "worksheet")) || (data4 === "records")) || (data4 === "activity")) || (data4 === "definition")) || (data4 === "operations")) || (data4 === "work_items"))){
validate106.errors = [{instancePath:instancePath+"/renderer",schemaPath:"#/properties/renderer/enum",keyword:"enum",params:{allowedValues: schema26.properties.renderer.enum},message:"must be equal to one of the allowed values"}];
return false;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.binding !== undefined){
const _errs10 = errors;
if(!(validate54(data.binding, {instancePath:instancePath+"/binding",parentData:data,parentDataProperty:"binding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
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
else {
validate106.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate106.errors = vErrors;
return errors === 0;
}
validate106.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Binding = validate110;

function validate110(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate110.evaluated;
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
validate110.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "name") || (key0 === "source"))){
validate110.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.name !== undefined){
const _errs2 = errors;
if(!(validate54(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.source !== undefined){
let data1 = data.source;
const _errs3 = errors;
const _errs4 = errors;
let valid1 = false;
let passing0 = null;
const _errs5 = errors;
if(errors === _errs5){
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
const _errs7 = errors;
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
if(_errs7 === errors){
if(data1.inspection !== undefined){
let data2 = data1.inspection;
const _errs8 = errors;
if(errors === _errs8){
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
const _errs10 = errors;
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
if(_errs10 === errors){
if(data2.projection !== undefined){
let data3 = data2.projection;
const _errs11 = errors;
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
const err5 = {instancePath:instancePath+"/source/inspection/projection",schemaPath:"#/properties/source/oneOf/0/properties/inspection/properties/projection/enum",keyword:"enum",params:{allowedValues: schema28.properties.source.oneOf[0].properties.inspection.properties.projection.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err5];
}
else {
vErrors.push(err5);
}
errors++;
}
var valid3 = _errs11 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data2.page_budget !== undefined){
const _errs13 = errors;
if(!(validate75(data2.page_budget, {instancePath:instancePath+"/source/inspection/page_budget",parentData:data2,parentDataProperty:"page_budget",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate75.errors : vErrors.concat(validate75.errors);
errors = vErrors.length;
}
var valid3 = _errs13 === errors;
}
else {
var valid3 = true;
}
}
}
}
}
else {
const err6 = {instancePath:instancePath+"/source/inspection",schemaPath:"#/properties/source/oneOf/0/properties/inspection/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err7 = {instancePath:instancePath+"/source",schemaPath:"#/properties/source/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err7];
}
else {
vErrors.push(err7);
}
errors++;
}
}
var _valid0 = _errs5 === errors;
if(_valid0){
valid1 = true;
passing0 = 0;
var props0 = true;
}
const _errs14 = errors;
if(errors === _errs14){
if(data1 && typeof data1 == "object" && !Array.isArray(data1)){
let missing3;
if((data1.query === undefined) && (missing3 = "query")){
const err8 = {instancePath:instancePath+"/source",schemaPath:"#/properties/source/oneOf/1/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
if(vErrors === null){
vErrors = [err8];
}
else {
vErrors.push(err8);
}
errors++;
}
else {
const _errs16 = errors;
for(const key3 in data1){
if(!(key3 === "query")){
const err9 = {instancePath:instancePath+"/source",schemaPath:"#/properties/source/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
break;
}
}
if(_errs16 === errors){
if(data1.query !== undefined){
let data5 = data1.query;
const _errs17 = errors;
if(errors === _errs17){
if(data5 && typeof data5 == "object" && !Array.isArray(data5)){
let missing4;
if(((((((data5.resource === undefined) && (missing4 = "resource")) || ((data5.name === undefined) && (missing4 = "name"))) || ((data5.source_kind === undefined) && (missing4 = "source_kind"))) || ((data5.schema === undefined) && (missing4 = "schema"))) || ((data5.profile === undefined) && (missing4 = "profile"))) || ((data5.sql === undefined) && (missing4 = "sql"))){
const err10 = {instancePath:instancePath+"/source/query",schemaPath:"#/properties/source/oneOf/1/properties/query/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
}
else {
const _errs19 = errors;
for(const key4 in data5){
if(!((((((((key4 === "resource") || (key4 === "name")) || (key4 === "source_kind")) || (key4 === "schema")) || (key4 === "profile")) || (key4 === "sql")) || (key4 === "refresh")) || (key4 === "starts"))){
const err11 = {instancePath:instancePath+"/source/query",schemaPath:"#/properties/source/oneOf/1/properties/query/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(_errs19 === errors){
if(data5.resource !== undefined){
const _errs20 = errors;
if(!(validate56(data5.resource, {instancePath:instancePath+"/source/query/resource",parentData:data5,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid5 = _errs20 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data5.name !== undefined){
const _errs21 = errors;
if(!(validate54(data5.name, {instancePath:instancePath+"/source/query/name",parentData:data5,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid5 = _errs21 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data5.source_kind !== undefined){
let data8 = data5.source_kind;
const _errs22 = errors;
if(typeof data8 !== "string"){
const err12 = {instancePath:instancePath+"/source/query/source_kind",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/source_kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
}
if(!(((data8 === "table") || (data8 === "kv")) || (data8 === "document"))){
const err13 = {instancePath:instancePath+"/source/query/source_kind",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/source_kind/enum",keyword:"enum",params:{allowedValues: schema28.properties.source.oneOf[1].properties.query.properties.source_kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err13];
}
else {
vErrors.push(err13);
}
errors++;
}
var valid5 = _errs22 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data5.schema !== undefined){
const _errs24 = errors;
if(!(validate79(data5.schema, {instancePath:instancePath+"/source/query/schema",parentData:data5,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate79.errors : vErrors.concat(validate79.errors);
errors = vErrors.length;
}
var valid5 = _errs24 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data5.profile !== undefined){
let data10 = data5.profile;
const _errs25 = errors;
if(typeof data10 !== "string"){
const err14 = {instancePath:instancePath+"/source/query/profile",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/profile/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err14];
}
else {
vErrors.push(err14);
}
errors++;
}
if(!(data10 === "unified_v1")){
const err15 = {instancePath:instancePath+"/source/query/profile",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/profile/enum",keyword:"enum",params:{allowedValues: schema28.properties.source.oneOf[1].properties.query.properties.profile.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
}
var valid5 = _errs25 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data5.sql !== undefined){
let data11 = data5.sql;
const _errs27 = errors;
if(errors === _errs27){
if(typeof data11 === "string"){
if(func2(data11) > 4096){
const err16 = {instancePath:instancePath+"/source/query/sql",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/sql/maxLength",keyword:"maxLength",params:{limit: 4096},message:"must NOT have more than 4096 characters"};
if(vErrors === null){
vErrors = [err16];
}
else {
vErrors.push(err16);
}
errors++;
}
else {
if(func2(data11) < 1){
const err17 = {instancePath:instancePath+"/source/query/sql",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/sql/minLength",keyword:"minLength",params:{limit: 1},message:"must NOT have fewer than 1 characters"};
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
const err18 = {instancePath:instancePath+"/source/query/sql",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/sql/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
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
if(data5.refresh !== undefined){
let data12 = data5.refresh;
const _errs29 = errors;
if(typeof data12 !== "string"){
const err19 = {instancePath:instancePath+"/source/query/refresh",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/refresh/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
}
if(!((data12 === "snapshot") || (data12 === "follow"))){
const err20 = {instancePath:instancePath+"/source/query/refresh",schemaPath:"#/properties/source/oneOf/1/properties/query/properties/refresh/enum",keyword:"enum",params:{allowedValues: schema28.properties.source.oneOf[1].properties.query.properties.refresh.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err20];
}
else {
vErrors.push(err20);
}
errors++;
}
var valid5 = _errs29 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data5.starts !== undefined){
const _errs31 = errors;
if(!(validate75(data5.starts, {instancePath:instancePath+"/source/query/starts",parentData:data5,parentDataProperty:"starts",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate75.errors : vErrors.concat(validate75.errors);
errors = vErrors.length;
}
var valid5 = _errs31 === errors;
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
const err21 = {instancePath:instancePath+"/source/query",schemaPath:"#/properties/source/oneOf/1/properties/query/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err22 = {instancePath:instancePath+"/source",schemaPath:"#/properties/source/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const _errs32 = errors;
if(errors === _errs32){
if(data1 && typeof data1 == "object" && !Array.isArray(data1)){
let missing5;
if((data1.command === undefined) && (missing5 = "command")){
const err23 = {instancePath:instancePath+"/source",schemaPath:"#/properties/source/oneOf/2/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
if(vErrors === null){
vErrors = [err23];
}
else {
vErrors.push(err23);
}
errors++;
}
else {
const _errs34 = errors;
for(const key5 in data1){
if(!(key5 === "command")){
const err24 = {instancePath:instancePath+"/source",schemaPath:"#/properties/source/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(_errs34 === errors){
if(data1.command !== undefined){
let data14 = data1.command;
const _errs35 = errors;
if(errors === _errs35){
if(data14 && typeof data14 == "object" && !Array.isArray(data14)){
let missing6;
if(((((data14.service === undefined) && (missing6 = "service")) || ((data14.target === undefined) && (missing6 = "target"))) || ((data14.revision === undefined) && (missing6 = "revision"))) || ((data14.codec === undefined) && (missing6 = "codec"))){
const err25 = {instancePath:instancePath+"/source/command",schemaPath:"#/properties/source/oneOf/2/properties/command/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
if(vErrors === null){
vErrors = [err25];
}
else {
vErrors.push(err25);
}
errors++;
}
else {
const _errs37 = errors;
for(const key6 in data14){
if(!((((key6 === "service") || (key6 === "target")) || (key6 === "revision")) || (key6 === "codec"))){
const err26 = {instancePath:instancePath+"/source/command",schemaPath:"#/properties/source/oneOf/2/properties/command/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
if(_errs37 === errors){
if(data14.service !== undefined){
const _errs38 = errors;
if(!(validate56(data14.service, {instancePath:instancePath+"/source/command/service",parentData:data14,parentDataProperty:"service",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid7 = _errs38 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data14.target !== undefined){
const _errs39 = errors;
if(!(validate56(data14.target, {instancePath:instancePath+"/source/command/target",parentData:data14,parentDataProperty:"target",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid7 = _errs39 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data14.revision !== undefined){
const _errs40 = errors;
if(!(validate56(data14.revision, {instancePath:instancePath+"/source/command/revision",parentData:data14,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid7 = _errs40 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data14.codec !== undefined){
const _errs41 = errors;
if(!(validate60(data14.codec, {instancePath:instancePath+"/source/command/codec",parentData:data14,parentDataProperty:"codec",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate60.errors : vErrors.concat(validate60.errors);
errors = vErrors.length;
}
var valid7 = _errs41 === errors;
}
else {
var valid7 = true;
}
}
}
}
}
}
}
else {
const err27 = {instancePath:instancePath+"/source/command",schemaPath:"#/properties/source/oneOf/2/properties/command/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err28 = {instancePath:instancePath+"/source",schemaPath:"#/properties/source/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err28];
}
else {
vErrors.push(err28);
}
errors++;
}
}
var _valid0 = _errs32 === errors;
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
const err29 = {instancePath:instancePath+"/source",schemaPath:"#/properties/source/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err29];
}
else {
vErrors.push(err29);
}
errors++;
validate110.errors = vErrors;
return false;
}
else {
errors = _errs4;
if(vErrors !== null){
if(_errs4){
vErrors.length = _errs4;
}
else {
vErrors = null;
}
}
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
validate110.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate110.errors = vErrors;
return errors === 0;
}
validate110.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Action = validate121;

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
if((((data.name === undefined) && (missing0 = "name")) || ((data.label === undefined) && (missing0 = "label"))) || ((data.target === undefined) && (missing0 = "target"))){
validate121.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "name") || (key0 === "label")) || (key0 === "target"))){
validate121.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.name !== undefined){
const _errs2 = errors;
if(!(validate54(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.label !== undefined){
const _errs3 = errors;
if(!(validate69(data.label, {instancePath:instancePath+"/label",parentData:data,parentDataProperty:"label",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate69.errors : vErrors.concat(validate69.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.target !== undefined){
let data2 = data.target;
const _errs4 = errors;
const _errs5 = errors;
let valid1 = false;
let passing0 = null;
const _errs6 = errors;
if(errors === _errs6){
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
const _errs8 = errors;
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
if(_errs8 === errors){
if(data2.navigate !== undefined){
let data3 = data2.navigate;
const _errs9 = errors;
if(errors === _errs9){
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
var _valid0 = _errs6 === errors;
if(_valid0){
valid1 = true;
passing0 = 0;
var props0 = true;
}
const _errs11 = errors;
if(errors === _errs11){
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
const _errs13 = errors;
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
if(_errs13 === errors){
if(data2.command !== undefined){
let data4 = data2.command;
const _errs14 = errors;
if(errors === _errs14){
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
var _valid0 = _errs11 === errors;
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
const _errs16 = errors;
if(errors === _errs16){
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
const _errs18 = errors;
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
if(_errs18 === errors){
if(data2.follow !== undefined){
let data5 = data2.follow;
const _errs19 = errors;
if(errors === _errs19){
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
var _valid0 = _errs16 === errors;
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
validate121.errors = vErrors;
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

export const Configuration = validate130;
const schema37 = {"type":"object","additionalProperties":false,"properties":{"application":{"$ref":"https://transit.invalid/generated-validator/1"},"namespace":{"$ref":"https://transit.invalid/generated-validator/2"},"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"administrator":{"$ref":"https://transit.invalid/generated-validator/1"},"name_digest":{"$ref":"https://transit.invalid/generated-validator/6"}},"required":["application","namespace","realm","administrator","name_digest"]};

function validate130(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate130.evaluated;
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
validate130.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "application") || (key0 === "namespace")) || (key0 === "realm")) || (key0 === "administrator")) || (key0 === "name_digest"))){
validate130.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.application !== undefined){
const _errs2 = errors;
if(!(validate56(data.application, {instancePath:instancePath+"/application",parentData:data,parentDataProperty:"application",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.namespace !== undefined){
const _errs3 = errors;
if(!(validate58(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
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
if(!(validate56(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.administrator !== undefined){
const _errs5 = errors;
if(!(validate56(data.administrator, {instancePath:instancePath+"/administrator",parentData:data,parentDataProperty:"administrator",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.name_digest !== undefined){
const _errs6 = errors;
if(!(validate79(data.name_digest, {instancePath:instancePath+"/name_digest",parentData:data,parentDataProperty:"name_digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate79.errors : vErrors.concat(validate79.errors);
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
validate130.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate130.errors = vErrors;
return errors === 0;
}
validate130.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Policy = validate138;
const schema39 = {"type":"object","additionalProperties":false,"properties":{"revision":{"$ref":"https://transit.invalid/generated-validator/2"},"publish":{"type":"boolean"}},"required":["revision","publish"]};

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
if(((data.revision === undefined) && (missing0 = "revision")) || ((data.publish === undefined) && (missing0 = "publish"))){
validate138.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "revision") || (key0 === "publish"))){
validate138.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.revision !== undefined){
const _errs2 = errors;
if(!(validate58(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.publish !== undefined){
const _errs3 = errors;
if(typeof data.publish !== "boolean"){
validate138.errors = [{instancePath:instancePath+"/publish",schemaPath:"#/properties/publish/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
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

export const Proposal = validate152;
const schema41 = {"type":"object","additionalProperties":false,"properties":{"operation":{"$ref":"https://transit.invalid/generated-validator/2"},"record":{"$ref":"https://transit.invalid/generated-validator/2"},"expected":{"$ref":"https://transit.invalid/generated-validator/2"},"expected_digest":{"$ref":"https://transit.invalid/generated-validator/6"},"revision":{"$ref":"https://transit.invalid/generated-validator/2"},"spec":{"$ref":"https://transit.invalid/generated-validator/10"}},"required":["operation","record","expected","expected_digest","revision","spec"]};
const schema42 = {"type":"object","additionalProperties":false,"properties":{"format":{"$ref":"https://transit.invalid/generated-validator/9"},"length":{"$ref":"https://transit.invalid/generated-validator/9"},"digest":{"$ref":"https://transit.invalid/generated-validator/6"}},"required":["format","length","digest"]};
const schema43 = {"type":"integer","minimum":0,"maximum":4294967295};

function validate147(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate147.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate147.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 4294967295 || isNaN(data)){
validate147.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate147.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate147.errors = vErrors;
return errors === 0;
}
validate147.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.format === undefined) && (missing0 = "format")) || ((data.length === undefined) && (missing0 = "length"))) || ((data.digest === undefined) && (missing0 = "digest"))){
validate146.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "format") || (key0 === "length")) || (key0 === "digest"))){
validate146.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.format !== undefined){
const _errs2 = errors;
if(!(validate147(data.format, {instancePath:instancePath+"/format",parentData:data,parentDataProperty:"format",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate147.errors : vErrors.concat(validate147.errors);
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
if(!(validate147(data.length, {instancePath:instancePath+"/length",parentData:data,parentDataProperty:"length",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate147.errors : vErrors.concat(validate147.errors);
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
if(!(validate79(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate79.errors : vErrors.concat(validate79.errors);
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
validate146.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate146.errors = vErrors;
return errors === 0;
}
validate146.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate152(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate152.evaluated;
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
validate152.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "operation") || (key0 === "record")) || (key0 === "expected")) || (key0 === "expected_digest")) || (key0 === "revision")) || (key0 === "spec"))){
validate152.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.operation !== undefined){
const _errs2 = errors;
if(!(validate58(data.operation, {instancePath:instancePath+"/operation",parentData:data,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.record !== undefined){
const _errs3 = errors;
if(!(validate58(data.record, {instancePath:instancePath+"/record",parentData:data,parentDataProperty:"record",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.expected !== undefined){
const _errs4 = errors;
if(!(validate58(data.expected, {instancePath:instancePath+"/expected",parentData:data,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.expected_digest !== undefined){
const _errs5 = errors;
if(!(validate79(data.expected_digest, {instancePath:instancePath+"/expected_digest",parentData:data,parentDataProperty:"expected_digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate79.errors : vErrors.concat(validate79.errors);
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
if(!(validate58(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.spec !== undefined){
const _errs7 = errors;
if(!(validate146(data.spec, {instancePath:instancePath+"/spec",parentData:data,parentDataProperty:"spec",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
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
validate152.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate152.errors = vErrors;
return errors === 0;
}
validate152.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Receipt = validate176;
const schema45 = {"type":"object","additionalProperties":false,"properties":{"proposal":{"$ref":"https://transit.invalid/generated-validator/11"},"phase":{"$ref":"https://transit.invalid/generated-validator/12"},"input":{"$ref":"https://transit.invalid/generated-validator/1"},"owns_record":{"type":"boolean"},"conflict_basis":{"$ref":"https://transit.invalid/generated-validator/17"}},"required":["proposal","phase","input","owns_record"]};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((data.operation === undefined) && (missing0 = "operation")) || ((data.record === undefined) && (missing0 = "record"))) || ((data.expected === undefined) && (missing0 = "expected"))) || ((data.expected_digest === undefined) && (missing0 = "expected_digest"))) || ((data.revision === undefined) && (missing0 = "revision"))) || ((data.spec === undefined) && (missing0 = "spec"))){
validate140.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "operation") || (key0 === "record")) || (key0 === "expected")) || (key0 === "expected_digest")) || (key0 === "revision")) || (key0 === "spec"))){
validate140.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.operation !== undefined){
const _errs2 = errors;
if(!(validate58(data.operation, {instancePath:instancePath+"/operation",parentData:data,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.record !== undefined){
const _errs3 = errors;
if(!(validate58(data.record, {instancePath:instancePath+"/record",parentData:data,parentDataProperty:"record",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.expected !== undefined){
const _errs4 = errors;
if(!(validate58(data.expected, {instancePath:instancePath+"/expected",parentData:data,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.expected_digest !== undefined){
const _errs5 = errors;
if(!(validate79(data.expected_digest, {instancePath:instancePath+"/expected_digest",parentData:data,parentDataProperty:"expected_digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate79.errors : vErrors.concat(validate79.errors);
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
if(!(validate58(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.spec !== undefined){
const _errs7 = errors;
if(!(validate146(data.spec, {instancePath:instancePath+"/spec",parentData:data,parentDataProperty:"spec",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
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
validate140.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate140.errors = vErrors;
return errors === 0;
}
validate140.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema46 = {"type":"string","enum":["staging","applied","conflict","abandoned"]};

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
if(typeof data !== "string"){
validate161.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((data === "staging") || (data === "applied")) || (data === "conflict")) || (data === "abandoned"))){
validate161.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema46.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate161.errors = vErrors;
return errors === 0;
}
validate161.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema47 = {"oneOf":[{"$ref":"https://transit.invalid/generated-validator/13"},{"$ref":"https://transit.invalid/generated-validator/14"},{"$ref":"https://transit.invalid/generated-validator/16"}]};
const schema48 = {"type":"object","additionalProperties":false,"required":["none"],"properties":{"none":{"type":"object","maxProperties":0}}};

function validate165(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate165.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.none === undefined) && (missing0 = "none")){
validate165.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "none")){
validate165.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.none !== undefined){
let data0 = data.none;
const _errs2 = errors;
if(errors === _errs2){
if(data0 && typeof data0 == "object" && !Array.isArray(data0)){
if(Object.keys(data0).length > 0){
validate165.errors = [{instancePath:instancePath+"/none",schemaPath:"#/properties/none/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"}];
return false;
}
}
else {
validate165.errors = [{instancePath:instancePath+"/none",schemaPath:"#/properties/none/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
}
}
}
}
else {
validate165.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate165.errors = vErrors;
return errors === 0;
}
validate165.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema49 = {"type":"object","additionalProperties":false,"required":["absent"],"properties":{"absent":{"type":"object","maxProperties":0}}};

function validate167(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate167.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.absent === undefined) && (missing0 = "absent")){
validate167.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "absent")){
validate167.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.absent !== undefined){
let data0 = data.absent;
const _errs2 = errors;
if(errors === _errs2){
if(data0 && typeof data0 == "object" && !Array.isArray(data0)){
if(Object.keys(data0).length > 0){
validate167.errors = [{instancePath:instancePath+"/absent",schemaPath:"#/properties/absent/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"}];
return false;
}
}
else {
validate167.errors = [{instancePath:instancePath+"/absent",schemaPath:"#/properties/absent/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
}
}
}
}
else {
validate167.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate167.errors = vErrors;
return errors === 0;
}
validate167.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema50 = {"type":"object","additionalProperties":false,"required":["head"],"properties":{"head":{"$ref":"https://transit.invalid/generated-validator/15"}}};
const schema51 = {"type":"object","additionalProperties":false,"properties":{"revision":{"$ref":"https://transit.invalid/generated-validator/2"},"digest":{"$ref":"https://transit.invalid/generated-validator/6"}},"required":["revision","digest"]};

function validate170(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate170.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.revision === undefined) && (missing0 = "revision")) || ((data.digest === undefined) && (missing0 = "digest"))){
validate170.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "revision") || (key0 === "digest"))){
validate170.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.revision !== undefined){
const _errs2 = errors;
if(!(validate58(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
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
if(!(validate79(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate79.errors : vErrors.concat(validate79.errors);
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
validate170.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate170.errors = vErrors;
return errors === 0;
}
validate170.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate169(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate169.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.head === undefined) && (missing0 = "head")){
validate169.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "head")){
validate169.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.head !== undefined){
if(!(validate170(data.head, {instancePath:instancePath+"/head",parentData:data,parentDataProperty:"head",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate170.errors : vErrors.concat(validate170.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate169.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate169.errors = vErrors;
return errors === 0;
}
validate169.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate164(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate164.evaluated;
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
if(!(validate165(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate165.errors : vErrors.concat(validate165.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs2 = errors;
if(!(validate167(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate167.errors : vErrors.concat(validate167.errors);
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
if(!(validate169(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate169.errors : vErrors.concat(validate169.errors);
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
validate164.errors = vErrors;
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
validate164.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate164.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate176(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate176.evaluated;
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
validate176.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "proposal") || (key0 === "phase")) || (key0 === "input")) || (key0 === "owns_record")) || (key0 === "conflict_basis"))){
validate176.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.proposal !== undefined){
const _errs2 = errors;
if(!(validate140(data.proposal, {instancePath:instancePath+"/proposal",parentData:data,parentDataProperty:"proposal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate140.errors : vErrors.concat(validate140.errors);
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
if(!(validate161(data.phase, {instancePath:instancePath+"/phase",parentData:data,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.input !== undefined){
const _errs4 = errors;
if(!(validate56(data.input, {instancePath:instancePath+"/input",parentData:data,parentDataProperty:"input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.owns_record !== undefined){
const _errs5 = errors;
if(typeof data.owns_record !== "boolean"){
validate176.errors = [{instancePath:instancePath+"/owns_record",schemaPath:"#/properties/owns_record/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.conflict_basis !== undefined){
const _errs7 = errors;
if(!(validate164(data.conflict_basis, {instancePath:instancePath+"/conflict_basis",parentData:data,parentDataProperty:"conflict_basis",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate164.errors : vErrors.concat(validate164.errors);
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
else {
validate176.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate176.errors = vErrors;
return errors === 0;
}
validate176.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Head = validate188;
const schema53 = {"type":"object","additionalProperties":false,"properties":{"revision":{"$ref":"https://transit.invalid/generated-validator/2"},"record":{"$ref":"https://transit.invalid/generated-validator/2"},"spec":{"$ref":"https://transit.invalid/generated-validator/10"},"principal":{"$ref":"https://transit.invalid/generated-validator/1"},"operation":{"$ref":"https://transit.invalid/generated-validator/2"},"input":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["revision","record","spec","principal","operation","input"]};

function validate188(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate188.evaluated;
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
validate188.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "revision") || (key0 === "record")) || (key0 === "spec")) || (key0 === "principal")) || (key0 === "operation")) || (key0 === "input"))){
validate188.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.revision !== undefined){
const _errs2 = errors;
if(!(validate58(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.record !== undefined){
const _errs3 = errors;
if(!(validate58(data.record, {instancePath:instancePath+"/record",parentData:data,parentDataProperty:"record",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.spec !== undefined){
const _errs4 = errors;
if(!(validate146(data.spec, {instancePath:instancePath+"/spec",parentData:data,parentDataProperty:"spec",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
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
if(!(validate56(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.operation !== undefined){
const _errs6 = errors;
if(!(validate58(data.operation, {instancePath:instancePath+"/operation",parentData:data,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.input !== undefined){
const _errs7 = errors;
if(!(validate56(data.input, {instancePath:instancePath+"/input",parentData:data,parentDataProperty:"input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
validate188.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate188.errors = vErrors;
return errors === 0;
}
validate188.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Command = validate225;
const schema55 = {"oneOf":[{"$ref":"https://transit.invalid/generated-validator/20"},{"$ref":"https://transit.invalid/generated-validator/22"},{"$ref":"https://transit.invalid/generated-validator/23"},{"$ref":"https://transit.invalid/generated-validator/26"},{"$ref":"https://transit.invalid/generated-validator/27"},{"$ref":"https://transit.invalid/generated-validator/28"},{"$ref":"https://transit.invalid/generated-validator/29"}]};
const schema56 = {"type":"object","additionalProperties":false,"required":["initialize"],"properties":{"initialize":{"type":"object","maxProperties":0}}};

function validate196(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate196.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.initialize === undefined) && (missing0 = "initialize")){
validate196.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "initialize")){
validate196.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.initialize !== undefined){
let data0 = data.initialize;
const _errs2 = errors;
if(errors === _errs2){
if(data0 && typeof data0 == "object" && !Array.isArray(data0)){
if(Object.keys(data0).length > 0){
validate196.errors = [{instancePath:instancePath+"/initialize",schemaPath:"#/properties/initialize/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"}];
return false;
}
}
else {
validate196.errors = [{instancePath:instancePath+"/initialize",schemaPath:"#/properties/initialize/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
}
}
}
}
else {
validate196.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate196.errors = vErrors;
return errors === 0;
}
validate196.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema57 = {"type":"object","additionalProperties":false,"required":["policy"],"properties":{"policy":{"$ref":"https://transit.invalid/generated-validator/21"}}};
const schema58 = {"type":"object","additionalProperties":false,"properties":{"principal":{"$ref":"https://transit.invalid/generated-validator/1"},"expected":{"$ref":"https://transit.invalid/generated-validator/2"},"next":{"$ref":"https://transit.invalid/generated-validator/8"}},"required":["principal","expected","next"]};

function validate136(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate136.evaluated;
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
validate136.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "revision") || (key0 === "publish"))){
validate136.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.revision !== undefined){
const _errs2 = errors;
if(!(validate58(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.publish !== undefined){
const _errs3 = errors;
if(typeof data.publish !== "boolean"){
validate136.errors = [{instancePath:instancePath+"/publish",schemaPath:"#/properties/publish/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
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
validate136.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate136.errors = vErrors;
return errors === 0;
}
validate136.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate199(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate199.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.principal === undefined) && (missing0 = "principal")) || ((data.expected === undefined) && (missing0 = "expected"))) || ((data.next === undefined) && (missing0 = "next"))){
validate199.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "principal") || (key0 === "expected")) || (key0 === "next"))){
validate199.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.principal !== undefined){
const _errs2 = errors;
if(!(validate56(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.expected !== undefined){
const _errs3 = errors;
if(!(validate58(data.expected, {instancePath:instancePath+"/expected",parentData:data,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.next !== undefined){
const _errs4 = errors;
if(!(validate136(data.next, {instancePath:instancePath+"/next",parentData:data,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate136.errors : vErrors.concat(validate136.errors);
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
validate199.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate199.errors = vErrors;
return errors === 0;
}
validate199.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate198(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate198.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.policy === undefined) && (missing0 = "policy")){
validate198.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "policy")){
validate198.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.policy !== undefined){
if(!(validate199(data.policy, {instancePath:instancePath+"/policy",parentData:data,parentDataProperty:"policy",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate199.errors : vErrors.concat(validate199.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate198.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate198.errors = vErrors;
return errors === 0;
}
validate198.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema59 = {"type":"object","additionalProperties":false,"required":["begin"],"properties":{"begin":{"$ref":"https://transit.invalid/generated-validator/11"}}};

function validate205(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate205.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.begin === undefined) && (missing0 = "begin")){
validate205.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "begin")){
validate205.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.begin !== undefined){
if(!(validate140(data.begin, {instancePath:instancePath+"/begin",parentData:data,parentDataProperty:"begin",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate140.errors : vErrors.concat(validate140.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate205.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate205.errors = vErrors;
return errors === 0;
}
validate205.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema60 = {"type":"object","additionalProperties":false,"required":["part"],"properties":{"part":{"$ref":"https://transit.invalid/generated-validator/25"}}};
const schema61 = {"type":"object","additionalProperties":false,"properties":{"operation":{"$ref":"https://transit.invalid/generated-validator/2"},"ordinal":{"$ref":"https://transit.invalid/generated-validator/9"},"second":{"type":"boolean"},"bytes":{"$ref":"https://transit.invalid/generated-validator/24"}},"required":["operation","ordinal","second","bytes"]};
const schema62 = {"type":"string","pattern":"^(?:[0-9a-f]{2})+$","maxLength":256};
const pattern7 = new RegExp("^(?:[0-9a-f]{2})+$", "u");

function validate212(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate212.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func2(data) > 256){
validate212.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"}];
return false;
}
else {
if(!pattern7.test(data)){
validate212.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})+$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})+$"+"\""}];
return false;
}
}
}
else {
validate212.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate212.errors = vErrors;
return errors === 0;
}
validate212.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate209(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate209.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.operation === undefined) && (missing0 = "operation")) || ((data.ordinal === undefined) && (missing0 = "ordinal"))) || ((data.second === undefined) && (missing0 = "second"))) || ((data.bytes === undefined) && (missing0 = "bytes"))){
validate209.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "operation") || (key0 === "ordinal")) || (key0 === "second")) || (key0 === "bytes"))){
validate209.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.operation !== undefined){
const _errs2 = errors;
if(!(validate58(data.operation, {instancePath:instancePath+"/operation",parentData:data,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
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
if(!(validate147(data.ordinal, {instancePath:instancePath+"/ordinal",parentData:data,parentDataProperty:"ordinal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate147.errors : vErrors.concat(validate147.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.second !== undefined){
const _errs4 = errors;
if(typeof data.second !== "boolean"){
validate209.errors = [{instancePath:instancePath+"/second",schemaPath:"#/properties/second/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.bytes !== undefined){
const _errs6 = errors;
if(!(validate212(data.bytes, {instancePath:instancePath+"/bytes",parentData:data,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate212.errors : vErrors.concat(validate212.errors);
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
else {
validate209.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate209.errors = vErrors;
return errors === 0;
}
validate209.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate208(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate208.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.part === undefined) && (missing0 = "part")){
validate208.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "part")){
validate208.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.part !== undefined){
if(!(validate209(data.part, {instancePath:instancePath+"/part",parentData:data,parentDataProperty:"part",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate209.errors : vErrors.concat(validate209.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate208.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate208.errors = vErrors;
return errors === 0;
}
validate208.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema63 = {"type":"object","additionalProperties":false,"required":["publish"],"properties":{"publish":{"$ref":"https://transit.invalid/generated-validator/2"}}};

function validate216(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate216.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.publish === undefined) && (missing0 = "publish")){
validate216.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "publish")){
validate216.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.publish !== undefined){
if(!(validate58(data.publish, {instancePath:instancePath+"/publish",parentData:data,parentDataProperty:"publish",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate216.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate216.errors = vErrors;
return errors === 0;
}
validate216.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema64 = {"type":"object","additionalProperties":false,"required":["abandon"],"properties":{"abandon":{"$ref":"https://transit.invalid/generated-validator/2"}}};

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
if((data.abandon === undefined) && (missing0 = "abandon")){
validate219.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "abandon")){
validate219.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.abandon !== undefined){
if(!(validate58(data.abandon, {instancePath:instancePath+"/abandon",parentData:data,parentDataProperty:"abandon",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
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

const schema65 = {"type":"object","additionalProperties":false,"required":["collect"],"properties":{"collect":{"$ref":"https://transit.invalid/generated-validator/2"}}};

function validate222(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate222.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.collect === undefined) && (missing0 = "collect")){
validate222.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "collect")){
validate222.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.collect !== undefined){
if(!(validate58(data.collect, {instancePath:instancePath+"/collect",parentData:data,parentDataProperty:"collect",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate222.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate222.errors = vErrors;
return errors === 0;
}
validate222.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
let passing0 = null;
const _errs1 = errors;
if(!(validate196(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate196.errors : vErrors.concat(validate196.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs2 = errors;
if(!(validate198(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate198.errors : vErrors.concat(validate198.errors);
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
if(!(validate205(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate205.errors : vErrors.concat(validate205.errors);
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
if(!(validate208(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate208.errors : vErrors.concat(validate208.errors);
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
if(!(validate216(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate216.errors : vErrors.concat(validate216.errors);
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
if(!(validate219(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate219.errors : vErrors.concat(validate219.errors);
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
const _errs7 = errors;
if(!(validate222(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate222.errors : vErrors.concat(validate222.errors);
errors = vErrors.length;
}
var _valid0 = _errs7 === errors;
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
const err0 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
validate225.errors = vErrors;
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
validate225.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate225.evaluated = {"dynamicProps":true,"dynamicItems":false};

export const Scope = validate239;
const schema67 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"application":{"$ref":"https://transit.invalid/generated-validator/1"},"pid":{"$ref":"https://transit.invalid/generated-validator/1"},"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"namespace":{"$ref":"https://transit.invalid/generated-validator/2"}},"required":["realm","application","pid","resource","namespace"]};

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
if((((((data.realm === undefined) && (missing0 = "realm")) || ((data.application === undefined) && (missing0 = "application"))) || ((data.pid === undefined) && (missing0 = "pid"))) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.namespace === undefined) && (missing0 = "namespace"))){
validate239.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "realm") || (key0 === "application")) || (key0 === "pid")) || (key0 === "resource")) || (key0 === "namespace"))){
validate239.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate56(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.application !== undefined){
const _errs3 = errors;
if(!(validate56(data.application, {instancePath:instancePath+"/application",parentData:data,parentDataProperty:"application",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.pid !== undefined){
const _errs4 = errors;
if(!(validate56(data.pid, {instancePath:instancePath+"/pid",parentData:data,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate56(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.namespace !== undefined){
const _errs6 = errors;
if(!(validate58(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
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
validate239.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate239.errors = vErrors;
return errors === 0;
}
validate239.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Prepared = validate251;
const schema69 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"https://transit.invalid/generated-validator/31"},"principal":{"$ref":"https://transit.invalid/generated-validator/1"},"sequence":{"$ref":"https://transit.invalid/generated-validator/2"},"command":{"$ref":"https://transit.invalid/generated-validator/30"},"digest":{"$ref":"https://transit.invalid/generated-validator/6"}},"required":["scope","principal","sequence","command","digest"]};

function validate233(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate233.evaluated;
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
validate233.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "realm") || (key0 === "application")) || (key0 === "pid")) || (key0 === "resource")) || (key0 === "namespace"))){
validate233.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate56(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.application !== undefined){
const _errs3 = errors;
if(!(validate56(data.application, {instancePath:instancePath+"/application",parentData:data,parentDataProperty:"application",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.pid !== undefined){
const _errs4 = errors;
if(!(validate56(data.pid, {instancePath:instancePath+"/pid",parentData:data,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate56(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.namespace !== undefined){
const _errs6 = errors;
if(!(validate58(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
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
validate233.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate233.errors = vErrors;
return errors === 0;
}
validate233.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate195(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate195.evaluated;
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
if(!(validate196(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate196.errors : vErrors.concat(validate196.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs2 = errors;
if(!(validate198(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate198.errors : vErrors.concat(validate198.errors);
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
if(!(validate205(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate205.errors : vErrors.concat(validate205.errors);
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
if(!(validate208(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate208.errors : vErrors.concat(validate208.errors);
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
if(!(validate216(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate216.errors : vErrors.concat(validate216.errors);
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
if(!(validate219(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate219.errors : vErrors.concat(validate219.errors);
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
const _errs7 = errors;
if(!(validate222(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate222.errors : vErrors.concat(validate222.errors);
errors = vErrors.length;
}
var _valid0 = _errs7 === errors;
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
const err0 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
validate195.errors = vErrors;
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
validate195.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate195.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate251(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate251.evaluated;
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
validate251.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "scope") || (key0 === "principal")) || (key0 === "sequence")) || (key0 === "command")) || (key0 === "digest"))){
validate251.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate233(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate233.errors : vErrors.concat(validate233.errors);
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
if(!(validate56(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.sequence !== undefined){
const _errs4 = errors;
if(!(validate58(data.sequence, {instancePath:instancePath+"/sequence",parentData:data,parentDataProperty:"sequence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.command !== undefined){
const _errs5 = errors;
if(!(validate195(data.command, {instancePath:instancePath+"/command",parentData:data,parentDataProperty:"command",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate195.errors : vErrors.concat(validate195.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.digest !== undefined){
const _errs6 = errors;
if(!(validate79(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate79.errors : vErrors.concat(validate79.errors);
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
validate251.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate251.errors = vErrors;
return errors === 0;
}
validate251.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Signed = validate262;
const schema71 = {"type":"object","additionalProperties":false,"properties":{"prepared":{"$ref":"https://transit.invalid/generated-validator/32"},"signature":{"$ref":"https://transit.invalid/generated-validator/33"}},"required":["prepared","signature"]};

function validate245(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate245.evaluated;
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
validate245.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "scope") || (key0 === "principal")) || (key0 === "sequence")) || (key0 === "command")) || (key0 === "digest"))){
validate245.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate233(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate233.errors : vErrors.concat(validate233.errors);
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
if(!(validate56(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.sequence !== undefined){
const _errs4 = errors;
if(!(validate58(data.sequence, {instancePath:instancePath+"/sequence",parentData:data,parentDataProperty:"sequence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.command !== undefined){
const _errs5 = errors;
if(!(validate195(data.command, {instancePath:instancePath+"/command",parentData:data,parentDataProperty:"command",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate195.errors : vErrors.concat(validate195.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.digest !== undefined){
const _errs6 = errors;
if(!(validate79(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate79.errors : vErrors.concat(validate79.errors);
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
validate245.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate245.errors = vErrors;
return errors === 0;
}
validate245.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema72 = {"type":"array","minItems":64,"maxItems":64,"items":{"$ref":"https://transit.invalid/generated-validator/5"}};

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
if(Array.isArray(data)){
if(data.length > 64){
validate259.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 64},message:"must NOT have more than 64 items"}];
return false;
}
else {
if(data.length < 64){
validate259.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 64},message:"must NOT have fewer than 64 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate75(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate75.errors : vErrors.concat(validate75.errors);
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
validate259.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate259.errors = vErrors;
return errors === 0;
}
validate259.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.prepared === undefined) && (missing0 = "prepared")) || ((data.signature === undefined) && (missing0 = "signature"))){
validate262.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "prepared") || (key0 === "signature"))){
validate262.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.prepared !== undefined){
const _errs2 = errors;
if(!(validate245(data.prepared, {instancePath:instancePath+"/prepared",parentData:data,parentDataProperty:"prepared",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate245.errors : vErrors.concat(validate245.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.signature !== undefined){
const _errs3 = errors;
if(!(validate259(data.signature, {instancePath:instancePath+"/signature",parentData:data,parentDataProperty:"signature",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate259.errors : vErrors.concat(validate259.errors);
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
validate262.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate262.errors = vErrors;
return errors === 0;
}
validate262.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const PreparedRead = validate280;
const schema74 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"https://transit.invalid/generated-validator/31"},"principal":{"$ref":"https://transit.invalid/generated-validator/1"},"selection":{"$ref":"https://transit.invalid/generated-validator/38"},"digest":{"$ref":"https://transit.invalid/generated-validator/6"}},"required":["scope","principal","selection","digest"]};
const schema75 = {"oneOf":[{"$ref":"https://transit.invalid/generated-validator/35"},{"$ref":"https://transit.invalid/generated-validator/37"}]};
const schema76 = {"type":"object","additionalProperties":false,"required":["identity"],"properties":{"identity":{"type":"object","maxProperties":0}}};

function validate269(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate269.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.identity === undefined) && (missing0 = "identity")){
validate269.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "identity")){
validate269.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.identity !== undefined){
let data0 = data.identity;
const _errs2 = errors;
if(errors === _errs2){
if(data0 && typeof data0 == "object" && !Array.isArray(data0)){
if(Object.keys(data0).length > 0){
validate269.errors = [{instancePath:instancePath+"/identity",schemaPath:"#/properties/identity/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"}];
return false;
}
}
else {
validate269.errors = [{instancePath:instancePath+"/identity",schemaPath:"#/properties/identity/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
}
}
}
}
else {
validate269.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate269.errors = vErrors;
return errors === 0;
}
validate269.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema77 = {"type":"object","additionalProperties":false,"required":["state"],"properties":{"state":{"$ref":"https://transit.invalid/generated-validator/36"}}};
const schema78 = {"type":"object","additionalProperties":false,"properties":{"operation":{"$ref":"https://transit.invalid/generated-validator/2"},"record":{"$ref":"https://transit.invalid/generated-validator/2"},"input":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":[]};

function validate272(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate272.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "operation") || (key0 === "record")) || (key0 === "input"))){
validate272.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.operation !== undefined){
const _errs2 = errors;
if(!(validate58(data.operation, {instancePath:instancePath+"/operation",parentData:data,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.record !== undefined){
const _errs3 = errors;
if(!(validate58(data.record, {instancePath:instancePath+"/record",parentData:data,parentDataProperty:"record",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.input !== undefined){
const _errs4 = errors;
if(!(validate56(data.input, {instancePath:instancePath+"/input",parentData:data,parentDataProperty:"input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
validate272.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate272.errors = vErrors;
return errors === 0;
}
validate272.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.state === undefined) && (missing0 = "state")){
validate271.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "state")){
validate271.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.state !== undefined){
if(!(validate272(data.state, {instancePath:instancePath+"/state",parentData:data,parentDataProperty:"state",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate272.errors : vErrors.concat(validate272.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate271.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate271.errors = vErrors;
return errors === 0;
}
validate271.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate268(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate268.evaluated;
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
if(!(validate269(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate269.errors : vErrors.concat(validate269.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs2 = errors;
if(!(validate271(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate271.errors : vErrors.concat(validate271.errors);
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
validate268.errors = vErrors;
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
validate268.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate268.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate280(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate280.evaluated;
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
validate280.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "scope") || (key0 === "principal")) || (key0 === "selection")) || (key0 === "digest"))){
validate280.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate233(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate233.errors : vErrors.concat(validate233.errors);
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
if(!(validate56(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.selection !== undefined){
const _errs4 = errors;
if(!(validate268(data.selection, {instancePath:instancePath+"/selection",parentData:data,parentDataProperty:"selection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate268.errors : vErrors.concat(validate268.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.digest !== undefined){
const _errs5 = errors;
if(!(validate79(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate79.errors : vErrors.concat(validate79.errors);
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
validate280.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate280.errors = vErrors;
return errors === 0;
}
validate280.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const SignedRead = validate288;
const schema80 = {"type":"object","additionalProperties":false,"properties":{"prepared":{"$ref":"https://transit.invalid/generated-validator/39"},"signature":{"$ref":"https://transit.invalid/generated-validator/33"}},"required":["prepared","signature"]};

function validate265(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate265.evaluated;
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
validate265.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "scope") || (key0 === "principal")) || (key0 === "selection")) || (key0 === "digest"))){
validate265.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate233(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate233.errors : vErrors.concat(validate233.errors);
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
if(!(validate56(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.selection !== undefined){
const _errs4 = errors;
if(!(validate268(data.selection, {instancePath:instancePath+"/selection",parentData:data,parentDataProperty:"selection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate268.errors : vErrors.concat(validate268.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.digest !== undefined){
const _errs5 = errors;
if(!(validate79(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate79.errors : vErrors.concat(validate79.errors);
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
validate265.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate265.errors = vErrors;
return errors === 0;
}
validate265.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(((data.prepared === undefined) && (missing0 = "prepared")) || ((data.signature === undefined) && (missing0 = "signature"))){
validate288.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "prepared") || (key0 === "signature"))){
validate288.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.prepared !== undefined){
const _errs2 = errors;
if(!(validate265(data.prepared, {instancePath:instancePath+"/prepared",parentData:data,parentDataProperty:"prepared",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate265.errors : vErrors.concat(validate265.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.signature !== undefined){
const _errs3 = errors;
if(!(validate259(data.signature, {instancePath:instancePath+"/signature",parentData:data,parentDataProperty:"signature",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate259.errors : vErrors.concat(validate259.errors);
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

export const Observation = validate474;
const schema82 = {"oneOf":[{"$ref":"https://transit.invalid/generated-validator/43"},{"$ref":"https://transit.invalid/generated-validator/105"}]};
const schema83 = {"type":"object","additionalProperties":false,"required":["identity"],"properties":{"identity":{"$ref":"https://transit.invalid/generated-validator/42"}}};
const schema84 = {"type":"object","additionalProperties":false,"properties":{"principal":{"$ref":"https://transit.invalid/generated-validator/1"},"sequence":{"$ref":"https://transit.invalid/generated-validator/2"},"permissions":{"$ref":"https://transit.invalid/generated-validator/3"},"pid":{"$ref":"https://transit.invalid/generated-validator/41"},"policy_revision":{"$ref":"https://transit.invalid/generated-validator/2"}},"required":["principal","sequence","permissions","pid","policy_revision"]};
const schema85 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/1"},{"type":"null"}]};

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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate56(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
validate297.errors = vErrors;
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
validate297.errors = vErrors;
return errors === 0;
}
validate297.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.principal === undefined) && (missing0 = "principal")) || ((data.sequence === undefined) && (missing0 = "sequence"))) || ((data.permissions === undefined) && (missing0 = "permissions"))) || ((data.pid === undefined) && (missing0 = "pid"))) || ((data.policy_revision === undefined) && (missing0 = "policy_revision"))){
validate293.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "principal") || (key0 === "sequence")) || (key0 === "permissions")) || (key0 === "pid")) || (key0 === "policy_revision"))){
validate293.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.principal !== undefined){
const _errs2 = errors;
if(!(validate56(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.sequence !== undefined){
const _errs3 = errors;
if(!(validate58(data.sequence, {instancePath:instancePath+"/sequence",parentData:data,parentDataProperty:"sequence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.permissions !== undefined){
const _errs4 = errors;
if(!(validate60(data.permissions, {instancePath:instancePath+"/permissions",parentData:data,parentDataProperty:"permissions",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate60.errors : vErrors.concat(validate60.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.pid !== undefined){
const _errs5 = errors;
if(!(validate297(data.pid, {instancePath:instancePath+"/pid",parentData:data,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate297.errors : vErrors.concat(validate297.errors);
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
if(!(validate58(data.policy_revision, {instancePath:instancePath+"/policy_revision",parentData:data,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
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
validate293.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate293.errors = vErrors;
return errors === 0;
}
validate293.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate292(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate292.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.identity === undefined) && (missing0 = "identity")){
validate292.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "identity")){
validate292.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.identity !== undefined){
if(!(validate293(data.identity, {instancePath:instancePath+"/identity",parentData:data,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate293.errors : vErrors.concat(validate293.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate292.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate292.errors = vErrors;
return errors === 0;
}
validate292.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema86 = {"type":"object","additionalProperties":false,"required":["state"],"properties":{"state":{"$ref":"https://transit.invalid/generated-validator/104"}}};
const schema87 = {"type":"object","additionalProperties":false,"properties":{"revision":{"$ref":"https://transit.invalid/generated-validator/2"},"configuration":{"$ref":"https://transit.invalid/generated-validator/7"},"policy":{"$ref":"https://transit.invalid/generated-validator/44"},"head":{"$ref":"https://transit.invalid/generated-validator/45"},"receipt":{"$ref":"https://transit.invalid/generated-validator/46"},"upload":{"$ref":"https://transit.invalid/generated-validator/49"},"disposition":{"$ref":"https://transit.invalid/generated-validator/103"},"receipt_diagnostic":{"$ref":"https://transit.invalid/generated-validator/101"}},"required":["revision","configuration","policy","head","receipt","upload","disposition"]};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.application === undefined) && (missing0 = "application")) || ((data.namespace === undefined) && (missing0 = "namespace"))) || ((data.realm === undefined) && (missing0 = "realm"))) || ((data.administrator === undefined) && (missing0 = "administrator"))) || ((data.name_digest === undefined) && (missing0 = "name_digest"))){
validate124.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "application") || (key0 === "namespace")) || (key0 === "realm")) || (key0 === "administrator")) || (key0 === "name_digest"))){
validate124.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.application !== undefined){
const _errs2 = errors;
if(!(validate56(data.application, {instancePath:instancePath+"/application",parentData:data,parentDataProperty:"application",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.namespace !== undefined){
const _errs3 = errors;
if(!(validate58(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
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
if(!(validate56(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.administrator !== undefined){
const _errs5 = errors;
if(!(validate56(data.administrator, {instancePath:instancePath+"/administrator",parentData:data,parentDataProperty:"administrator",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.name_digest !== undefined){
const _errs6 = errors;
if(!(validate79(data.name_digest, {instancePath:instancePath+"/name_digest",parentData:data,parentDataProperty:"name_digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate79.errors : vErrors.concat(validate79.errors);
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
validate124.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate124.errors = vErrors;
return errors === 0;
}
validate124.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema88 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/8"},{"type":"null"}]};

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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate136(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate136.errors : vErrors.concat(validate136.errors);
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
validate307.errors = vErrors;
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
validate307.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate307.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema89 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/19"},{"type":"null"}]};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((data.revision === undefined) && (missing0 = "revision")) || ((data.record === undefined) && (missing0 = "record"))) || ((data.spec === undefined) && (missing0 = "spec"))) || ((data.principal === undefined) && (missing0 = "principal"))) || ((data.operation === undefined) && (missing0 = "operation"))) || ((data.input === undefined) && (missing0 = "input"))){
validate181.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "revision") || (key0 === "record")) || (key0 === "spec")) || (key0 === "principal")) || (key0 === "operation")) || (key0 === "input"))){
validate181.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.revision !== undefined){
const _errs2 = errors;
if(!(validate58(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.record !== undefined){
const _errs3 = errors;
if(!(validate58(data.record, {instancePath:instancePath+"/record",parentData:data,parentDataProperty:"record",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.spec !== undefined){
const _errs4 = errors;
if(!(validate146(data.spec, {instancePath:instancePath+"/spec",parentData:data,parentDataProperty:"spec",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
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
if(!(validate56(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.operation !== undefined){
const _errs6 = errors;
if(!(validate58(data.operation, {instancePath:instancePath+"/operation",parentData:data,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.input !== undefined){
const _errs7 = errors;
if(!(validate56(data.input, {instancePath:instancePath+"/input",parentData:data,parentDataProperty:"input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
validate181.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate181.errors = vErrors;
return errors === 0;
}
validate181.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate181(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate181.errors : vErrors.concat(validate181.errors);
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
validate310.errors = vErrors;
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
validate310.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate310.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema90 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/18"},{"type":"null"}]};

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
if(((((data.proposal === undefined) && (missing0 = "proposal")) || ((data.phase === undefined) && (missing0 = "phase"))) || ((data.input === undefined) && (missing0 = "input"))) || ((data.owns_record === undefined) && (missing0 = "owns_record"))){
validate159.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "proposal") || (key0 === "phase")) || (key0 === "input")) || (key0 === "owns_record")) || (key0 === "conflict_basis"))){
validate159.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.proposal !== undefined){
const _errs2 = errors;
if(!(validate140(data.proposal, {instancePath:instancePath+"/proposal",parentData:data,parentDataProperty:"proposal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate140.errors : vErrors.concat(validate140.errors);
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
if(!(validate161(data.phase, {instancePath:instancePath+"/phase",parentData:data,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.input !== undefined){
const _errs4 = errors;
if(!(validate56(data.input, {instancePath:instancePath+"/input",parentData:data,parentDataProperty:"input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.owns_record !== undefined){
const _errs5 = errors;
if(typeof data.owns_record !== "boolean"){
validate159.errors = [{instancePath:instancePath+"/owns_record",schemaPath:"#/properties/owns_record/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.conflict_basis !== undefined){
const _errs7 = errors;
if(!(validate164(data.conflict_basis, {instancePath:instancePath+"/conflict_basis",parentData:data,parentDataProperty:"conflict_basis",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate164.errors : vErrors.concat(validate164.errors);
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
else {
validate159.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate159.errors = vErrors;
return errors === 0;
}
validate159.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate159(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate159.errors : vErrors.concat(validate159.errors);
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
validate313.errors = vErrors;
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
validate313.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate313.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema91 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/48"},{"type":"null"}]};
const schema92 = {"type":"object","additionalProperties":false,"properties":{"written":{"$ref":"https://transit.invalid/generated-validator/9"},"collected":{"$ref":"https://transit.invalid/generated-validator/9"},"reserved":{"type":"boolean"},"first_half":{"type":"boolean"},"state":{"$ref":"https://transit.invalid/generated-validator/47"}},"required":["written","collected","reserved","first_half","state"]};
const schema93 = {"type":"string","enum":["staging","published","abandoned","retired"]};

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
if(typeof data !== "string"){
validate320.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((data === "staging") || (data === "published")) || (data === "abandoned")) || (data === "retired"))){
validate320.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema93.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate320.errors = vErrors;
return errors === 0;
}
validate320.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.written === undefined) && (missing0 = "written")) || ((data.collected === undefined) && (missing0 = "collected"))) || ((data.reserved === undefined) && (missing0 = "reserved"))) || ((data.first_half === undefined) && (missing0 = "first_half"))) || ((data.state === undefined) && (missing0 = "state"))){
validate317.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "written") || (key0 === "collected")) || (key0 === "reserved")) || (key0 === "first_half")) || (key0 === "state"))){
validate317.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.written !== undefined){
const _errs2 = errors;
if(!(validate147(data.written, {instancePath:instancePath+"/written",parentData:data,parentDataProperty:"written",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate147.errors : vErrors.concat(validate147.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.collected !== undefined){
const _errs3 = errors;
if(!(validate147(data.collected, {instancePath:instancePath+"/collected",parentData:data,parentDataProperty:"collected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate147.errors : vErrors.concat(validate147.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.reserved !== undefined){
const _errs4 = errors;
if(typeof data.reserved !== "boolean"){
validate317.errors = [{instancePath:instancePath+"/reserved",schemaPath:"#/properties/reserved/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.first_half !== undefined){
const _errs6 = errors;
if(typeof data.first_half !== "boolean"){
validate317.errors = [{instancePath:instancePath+"/first_half",schemaPath:"#/properties/first_half/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.state !== undefined){
const _errs8 = errors;
if(!(validate320(data.state, {instancePath:instancePath+"/state",parentData:data,parentDataProperty:"state",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate320.errors : vErrors.concat(validate320.errors);
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
else {
validate317.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate317.errors = vErrors;
return errors === 0;
}
validate317.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate316(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate316.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate317(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate317.errors : vErrors.concat(validate317.errors);
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
validate316.errors = vErrors;
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
validate316.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate316.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema94 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/102"},{"type":"null"}]};
const schema95 = {"type":"object","additionalProperties":false,"properties":{"record":{"$ref":"https://transit.invalid/generated-validator/54"},"witness":{"$ref":"https://transit.invalid/generated-validator/67"},"diagnostic":{"$ref":"https://transit.invalid/generated-validator/101"}},"required":["record","witness","diagnostic"]};
const schema96 = {"type":"object","additionalProperties":false,"properties":{"reason":{"$ref":"https://transit.invalid/generated-validator/50"},"input":{"$ref":"https://transit.invalid/generated-validator/1"},"operation":{"$ref":"https://transit.invalid/generated-validator/2"},"payload":{"$ref":"https://transit.invalid/generated-validator/6"},"cause":{"$ref":"https://transit.invalid/generated-validator/51"},"code":{"$ref":"https://transit.invalid/generated-validator/51"},"category":{"$ref":"https://transit.invalid/generated-validator/52"},"stage":{"$ref":"https://transit.invalid/generated-validator/53"}},"required":["reason","input","operation","payload","cause","code","category","stage"]};
const schema97 = {"type":"string","enum":["InvalidApplicationFrame","ApplicationExternalOriginRequired","InvalidApplicationCommand","ApplicationDenied","ApplicationPolicyConflict","ApplicationIdentityConflict","ApplicationRecordOccupied","ApplicationOperationNotFound","ApplicationAlreadyApplied","ApplicationNotAbandoned","ApplicationDigestMismatch","ApplicationDefinitionMismatch","NoncanonicalApplicationProgram","ApplicationUploadPartConflict","InvalidApplicationPart","InvalidApplicationOperation","InvalidApplicationPolicy","InvalidApplicationProposal","PublicationQuotaExceeded","PublicationGap","InvalidPublicationPart","PublicationPartConflict","IncompletePublication","InvalidApplicationProgram","InterfaceProgramTooLarge"]};

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
if(!(((((((((((((((((((((((((data === "InvalidApplicationFrame") || (data === "ApplicationExternalOriginRequired")) || (data === "InvalidApplicationCommand")) || (data === "ApplicationDenied")) || (data === "ApplicationPolicyConflict")) || (data === "ApplicationIdentityConflict")) || (data === "ApplicationRecordOccupied")) || (data === "ApplicationOperationNotFound")) || (data === "ApplicationAlreadyApplied")) || (data === "ApplicationNotAbandoned")) || (data === "ApplicationDigestMismatch")) || (data === "ApplicationDefinitionMismatch")) || (data === "NoncanonicalApplicationProgram")) || (data === "ApplicationUploadPartConflict")) || (data === "InvalidApplicationPart")) || (data === "InvalidApplicationOperation")) || (data === "InvalidApplicationPolicy")) || (data === "InvalidApplicationProposal")) || (data === "PublicationQuotaExceeded")) || (data === "PublicationGap")) || (data === "InvalidPublicationPart")) || (data === "PublicationPartConflict")) || (data === "IncompletePublication")) || (data === "InvalidApplicationProgram")) || (data === "InterfaceProgramTooLarge"))){
validate327.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema97.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate327.errors = vErrors;
return errors === 0;
}
validate327.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema98 = {"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512};
const pattern8 = new RegExp("^(?:[0-9a-f]{2})*$", "u");

function validate332(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate332.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func2(data) > 512){
validate332.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"}];
return false;
}
else {
if(!pattern8.test(data)){
validate332.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""}];
return false;
}
}
}
else {
validate332.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate332.errors = vErrors;
return errors === 0;
}
validate332.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema99 = {"type":"string","enum":["syntax","binding","unsupported","constraint","access","conflict","limit","lifecycle","integrity","unavailable","internal"]};

function validate335(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate335.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate335.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((data === "syntax") || (data === "binding")) || (data === "unsupported")) || (data === "constraint")) || (data === "access")) || (data === "conflict")) || (data === "limit")) || (data === "lifecycle")) || (data === "integrity")) || (data === "unavailable")) || (data === "internal"))){
validate335.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema99.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate335.errors = vErrors;
return errors === 0;
}
validate335.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema100 = {"type":"string","enum":["input","parse","compile","bind","prepare","submit","admission","execute","read","decode","output","reconcile","cleanup","control"]};

function validate337(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate337.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate337.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((((data === "input") || (data === "parse")) || (data === "compile")) || (data === "bind")) || (data === "prepare")) || (data === "submit")) || (data === "admission")) || (data === "execute")) || (data === "read")) || (data === "decode")) || (data === "output")) || (data === "reconcile")) || (data === "cleanup")) || (data === "control"))){
validate337.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema100.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate337.errors = vErrors;
return errors === 0;
}
validate337.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate326(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate326.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((((data.reason === undefined) && (missing0 = "reason")) || ((data.input === undefined) && (missing0 = "input"))) || ((data.operation === undefined) && (missing0 = "operation"))) || ((data.payload === undefined) && (missing0 = "payload"))) || ((data.cause === undefined) && (missing0 = "cause"))) || ((data.code === undefined) && (missing0 = "code"))) || ((data.category === undefined) && (missing0 = "category"))) || ((data.stage === undefined) && (missing0 = "stage"))){
validate326.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "reason") || (key0 === "input")) || (key0 === "operation")) || (key0 === "payload")) || (key0 === "cause")) || (key0 === "code")) || (key0 === "category")) || (key0 === "stage"))){
validate326.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.reason !== undefined){
const _errs2 = errors;
if(!(validate327(data.reason, {instancePath:instancePath+"/reason",parentData:data,parentDataProperty:"reason",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate327.errors : vErrors.concat(validate327.errors);
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
if(!(validate56(data.input, {instancePath:instancePath+"/input",parentData:data,parentDataProperty:"input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.operation !== undefined){
const _errs4 = errors;
if(!(validate58(data.operation, {instancePath:instancePath+"/operation",parentData:data,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.payload !== undefined){
const _errs5 = errors;
if(!(validate79(data.payload, {instancePath:instancePath+"/payload",parentData:data,parentDataProperty:"payload",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate79.errors : vErrors.concat(validate79.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.cause !== undefined){
const _errs6 = errors;
if(!(validate332(data.cause, {instancePath:instancePath+"/cause",parentData:data,parentDataProperty:"cause",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate332.errors : vErrors.concat(validate332.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.code !== undefined){
const _errs7 = errors;
if(!(validate332(data.code, {instancePath:instancePath+"/code",parentData:data,parentDataProperty:"code",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate332.errors : vErrors.concat(validate332.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.category !== undefined){
const _errs8 = errors;
if(!(validate335(data.category, {instancePath:instancePath+"/category",parentData:data,parentDataProperty:"category",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate335.errors : vErrors.concat(validate335.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.stage !== undefined){
const _errs9 = errors;
if(!(validate337(data.stage, {instancePath:instancePath+"/stage",parentData:data,parentDataProperty:"stage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate337.errors : vErrors.concat(validate337.errors);
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
validate326.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate326.errors = vErrors;
return errors === 0;
}
validate326.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema101 = {"oneOf":[{"$ref":"https://transit.invalid/generated-validator/13"},{"$ref":"https://transit.invalid/generated-validator/56"},{"$ref":"https://transit.invalid/generated-validator/62"},{"$ref":"https://transit.invalid/generated-validator/64"},{"$ref":"https://transit.invalid/generated-validator/66"}]};
const schema102 = {"type":"object","additionalProperties":false,"required":["policy"],"properties":{"policy":{"$ref":"https://transit.invalid/generated-validator/55"}}};
const schema103 = {"type":"object","additionalProperties":false,"properties":{"principal":{"$ref":"https://transit.invalid/generated-validator/1"},"expected":{"$ref":"https://transit.invalid/generated-validator/2"},"actual":{"$ref":"https://transit.invalid/generated-validator/2"},"present":{"type":"boolean"},"publish":{"type":"boolean"}},"required":["principal","expected","actual","present","publish"]};

function validate343(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate343.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.principal === undefined) && (missing0 = "principal")) || ((data.expected === undefined) && (missing0 = "expected"))) || ((data.actual === undefined) && (missing0 = "actual"))) || ((data.present === undefined) && (missing0 = "present"))) || ((data.publish === undefined) && (missing0 = "publish"))){
validate343.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "principal") || (key0 === "expected")) || (key0 === "actual")) || (key0 === "present")) || (key0 === "publish"))){
validate343.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.principal !== undefined){
const _errs2 = errors;
if(!(validate56(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.expected !== undefined){
const _errs3 = errors;
if(!(validate58(data.expected, {instancePath:instancePath+"/expected",parentData:data,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.actual !== undefined){
const _errs4 = errors;
if(!(validate58(data.actual, {instancePath:instancePath+"/actual",parentData:data,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.present !== undefined){
const _errs5 = errors;
if(typeof data.present !== "boolean"){
validate343.errors = [{instancePath:instancePath+"/present",schemaPath:"#/properties/present/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.publish !== undefined){
const _errs7 = errors;
if(typeof data.publish !== "boolean"){
validate343.errors = [{instancePath:instancePath+"/publish",schemaPath:"#/properties/publish/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
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
else {
validate343.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate343.errors = vErrors;
return errors === 0;
}
validate343.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate342(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate342.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.policy === undefined) && (missing0 = "policy")){
validate342.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "policy")){
validate342.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.policy !== undefined){
if(!(validate343(data.policy, {instancePath:instancePath+"/policy",parentData:data,parentDataProperty:"policy",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate343.errors : vErrors.concat(validate343.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate342.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate342.errors = vErrors;
return errors === 0;
}
validate342.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema104 = {"type":"object","additionalProperties":false,"required":["declaration"],"properties":{"declaration":{"$ref":"https://transit.invalid/generated-validator/61"}}};
const schema105 = {"type":"object","additionalProperties":false,"properties":{"body_digest":{"$ref":"https://transit.invalid/generated-validator/6"},"location":{"$ref":"https://transit.invalid/generated-validator/57"},"member":{"$ref":"https://transit.invalid/generated-validator/51"},"option":{"$ref":"https://transit.invalid/generated-validator/51"},"extra":{"$ref":"https://transit.invalid/generated-validator/60"}},"required":["body_digest","location","member","option","extra"]};
const schema106 = {"type":"object","additionalProperties":false,"properties":{"offset":{"$ref":"https://transit.invalid/generated-validator/9"},"line":{"$ref":"https://transit.invalid/generated-validator/9"},"column":{"$ref":"https://transit.invalid/generated-validator/9"}},"required":[]};

function validate352(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate352.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "offset") || (key0 === "line")) || (key0 === "column"))){
validate352.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.offset !== undefined){
const _errs2 = errors;
if(!(validate147(data.offset, {instancePath:instancePath+"/offset",parentData:data,parentDataProperty:"offset",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate147.errors : vErrors.concat(validate147.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.line !== undefined){
const _errs3 = errors;
if(!(validate147(data.line, {instancePath:instancePath+"/line",parentData:data,parentDataProperty:"line",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate147.errors : vErrors.concat(validate147.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.column !== undefined){
const _errs4 = errors;
if(!(validate147(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate147.errors : vErrors.concat(validate147.errors);
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
validate352.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate352.errors = vErrors;
return errors === 0;
}
validate352.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema107 = {"oneOf":[{"$ref":"https://transit.invalid/generated-validator/13"},{"$ref":"https://transit.invalid/generated-validator/58"},{"$ref":"https://transit.invalid/generated-validator/59"}]};
const schema108 = {"type":"object","additionalProperties":false,"required":["expected"],"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/51"}}};

function validate361(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate361.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.expected === undefined) && (missing0 = "expected")){
validate361.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "expected")){
validate361.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.expected !== undefined){
if(!(validate332(data.expected, {instancePath:instancePath+"/expected",parentData:data,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate332.errors : vErrors.concat(validate332.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate361.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate361.errors = vErrors;
return errors === 0;
}
validate361.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema109 = {"type":"object","additionalProperties":false,"required":["reference"],"properties":{"reference":{"$ref":"https://transit.invalid/generated-validator/51"}}};

function validate364(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate364.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.reference === undefined) && (missing0 = "reference")){
validate364.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "reference")){
validate364.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.reference !== undefined){
if(!(validate332(data.reference, {instancePath:instancePath+"/reference",parentData:data,parentDataProperty:"reference",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate332.errors : vErrors.concat(validate332.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate364.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate364.errors = vErrors;
return errors === 0;
}
validate364.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate359(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate359.evaluated;
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
if(!(validate165(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate165.errors : vErrors.concat(validate165.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs2 = errors;
if(!(validate361(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate361.errors : vErrors.concat(validate361.errors);
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
if(!(validate364(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate364.errors : vErrors.concat(validate364.errors);
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
validate359.errors = vErrors;
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
validate359.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate359.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate350(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate350.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.body_digest === undefined) && (missing0 = "body_digest")) || ((data.location === undefined) && (missing0 = "location"))) || ((data.member === undefined) && (missing0 = "member"))) || ((data.option === undefined) && (missing0 = "option"))) || ((data.extra === undefined) && (missing0 = "extra"))){
validate350.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "body_digest") || (key0 === "location")) || (key0 === "member")) || (key0 === "option")) || (key0 === "extra"))){
validate350.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.body_digest !== undefined){
const _errs2 = errors;
if(!(validate79(data.body_digest, {instancePath:instancePath+"/body_digest",parentData:data,parentDataProperty:"body_digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate79.errors : vErrors.concat(validate79.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.location !== undefined){
const _errs3 = errors;
if(!(validate352(data.location, {instancePath:instancePath+"/location",parentData:data,parentDataProperty:"location",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate352.errors : vErrors.concat(validate352.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.member !== undefined){
const _errs4 = errors;
if(!(validate332(data.member, {instancePath:instancePath+"/member",parentData:data,parentDataProperty:"member",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate332.errors : vErrors.concat(validate332.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.option !== undefined){
const _errs5 = errors;
if(!(validate332(data.option, {instancePath:instancePath+"/option",parentData:data,parentDataProperty:"option",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate332.errors : vErrors.concat(validate332.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.extra !== undefined){
const _errs6 = errors;
if(!(validate359(data.extra, {instancePath:instancePath+"/extra",parentData:data,parentDataProperty:"extra",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate359.errors : vErrors.concat(validate359.errors);
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
validate350.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate350.errors = vErrors;
return errors === 0;
}
validate350.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate349(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate349.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.declaration === undefined) && (missing0 = "declaration")){
validate349.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "declaration")){
validate349.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.declaration !== undefined){
if(!(validate350(data.declaration, {instancePath:instancePath+"/declaration",parentData:data,parentDataProperty:"declaration",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate350.errors : vErrors.concat(validate350.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate349.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate349.errors = vErrors;
return errors === 0;
}
validate349.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema110 = {"type":"object","additionalProperties":false,"required":["sql"],"properties":{"sql":{"$ref":"https://transit.invalid/generated-validator/63"}}};
const schema111 = {"type":"object","additionalProperties":false,"properties":{"body_digest":{"$ref":"https://transit.invalid/generated-validator/6"},"location":{"$ref":"https://transit.invalid/generated-validator/57"},"member":{"$ref":"https://transit.invalid/generated-validator/51"},"sql":{"$ref":"https://transit.invalid/generated-validator/57"}},"required":["body_digest","location","member","sql"]};

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
if(((((data.body_digest === undefined) && (missing0 = "body_digest")) || ((data.location === undefined) && (missing0 = "location"))) || ((data.member === undefined) && (missing0 = "member"))) || ((data.sql === undefined) && (missing0 = "sql"))){
validate371.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "body_digest") || (key0 === "location")) || (key0 === "member")) || (key0 === "sql"))){
validate371.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.body_digest !== undefined){
const _errs2 = errors;
if(!(validate79(data.body_digest, {instancePath:instancePath+"/body_digest",parentData:data,parentDataProperty:"body_digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate79.errors : vErrors.concat(validate79.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.location !== undefined){
const _errs3 = errors;
if(!(validate352(data.location, {instancePath:instancePath+"/location",parentData:data,parentDataProperty:"location",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate352.errors : vErrors.concat(validate352.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.member !== undefined){
const _errs4 = errors;
if(!(validate332(data.member, {instancePath:instancePath+"/member",parentData:data,parentDataProperty:"member",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate332.errors : vErrors.concat(validate332.errors);
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
if(!(validate352(data.sql, {instancePath:instancePath+"/sql",parentData:data,parentDataProperty:"sql",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate352.errors : vErrors.concat(validate352.errors);
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


function validate370(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate370.evaluated;
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
validate370.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "sql")){
validate370.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.sql !== undefined){
if(!(validate371(data.sql, {instancePath:instancePath+"/sql",parentData:data,parentDataProperty:"sql",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate371.errors : vErrors.concat(validate371.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate370.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate370.errors = vErrors;
return errors === 0;
}
validate370.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema112 = {"type":"object","additionalProperties":false,"required":["upload"],"properties":{"upload":{"$ref":"https://transit.invalid/generated-validator/65"}}};
const schema113 = {"type":"object","additionalProperties":false,"properties":{"record":{"$ref":"https://transit.invalid/generated-validator/2"},"written":{"$ref":"https://transit.invalid/generated-validator/9"},"required":{"$ref":"https://transit.invalid/generated-validator/9"},"length":{"$ref":"https://transit.invalid/generated-validator/9"}},"required":["record","written","required","length"]};

function validate379(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate379.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.record === undefined) && (missing0 = "record")) || ((data.written === undefined) && (missing0 = "written"))) || ((data.required === undefined) && (missing0 = "required"))) || ((data.length === undefined) && (missing0 = "length"))){
validate379.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "record") || (key0 === "written")) || (key0 === "required")) || (key0 === "length"))){
validate379.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.record !== undefined){
const _errs2 = errors;
if(!(validate58(data.record, {instancePath:instancePath+"/record",parentData:data,parentDataProperty:"record",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.written !== undefined){
const _errs3 = errors;
if(!(validate147(data.written, {instancePath:instancePath+"/written",parentData:data,parentDataProperty:"written",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate147.errors : vErrors.concat(validate147.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.required !== undefined){
const _errs4 = errors;
if(!(validate147(data.required, {instancePath:instancePath+"/required",parentData:data,parentDataProperty:"required",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate147.errors : vErrors.concat(validate147.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.length !== undefined){
const _errs5 = errors;
if(!(validate147(data.length, {instancePath:instancePath+"/length",parentData:data,parentDataProperty:"length",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate147.errors : vErrors.concat(validate147.errors);
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
validate379.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate379.errors = vErrors;
return errors === 0;
}
validate379.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate378(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate378.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.upload === undefined) && (missing0 = "upload")){
validate378.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "upload")){
validate378.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.upload !== undefined){
if(!(validate379(data.upload, {instancePath:instancePath+"/upload",parentData:data,parentDataProperty:"upload",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate379.errors : vErrors.concat(validate379.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate378.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate378.errors = vErrors;
return errors === 0;
}
validate378.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate340(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate340.evaluated;
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
if(!(validate165(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate165.errors : vErrors.concat(validate165.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs2 = errors;
if(!(validate342(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate342.errors : vErrors.concat(validate342.errors);
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
if(!(validate349(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate349.errors : vErrors.concat(validate349.errors);
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
if(!(validate370(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate370.errors : vErrors.concat(validate370.errors);
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
if(!(validate378(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate378.errors : vErrors.concat(validate378.errors);
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
validate340.errors = vErrors;
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
validate340.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate340.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema114 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/100"},{"type":"null"}]};
const schema115 = {"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"definition":{"$ref":"https://transit.invalid/generated-validator/68"},"code":{"type":"string","maxLength":96},"category":{"$ref":"https://transit.invalid/generated-validator/52"},"stage":{"$ref":"https://transit.invalid/generated-validator/53"},"outcome":{"$ref":"https://transit.invalid/generated-validator/69"},"evidence":{"$ref":"https://transit.invalid/generated-validator/70"},"message":{"type":"string","maxLength":384},"cause":{"$ref":"https://transit.invalid/generated-validator/71"},"identity":{"$ref":"https://transit.invalid/generated-validator/76"},"location":{"$ref":"https://transit.invalid/generated-validator/80"},"facts":{"$ref":"https://transit.invalid/generated-validator/95"},"actions":{"$ref":"https://transit.invalid/generated-validator/99"}},"required":["version","definition","code","category","stage","outcome","evidence","message"]};
const schema116 = {"type":"string","enum":["b840e71bde2e36fc2c83d773e3bb13bbf9c44c15d3d46b955beed1f8fda84a00"]};

function validate389(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate389.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate389.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(data === "b840e71bde2e36fc2c83d773e3bb13bbf9c44c15d3d46b955beed1f8fda84a00")){
validate389.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema116.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate389.errors = vErrors;
return errors === 0;
}
validate389.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema117 = {"type":"string","enum":["not_applicable","not_submitted","not_dispatched","prepared","unknown","pending","input_rejected","rejected","applied","completed","failed","cancelled","retired","closed_unknown"]};

function validate393(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate393.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate393.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((((data === "not_applicable") || (data === "not_submitted")) || (data === "not_dispatched")) || (data === "prepared")) || (data === "unknown")) || (data === "pending")) || (data === "input_rejected")) || (data === "rejected")) || (data === "applied")) || (data === "completed")) || (data === "failed")) || (data === "cancelled")) || (data === "retired")) || (data === "closed_unknown"))){
validate393.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema117.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate393.errors = vErrors;
return errors === 0;
}
validate393.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema118 = {"type":"string","enum":["none","local_before_dispatch","saved_intent","native_receipt","domain_status"]};

function validate395(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate395.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate395.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((data === "none") || (data === "local_before_dispatch")) || (data === "saved_intent")) || (data === "native_receipt")) || (data === "domain_status"))){
validate395.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema118.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate395.errors = vErrors;
return errors === 0;
}
validate395.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema119 = {"anyOf":[{"type":"string","maxLength":96},{"type":"null"}]};

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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(errors === _errs1){
if(typeof data === "string"){
if(func2(data) > 96){
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
validate397.errors = vErrors;
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
validate397.errors = vErrors;
return errors === 0;
}
validate397.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema120 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/75"},{"type":"null"}]};
const schema121 = {"type":"object","additionalProperties":false,"properties":{"domain":{"$ref":"https://transit.invalid/generated-validator/72"},"id":{"$ref":"https://transit.invalid/generated-validator/73"},"realm":{"$ref":"https://transit.invalid/generated-validator/74"},"resource":{"$ref":"https://transit.invalid/generated-validator/74"},"sequence":{"$ref":"https://transit.invalid/generated-validator/74"}},"required":["domain","id"]};
const schema122 = {"type":"string","enum":["sql","query","mutation","catalog","application","publication","migration","reactive","serving","effect","exchange","transport","internal"]};

function validate401(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate401.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate401.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((((data === "sql") || (data === "query")) || (data === "mutation")) || (data === "catalog")) || (data === "application")) || (data === "publication")) || (data === "migration")) || (data === "reactive")) || (data === "serving")) || (data === "effect")) || (data === "exchange")) || (data === "transport")) || (data === "internal"))){
validate401.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema122.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate401.errors = vErrors;
return errors === 0;
}
validate401.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema123 = {"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"};

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
if(typeof data === "string"){
if(func2(data) > 20){
validate403.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern4.test(data)){
validate403.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate403.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate403.errors = vErrors;
return errors === 0;
}
validate403.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema124 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/73"},{"type":"null"}]};

function validate405(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate405.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate403(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate403.errors : vErrors.concat(validate403.errors);
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
validate405.errors = vErrors;
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
validate405.errors = vErrors;
return errors === 0;
}
validate405.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate400(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate400.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.domain === undefined) && (missing0 = "domain")) || ((data.id === undefined) && (missing0 = "id"))){
validate400.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "domain") || (key0 === "id")) || (key0 === "realm")) || (key0 === "resource")) || (key0 === "sequence"))){
validate400.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.domain !== undefined){
const _errs2 = errors;
if(!(validate401(data.domain, {instancePath:instancePath+"/domain",parentData:data,parentDataProperty:"domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate401.errors : vErrors.concat(validate401.errors);
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
if(!(validate403(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate403.errors : vErrors.concat(validate403.errors);
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
if(!(validate405(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate405.errors : vErrors.concat(validate405.errors);
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
if(!(validate405(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate405.errors : vErrors.concat(validate405.errors);
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
if(!(validate405(data.sequence, {instancePath:instancePath+"/sequence",parentData:data,parentDataProperty:"sequence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate405.errors : vErrors.concat(validate405.errors);
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
validate400.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate400.errors = vErrors;
return errors === 0;
}
validate400.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate399(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate399.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate400(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate400.errors : vErrors.concat(validate400.errors);
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
validate399.errors = vErrors;
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
validate399.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate399.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema125 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/79"},{"type":"null"}]};
const schema126 = {"type":"object","additionalProperties":false,"properties":{"source":{"$ref":"https://transit.invalid/generated-validator/77"},"source_encoding":{"$ref":"https://transit.invalid/generated-validator/78"},"source_truncated":{"type":"boolean"},"statement":{"$ref":"https://transit.invalid/generated-validator/74"},"offset":{"$ref":"https://transit.invalid/generated-validator/73"},"length":{"$ref":"https://transit.invalid/generated-validator/73"},"line":{"$ref":"https://transit.invalid/generated-validator/73"},"byte_column":{"$ref":"https://transit.invalid/generated-validator/73"}},"required":["offset","length","line","byte_column"]};
const schema127 = {"anyOf":[{"type":"string","maxLength":512},{"type":"null"}]};

function validate414(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate414.evaluated;
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
if(func2(data) > 512){
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
validate414.errors = vErrors;
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
validate414.errors = vErrors;
return errors === 0;
}
validate414.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema128 = {"type":"string","enum":["utf8","escaped_bytes"]};

function validate416(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate416.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate416.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((data === "utf8") || (data === "escaped_bytes"))){
validate416.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema128.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate416.errors = vErrors;
return errors === 0;
}
validate416.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate413(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate413.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.offset === undefined) && (missing0 = "offset")) || ((data.length === undefined) && (missing0 = "length"))) || ((data.line === undefined) && (missing0 = "line"))) || ((data.byte_column === undefined) && (missing0 = "byte_column"))){
validate413.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "source") || (key0 === "source_encoding")) || (key0 === "source_truncated")) || (key0 === "statement")) || (key0 === "offset")) || (key0 === "length")) || (key0 === "line")) || (key0 === "byte_column"))){
validate413.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.source !== undefined){
const _errs2 = errors;
if(!(validate414(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate414.errors : vErrors.concat(validate414.errors);
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
if(!(validate416(data.source_encoding, {instancePath:instancePath+"/source_encoding",parentData:data,parentDataProperty:"source_encoding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate416.errors : vErrors.concat(validate416.errors);
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
validate413.errors = [{instancePath:instancePath+"/source_truncated",schemaPath:"#/properties/source_truncated/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
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
if(!(validate405(data.statement, {instancePath:instancePath+"/statement",parentData:data,parentDataProperty:"statement",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate405.errors : vErrors.concat(validate405.errors);
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
if(!(validate403(data.offset, {instancePath:instancePath+"/offset",parentData:data,parentDataProperty:"offset",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate403.errors : vErrors.concat(validate403.errors);
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
if(!(validate403(data.length, {instancePath:instancePath+"/length",parentData:data,parentDataProperty:"length",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate403.errors : vErrors.concat(validate403.errors);
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
if(!(validate403(data.line, {instancePath:instancePath+"/line",parentData:data,parentDataProperty:"line",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate403.errors : vErrors.concat(validate403.errors);
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
if(!(validate403(data.byte_column, {instancePath:instancePath+"/byte_column",parentData:data,parentDataProperty:"byte_column",rootData,dynamicAnchors}))){
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
else {
validate413.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate413.errors = vErrors;
return errors === 0;
}
validate413.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate413(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate413.errors : vErrors.concat(validate413.errors);
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
validate412.errors = vErrors;
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
validate412.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate412.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema129 = {"type":"array","minItems":16,"maxItems":16,"items":{"$ref":"https://transit.invalid/generated-validator/94"}};
const schema130 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/93"},{"type":"null"}]};
const schema131 = {"type":"object","additionalProperties":false,"properties":{"field":{"$ref":"https://transit.invalid/generated-validator/81"},"origin":{"$ref":"https://transit.invalid/generated-validator/82"},"availability":{"$ref":"https://transit.invalid/generated-validator/83"},"value":{"$ref":"https://transit.invalid/generated-validator/92"}},"required":["field","origin","availability","value"]};
const schema132 = {"type":"string","enum":["object","name","table","native_input","affected_rows","argument","option","permissions","scope","column","qualifier","constraint","key","input_row","first_occurrence","parameter","parameter_use","expected_count","actual_count","expected_type","actual_type","supplied_value","expected_value","expression","source_kind","source_basis","source_key","source_row","field_path","byte_offset","expected_resource","actual_resource","expected_source","actual_source","expected_revision","actual_revision","expected_schema","actual_schema","expected_policy","actual_policy","budget","limit","required","unit","completed_statements","emitted_rows","emitted_segments","completion","proposal","step","generation","attachment","lease","schema_origin","sampling_records","operation","native_cause","expected_bytes","presence","published","subscription","expected_codec","actual_codec","observed_clock","expected_namespace","actual_namespace","attempt","executor","resolution_reason","principal","deadline","authorization_policy","resolution_policy","protocol_status","native_effect","dependency","dependency_kind","dependency_owner"]};

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
if(typeof data !== "string"){
validate428.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((data === "object") || (data === "name")) || (data === "table")) || (data === "native_input")) || (data === "affected_rows")) || (data === "argument")) || (data === "option")) || (data === "permissions")) || (data === "scope")) || (data === "column")) || (data === "qualifier")) || (data === "constraint")) || (data === "key")) || (data === "input_row")) || (data === "first_occurrence")) || (data === "parameter")) || (data === "parameter_use")) || (data === "expected_count")) || (data === "actual_count")) || (data === "expected_type")) || (data === "actual_type")) || (data === "supplied_value")) || (data === "expected_value")) || (data === "expression")) || (data === "source_kind")) || (data === "source_basis")) || (data === "source_key")) || (data === "source_row")) || (data === "field_path")) || (data === "byte_offset")) || (data === "expected_resource")) || (data === "actual_resource")) || (data === "expected_source")) || (data === "actual_source")) || (data === "expected_revision")) || (data === "actual_revision")) || (data === "expected_schema")) || (data === "actual_schema")) || (data === "expected_policy")) || (data === "actual_policy")) || (data === "budget")) || (data === "limit")) || (data === "required")) || (data === "unit")) || (data === "completed_statements")) || (data === "emitted_rows")) || (data === "emitted_segments")) || (data === "completion")) || (data === "proposal")) || (data === "step")) || (data === "generation")) || (data === "attachment")) || (data === "lease")) || (data === "schema_origin")) || (data === "sampling_records")) || (data === "operation")) || (data === "native_cause")) || (data === "expected_bytes")) || (data === "presence")) || (data === "published")) || (data === "subscription")) || (data === "expected_codec")) || (data === "actual_codec")) || (data === "observed_clock")) || (data === "expected_namespace")) || (data === "actual_namespace")) || (data === "attempt")) || (data === "executor")) || (data === "resolution_reason")) || (data === "principal")) || (data === "deadline")) || (data === "authorization_policy")) || (data === "resolution_policy")) || (data === "protocol_status")) || (data === "native_effect")) || (data === "dependency")) || (data === "dependency_kind")) || (data === "dependency_owner"))){
validate428.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema132.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate428.errors = vErrors;
return errors === 0;
}
validate428.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema133 = {"type":"string","enum":["caller","execution","schema","authority","owner"]};

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
if(typeof data !== "string"){
validate430.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((data === "caller") || (data === "execution")) || (data === "schema")) || (data === "authority")) || (data === "owner"))){
validate430.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema133.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate430.errors = vErrors;
return errors === 0;
}
validate430.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema134 = {"type":"string","enum":["provided","truncated","unrecorded","unavailable","withheld","inapplicable"]};

function validate432(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate432.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate432.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((data === "provided") || (data === "truncated")) || (data === "unrecorded")) || (data === "unavailable")) || (data === "withheld")) || (data === "inapplicable"))){
validate432.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema134.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate432.errors = vErrors;
return errors === 0;
}
validate432.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema135 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/91"},{"type":"null"}]};
const schema136 = {"oneOf":[{"$ref":"https://transit.invalid/generated-validator/84"},{"$ref":"https://transit.invalid/generated-validator/86"},{"$ref":"https://transit.invalid/generated-validator/87"},{"$ref":"https://transit.invalid/generated-validator/88"},{"$ref":"https://transit.invalid/generated-validator/89"},{"$ref":"https://transit.invalid/generated-validator/90"}]};
const schema137 = {"type":"object","additionalProperties":false,"required":["text"],"properties":{"text":{"type":"string","maxLength":256}}};

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
if((data.text === undefined) && (missing0 = "text")){
validate436.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "text")){
validate436.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
if(func2(data0) > 256){
validate436.errors = [{instancePath:instancePath+"/text",schemaPath:"#/properties/text/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"}];
return false;
}
}
else {
validate436.errors = [{instancePath:instancePath+"/text",schemaPath:"#/properties/text/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
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

const schema138 = {"type":"object","additionalProperties":false,"required":["signed"],"properties":{"signed":{"$ref":"https://transit.invalid/generated-validator/85"}}};
const schema139 = {"type":"string","maxLength":20,"pattern":"^(0|-?[1-9][0-9]*)$"};
const pattern10 = new RegExp("^(0|-?[1-9][0-9]*)$", "u");

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
if(errors === 0){
if(typeof data === "string"){
if(func2(data) > 20){
validate439.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern10.test(data)){
validate439.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(0|-?[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|-?[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate439.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate439.errors = vErrors;
return errors === 0;
}
validate439.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate438(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate438.evaluated;
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
validate438.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "signed")){
validate438.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.signed !== undefined){
if(!(validate439(data.signed, {instancePath:instancePath+"/signed",parentData:data,parentDataProperty:"signed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate439.errors : vErrors.concat(validate439.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate438.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate438.errors = vErrors;
return errors === 0;
}
validate438.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema140 = {"type":"object","additionalProperties":false,"required":["unsigned"],"properties":{"unsigned":{"$ref":"https://transit.invalid/generated-validator/73"}}};

function validate442(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate442.evaluated;
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
validate442.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "unsigned")){
validate442.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.unsigned !== undefined){
if(!(validate403(data.unsigned, {instancePath:instancePath+"/unsigned",parentData:data,parentDataProperty:"unsigned",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate403.errors : vErrors.concat(validate403.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate442.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate442.errors = vErrors;
return errors === 0;
}
validate442.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema141 = {"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"type":"boolean"}}};

function validate445(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate445.evaluated;
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
validate445.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "boolean")){
validate445.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.boolean !== undefined){
if(typeof data.boolean !== "boolean"){
validate445.errors = [{instancePath:instancePath+"/boolean",schemaPath:"#/properties/boolean/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
}
}
}
}
else {
validate445.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate445.errors = vErrors;
return errors === 0;
}
validate445.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema142 = {"type":"object","additionalProperties":false,"required":["digest"],"properties":{"digest":{"$ref":"https://transit.invalid/generated-validator/6"}}};

function validate447(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate447.evaluated;
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
validate447.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "digest")){
validate447.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.digest !== undefined){
if(!(validate79(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate79.errors : vErrors.concat(validate79.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate447.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate447.errors = vErrors;
return errors === 0;
}
validate447.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema143 = {"type":"object","additionalProperties":false,"required":["location"],"properties":{"location":{"$ref":"https://transit.invalid/generated-validator/79"}}};

function validate450(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate450.evaluated;
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
validate450.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "location")){
validate450.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.location !== undefined){
if(!(validate413(data.location, {instancePath:instancePath+"/location",parentData:data,parentDataProperty:"location",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate413.errors : vErrors.concat(validate413.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate450.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate450.errors = vErrors;
return errors === 0;
}
validate450.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate435(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate435.evaluated;
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
if(!(validate436(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate436.errors : vErrors.concat(validate436.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs2 = errors;
if(!(validate438(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate438.errors : vErrors.concat(validate438.errors);
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
if(!(validate442(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate442.errors : vErrors.concat(validate442.errors);
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
if(!(validate445(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate445.errors : vErrors.concat(validate445.errors);
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
if(!(validate447(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate447.errors : vErrors.concat(validate447.errors);
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
if(!(validate450(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate450.errors : vErrors.concat(validate450.errors);
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
validate435.errors = vErrors;
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
validate435.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate435.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate434(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate434.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate435(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate435.errors : vErrors.concat(validate435.errors);
errors = vErrors.length;
}
else {
var props0 = validate435.evaluated.props;
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
validate434.errors = vErrors;
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
validate434.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate434.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate427(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate427.evaluated;
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
validate427.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "field") || (key0 === "origin")) || (key0 === "availability")) || (key0 === "value"))){
validate427.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.field !== undefined){
const _errs2 = errors;
if(!(validate428(data.field, {instancePath:instancePath+"/field",parentData:data,parentDataProperty:"field",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate428.errors : vErrors.concat(validate428.errors);
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
if(!(validate430(data.origin, {instancePath:instancePath+"/origin",parentData:data,parentDataProperty:"origin",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate430.errors : vErrors.concat(validate430.errors);
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
if(!(validate432(data.availability, {instancePath:instancePath+"/availability",parentData:data,parentDataProperty:"availability",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate432.errors : vErrors.concat(validate432.errors);
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
if(!(validate434(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate434.errors : vErrors.concat(validate434.errors);
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
validate427.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate427.errors = vErrors;
return errors === 0;
}
validate427.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate427(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate427.errors : vErrors.concat(validate427.errors);
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
validate426.errors = vErrors;
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
validate426.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate426.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate425(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate425.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 16){
validate425.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
if(data.length < 16){
validate425.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate426(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate426.errors : vErrors.concat(validate426.errors);
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
validate425.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate425.errors = vErrors;
return errors === 0;
}
validate425.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema144 = {"type":"array","minItems":4,"maxItems":4,"items":{"$ref":"https://transit.invalid/generated-validator/98"}};
const schema145 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/97"},{"type":"null"}]};
const schema146 = {"type":"object","additionalProperties":false,"properties":{"kind":{"$ref":"https://transit.invalid/generated-validator/96"},"target":{"$ref":"https://transit.invalid/generated-validator/76"}},"required":["kind"]};
const schema147 = {"type":"string","enum":["correct_input","inspect_status","resume_exact","cancel_wait","cancel_mutation","refresh","recompile","retry_read","inspect_scope","reconcile_effect","contact_operator"]};

function validate461(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate461.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate461.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((data === "correct_input") || (data === "inspect_status")) || (data === "resume_exact")) || (data === "cancel_wait")) || (data === "cancel_mutation")) || (data === "refresh")) || (data === "recompile")) || (data === "retry_read")) || (data === "inspect_scope")) || (data === "reconcile_effect")) || (data === "contact_operator"))){
validate461.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema147.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate461.errors = vErrors;
return errors === 0;
}
validate461.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if((data.kind === undefined) && (missing0 = "kind")){
validate460.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "kind") || (key0 === "target"))){
validate460.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.kind !== undefined){
const _errs2 = errors;
if(!(validate461(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate461.errors : vErrors.concat(validate461.errors);
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
if(!(validate399(data.target, {instancePath:instancePath+"/target",parentData:data,parentDataProperty:"target",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate399.errors : vErrors.concat(validate399.errors);
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


function validate459(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate459.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate460(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate460.errors : vErrors.concat(validate460.errors);
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
validate459.errors = vErrors;
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
validate459.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate459.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate458(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate458.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 4){
validate458.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 4},message:"must NOT have more than 4 items"}];
return false;
}
else {
if(data.length < 4){
validate458.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 4},message:"must NOT have fewer than 4 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate459(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate459.errors : vErrors.concat(validate459.errors);
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
validate458.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate458.errors = vErrors;
return errors === 0;
}
validate458.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate388(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate388.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((((data.version === undefined) && (missing0 = "version")) || ((data.definition === undefined) && (missing0 = "definition"))) || ((data.code === undefined) && (missing0 = "code"))) || ((data.category === undefined) && (missing0 = "category"))) || ((data.stage === undefined) && (missing0 = "stage"))) || ((data.outcome === undefined) && (missing0 = "outcome"))) || ((data.evidence === undefined) && (missing0 = "evidence"))) || ((data.message === undefined) && (missing0 = "message"))){
validate388.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema115.properties, key0))){
validate388.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate388.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"}];
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
if(!(validate389(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate389.errors : vErrors.concat(validate389.errors);
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
if(func2(data2) > 96){
validate388.errors = [{instancePath:instancePath+"/code",schemaPath:"#/properties/code/maxLength",keyword:"maxLength",params:{limit: 96},message:"must NOT have more than 96 characters"}];
return false;
}
}
else {
validate388.errors = [{instancePath:instancePath+"/code",schemaPath:"#/properties/code/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
if(!(validate335(data.category, {instancePath:instancePath+"/category",parentData:data,parentDataProperty:"category",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate335.errors : vErrors.concat(validate335.errors);
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
if(!(validate337(data.stage, {instancePath:instancePath+"/stage",parentData:data,parentDataProperty:"stage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate337.errors : vErrors.concat(validate337.errors);
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
if(!(validate393(data.outcome, {instancePath:instancePath+"/outcome",parentData:data,parentDataProperty:"outcome",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate393.errors : vErrors.concat(validate393.errors);
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
if(!(validate395(data.evidence, {instancePath:instancePath+"/evidence",parentData:data,parentDataProperty:"evidence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate395.errors : vErrors.concat(validate395.errors);
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
if(func2(data7) > 384){
validate388.errors = [{instancePath:instancePath+"/message",schemaPath:"#/properties/message/maxLength",keyword:"maxLength",params:{limit: 384},message:"must NOT have more than 384 characters"}];
return false;
}
}
else {
validate388.errors = [{instancePath:instancePath+"/message",schemaPath:"#/properties/message/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
if(!(validate397(data.cause, {instancePath:instancePath+"/cause",parentData:data,parentDataProperty:"cause",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate397.errors : vErrors.concat(validate397.errors);
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
if(!(validate399(data.identity, {instancePath:instancePath+"/identity",parentData:data,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate399.errors : vErrors.concat(validate399.errors);
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
if(!(validate412(data.location, {instancePath:instancePath+"/location",parentData:data,parentDataProperty:"location",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate412.errors : vErrors.concat(validate412.errors);
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
if(!(validate425(data.facts, {instancePath:instancePath+"/facts",parentData:data,parentDataProperty:"facts",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate425.errors : vErrors.concat(validate425.errors);
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
if(!(validate458(data.actions, {instancePath:instancePath+"/actions",parentData:data,parentDataProperty:"actions",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate458.errors : vErrors.concat(validate458.errors);
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
validate388.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate388.errors = vErrors;
return errors === 0;
}
validate388.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate388(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate388.errors : vErrors.concat(validate388.errors);
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
validate387.errors = vErrors;
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
validate387.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate387.evaluated = {"dynamicProps":true,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.record === undefined) && (missing0 = "record")) || ((data.witness === undefined) && (missing0 = "witness"))) || ((data.diagnostic === undefined) && (missing0 = "diagnostic"))){
validate325.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "record") || (key0 === "witness")) || (key0 === "diagnostic"))){
validate325.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.record !== undefined){
const _errs2 = errors;
if(!(validate326(data.record, {instancePath:instancePath+"/record",parentData:data,parentDataProperty:"record",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate326.errors : vErrors.concat(validate326.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.witness !== undefined){
const _errs3 = errors;
if(!(validate340(data.witness, {instancePath:instancePath+"/witness",parentData:data,parentDataProperty:"witness",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate340.errors : vErrors.concat(validate340.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.diagnostic !== undefined){
const _errs4 = errors;
if(!(validate387(data.diagnostic, {instancePath:instancePath+"/diagnostic",parentData:data,parentDataProperty:"diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate387.errors : vErrors.concat(validate387.errors);
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
validate325.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate325.errors = vErrors;
return errors === 0;
}
validate325.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate324(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate324.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate325(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate325.errors : vErrors.concat(validate325.errors);
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
validate324.errors = vErrors;
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
validate324.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate324.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate304(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate304.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((data.revision === undefined) && (missing0 = "revision")) || ((data.configuration === undefined) && (missing0 = "configuration"))) || ((data.policy === undefined) && (missing0 = "policy"))) || ((data.head === undefined) && (missing0 = "head"))) || ((data.receipt === undefined) && (missing0 = "receipt"))) || ((data.upload === undefined) && (missing0 = "upload"))) || ((data.disposition === undefined) && (missing0 = "disposition"))){
validate304.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "revision") || (key0 === "configuration")) || (key0 === "policy")) || (key0 === "head")) || (key0 === "receipt")) || (key0 === "upload")) || (key0 === "disposition")) || (key0 === "receipt_diagnostic"))){
validate304.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.revision !== undefined){
const _errs2 = errors;
if(!(validate58(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.configuration !== undefined){
const _errs3 = errors;
if(!(validate124(data.configuration, {instancePath:instancePath+"/configuration",parentData:data,parentDataProperty:"configuration",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate124.errors : vErrors.concat(validate124.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.policy !== undefined){
const _errs4 = errors;
if(!(validate307(data.policy, {instancePath:instancePath+"/policy",parentData:data,parentDataProperty:"policy",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate307.errors : vErrors.concat(validate307.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.head !== undefined){
const _errs5 = errors;
if(!(validate310(data.head, {instancePath:instancePath+"/head",parentData:data,parentDataProperty:"head",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate310.errors : vErrors.concat(validate310.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.receipt !== undefined){
const _errs6 = errors;
if(!(validate313(data.receipt, {instancePath:instancePath+"/receipt",parentData:data,parentDataProperty:"receipt",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate313.errors : vErrors.concat(validate313.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.upload !== undefined){
const _errs7 = errors;
if(!(validate316(data.upload, {instancePath:instancePath+"/upload",parentData:data,parentDataProperty:"upload",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate316.errors : vErrors.concat(validate316.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.disposition !== undefined){
const _errs8 = errors;
if(!(validate324(data.disposition, {instancePath:instancePath+"/disposition",parentData:data,parentDataProperty:"disposition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate324.errors : vErrors.concat(validate324.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.receipt_diagnostic !== undefined){
const _errs9 = errors;
if(!(validate387(data.receipt_diagnostic, {instancePath:instancePath+"/receipt_diagnostic",parentData:data,parentDataProperty:"receipt_diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate387.errors : vErrors.concat(validate387.errors);
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
validate304.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate304.errors = vErrors;
return errors === 0;
}
validate304.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if((data.state === undefined) && (missing0 = "state")){
validate303.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "state")){
validate303.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.state !== undefined){
if(!(validate304(data.state, {instancePath:instancePath+"/state",parentData:data,parentDataProperty:"state",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate304.errors : vErrors.concat(validate304.errors);
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


function validate474(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate474.evaluated;
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
if(!(validate292(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate292.errors : vErrors.concat(validate292.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs2 = errors;
if(!(validate303(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate303.errors : vErrors.concat(validate303.errors);
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
validate474.errors = vErrors;
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
validate474.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate474.evaluated = {"dynamicProps":true,"dynamicItems":false};

export const HostRequest = validate477;
const schema149 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["info"],"properties":{"info":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["compile"],"properties":{"compile":{"type":"object","additionalProperties":false,"properties":{"source":{"type":"string","maxLength":65536}},"required":["source"]}}},{"type":"object","additionalProperties":false,"required":["format"],"properties":{"format":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","const":1},"name":{"$ref":"https://transit.invalid/generated-validator/0"},"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"revision":{"$ref":"https://transit.invalid/generated-validator/2"},"components":{"$ref":"https://transit.invalid/generated-validator/3"},"entry":{"$ref":"https://transit.invalid/generated-validator/0"},"theme":{"$ref":"https://transit.invalid/generated-validator/0"},"themes":{"type":"array","maxItems":2,"items":{"$ref":"#/$defs/Theme"}},"screens":{"type":"array","maxItems":16,"items":{"$ref":"#/$defs/Screen"}},"bindings":{"type":"array","maxItems":16,"items":{"$ref":"#/$defs/Binding"}},"actions":{"type":"array","maxItems":16,"items":{"$ref":"#/$defs/Action"}}},"required":["name","realm","revision","entry","theme","themes","screens","bindings","actions"]}}},{"type":"object","additionalProperties":false,"required":["next_upload"],"properties":{"next_upload":{"type":"object","additionalProperties":false,"properties":{"proposal":{"$ref":"https://transit.invalid/generated-validator/11"},"canonical":{"type":"string","maxLength":65536},"state":{"$ref":"https://transit.invalid/generated-validator/104"}},"required":["proposal","canonical","state"]}}},{"type":"object","additionalProperties":false,"required":["next_cleanup"],"properties":{"next_cleanup":{"type":"object","additionalProperties":false,"properties":{"proposal":{"$ref":"https://transit.invalid/generated-validator/11"},"state":{"$ref":"https://transit.invalid/generated-validator/104"}},"required":["proposal","state"]}}},{"type":"object","additionalProperties":false,"required":["prepare"],"properties":{"prepare":{"type":"object","additionalProperties":false,"properties":{"principal":{"$ref":"https://transit.invalid/generated-validator/1"},"sequence":{"$ref":"https://transit.invalid/generated-validator/2"},"command":{"$ref":"https://transit.invalid/generated-validator/30"}},"required":["principal","sequence","command"]}}},{"type":"object","additionalProperties":false,"required":["submit"],"properties":{"submit":{"$ref":"https://transit.invalid/generated-validator/34"}}},{"type":"object","additionalProperties":false,"required":["prepare_read"],"properties":{"prepare_read":{"type":"object","additionalProperties":false,"properties":{"principal":{"$ref":"https://transit.invalid/generated-validator/1"},"selection":{"$ref":"https://transit.invalid/generated-validator/38"}},"required":["principal","selection"]}}},{"type":"object","additionalProperties":false,"required":["read"],"properties":{"read":{"$ref":"https://transit.invalid/generated-validator/40"}}}]};

function validate257(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate257.evaluated;
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
validate257.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "prepared") || (key0 === "signature"))){
validate257.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.prepared !== undefined){
const _errs2 = errors;
if(!(validate245(data.prepared, {instancePath:instancePath+"/prepared",parentData:data,parentDataProperty:"prepared",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate245.errors : vErrors.concat(validate245.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.signature !== undefined){
const _errs3 = errors;
if(!(validate259(data.signature, {instancePath:instancePath+"/signature",parentData:data,parentDataProperty:"signature",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate259.errors : vErrors.concat(validate259.errors);
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
validate257.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate257.errors = vErrors;
return errors === 0;
}
validate257.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate285(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate285.evaluated;
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
validate285.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "prepared") || (key0 === "signature"))){
validate285.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.prepared !== undefined){
const _errs2 = errors;
if(!(validate265(data.prepared, {instancePath:instancePath+"/prepared",parentData:data,parentDataProperty:"prepared",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate265.errors : vErrors.concat(validate265.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.signature !== undefined){
const _errs3 = errors;
if(!(validate259(data.signature, {instancePath:instancePath+"/signature",parentData:data,parentDataProperty:"signature",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate259.errors : vErrors.concat(validate259.errors);
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
validate285.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate285.errors = vErrors;
return errors === 0;
}
validate285.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
let passing0 = null;
const _errs1 = errors;
if(errors === _errs1){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.info === undefined) && (missing0 = "info")){
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
if(!(key0 === "info")){
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
if(data.info !== undefined){
let data0 = data.info;
const _errs4 = errors;
if(errors === _errs4){
if(data0 && typeof data0 == "object" && !Array.isArray(data0)){
if(Object.keys(data0).length > 0){
const err2 = {instancePath:instancePath+"/info",schemaPath:"#/oneOf/0/properties/info/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
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
const err3 = {instancePath:instancePath+"/info",schemaPath:"#/oneOf/0/properties/info/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data1.source === undefined) && (missing2 = "source")){
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
if(!(key2 === "source")){
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
if(data1.source !== undefined){
let data2 = data1.source;
const _errs12 = errors;
if(errors === _errs12){
if(typeof data2 === "string"){
if(func2(data2) > 65536){
const err9 = {instancePath:instancePath+"/compile/source",schemaPath:"#/oneOf/1/properties/compile/properties/source/maxLength",keyword:"maxLength",params:{limit: 65536},message:"must NOT have more than 65536 characters"};
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
const err10 = {instancePath:instancePath+"/compile/source",schemaPath:"#/oneOf/1/properties/compile/properties/source/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
if((data.format === undefined) && (missing3 = "format")){
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
if(!(key3 === "format")){
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
if(data.format !== undefined){
let data3 = data.format;
const _errs17 = errors;
if(errors === _errs17){
if(data3 && typeof data3 == "object" && !Array.isArray(data3)){
let missing4;
if((((((((((data3.name === undefined) && (missing4 = "name")) || ((data3.realm === undefined) && (missing4 = "realm"))) || ((data3.revision === undefined) && (missing4 = "revision"))) || ((data3.entry === undefined) && (missing4 = "entry"))) || ((data3.theme === undefined) && (missing4 = "theme"))) || ((data3.themes === undefined) && (missing4 = "themes"))) || ((data3.screens === undefined) && (missing4 = "screens"))) || ((data3.bindings === undefined) && (missing4 = "bindings"))) || ((data3.actions === undefined) && (missing4 = "actions"))){
const err15 = {instancePath:instancePath+"/format",schemaPath:"#/oneOf/2/properties/format/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
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
if(!(func1.call(schema149.oneOf[2].properties.format.properties, key4))){
const err16 = {instancePath:instancePath+"/format",schemaPath:"#/oneOf/2/properties/format/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(data3.version !== undefined){
let data4 = data3.version;
const _errs20 = errors;
if(!(((typeof data4 == "number") && (!(data4 % 1) && !isNaN(data4))) && (isFinite(data4)))){
const err17 = {instancePath:instancePath+"/format/version",schemaPath:"#/oneOf/2/properties/format/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err17];
}
else {
vErrors.push(err17);
}
errors++;
}
if(1 !== data4){
const err18 = {instancePath:instancePath+"/format/version",schemaPath:"#/oneOf/2/properties/format/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
}
var valid5 = _errs20 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data3.name !== undefined){
const _errs22 = errors;
if(!(validate54(data3.name, {instancePath:instancePath+"/format/name",parentData:data3,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid5 = _errs22 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data3.realm !== undefined){
const _errs23 = errors;
if(!(validate56(data3.realm, {instancePath:instancePath+"/format/realm",parentData:data3,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid5 = _errs23 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data3.revision !== undefined){
const _errs24 = errors;
if(!(validate58(data3.revision, {instancePath:instancePath+"/format/revision",parentData:data3,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid5 = _errs24 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data3.components !== undefined){
const _errs25 = errors;
if(!(validate60(data3.components, {instancePath:instancePath+"/format/components",parentData:data3,parentDataProperty:"components",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate60.errors : vErrors.concat(validate60.errors);
errors = vErrors.length;
}
var valid5 = _errs25 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data3.entry !== undefined){
const _errs26 = errors;
if(!(validate54(data3.entry, {instancePath:instancePath+"/format/entry",parentData:data3,parentDataProperty:"entry",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid5 = _errs26 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data3.theme !== undefined){
const _errs27 = errors;
if(!(validate54(data3.theme, {instancePath:instancePath+"/format/theme",parentData:data3,parentDataProperty:"theme",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid5 = _errs27 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data3.themes !== undefined){
let data11 = data3.themes;
const _errs28 = errors;
if(errors === _errs28){
if(Array.isArray(data11)){
if(data11.length > 2){
const err19 = {instancePath:instancePath+"/format/themes",schemaPath:"#/oneOf/2/properties/format/properties/themes/maxItems",keyword:"maxItems",params:{limit: 2},message:"must NOT have more than 2 items"};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
}
else {
var valid6 = true;
const len0 = data11.length;
for(let i0=0; i0<len0; i0++){
const _errs30 = errors;
if(!(validate64(data11[i0], {instancePath:instancePath+"/format/themes/" + i0,parentData:data11,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
errors = vErrors.length;
}
var valid6 = _errs30 === errors;
if(!valid6){
break;
}
}
}
}
else {
const err20 = {instancePath:instancePath+"/format/themes",schemaPath:"#/oneOf/2/properties/format/properties/themes/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err20];
}
else {
vErrors.push(err20);
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
if(data3.screens !== undefined){
let data13 = data3.screens;
const _errs31 = errors;
if(errors === _errs31){
if(Array.isArray(data13)){
if(data13.length > 16){
const err21 = {instancePath:instancePath+"/format/screens",schemaPath:"#/oneOf/2/properties/format/properties/screens/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
}
errors++;
}
else {
var valid7 = true;
const len1 = data13.length;
for(let i1=0; i1<len1; i1++){
const _errs33 = errors;
if(!(validate67(data13[i1], {instancePath:instancePath+"/format/screens/" + i1,parentData:data13,parentDataProperty:i1,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate67.errors : vErrors.concat(validate67.errors);
errors = vErrors.length;
}
var valid7 = _errs33 === errors;
if(!valid7){
break;
}
}
}
}
else {
const err22 = {instancePath:instancePath+"/format/screens",schemaPath:"#/oneOf/2/properties/format/properties/screens/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err22];
}
else {
vErrors.push(err22);
}
errors++;
}
}
var valid5 = _errs31 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data3.bindings !== undefined){
let data15 = data3.bindings;
const _errs34 = errors;
if(errors === _errs34){
if(Array.isArray(data15)){
if(data15.length > 16){
const err23 = {instancePath:instancePath+"/format/bindings",schemaPath:"#/oneOf/2/properties/format/properties/bindings/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"};
if(vErrors === null){
vErrors = [err23];
}
else {
vErrors.push(err23);
}
errors++;
}
else {
var valid8 = true;
const len2 = data15.length;
for(let i2=0; i2<len2; i2++){
const _errs36 = errors;
if(!(validate73(data15[i2], {instancePath:instancePath+"/format/bindings/" + i2,parentData:data15,parentDataProperty:i2,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate73.errors : vErrors.concat(validate73.errors);
errors = vErrors.length;
}
var valid8 = _errs36 === errors;
if(!valid8){
break;
}
}
}
}
else {
const err24 = {instancePath:instancePath+"/format/bindings",schemaPath:"#/oneOf/2/properties/format/properties/bindings/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
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
if(data3.actions !== undefined){
let data17 = data3.actions;
const _errs37 = errors;
if(errors === _errs37){
if(Array.isArray(data17)){
if(data17.length > 16){
const err25 = {instancePath:instancePath+"/format/actions",schemaPath:"#/oneOf/2/properties/format/properties/actions/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"};
if(vErrors === null){
vErrors = [err25];
}
else {
vErrors.push(err25);
}
errors++;
}
else {
var valid9 = true;
const len3 = data17.length;
for(let i3=0; i3<len3; i3++){
const _errs39 = errors;
if(!(validate88(data17[i3], {instancePath:instancePath+"/format/actions/" + i3,parentData:data17,parentDataProperty:i3,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate88.errors : vErrors.concat(validate88.errors);
errors = vErrors.length;
}
var valid9 = _errs39 === errors;
if(!valid9){
break;
}
}
}
}
else {
const err26 = {instancePath:instancePath+"/format/actions",schemaPath:"#/oneOf/2/properties/format/properties/actions/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err26];
}
else {
vErrors.push(err26);
}
errors++;
}
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
else {
const err27 = {instancePath:instancePath+"/format",schemaPath:"#/oneOf/2/properties/format/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const _errs40 = errors;
if(errors === _errs40){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing5;
if((data.next_upload === undefined) && (missing5 = "next_upload")){
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
const _errs42 = errors;
for(const key5 in data){
if(!(key5 === "next_upload")){
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
if(_errs42 === errors){
if(data.next_upload !== undefined){
let data19 = data.next_upload;
const _errs43 = errors;
if(errors === _errs43){
if(data19 && typeof data19 == "object" && !Array.isArray(data19)){
let missing6;
if((((data19.proposal === undefined) && (missing6 = "proposal")) || ((data19.canonical === undefined) && (missing6 = "canonical"))) || ((data19.state === undefined) && (missing6 = "state"))){
const err31 = {instancePath:instancePath+"/next_upload",schemaPath:"#/oneOf/3/properties/next_upload/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
if(vErrors === null){
vErrors = [err31];
}
else {
vErrors.push(err31);
}
errors++;
}
else {
const _errs45 = errors;
for(const key6 in data19){
if(!(((key6 === "proposal") || (key6 === "canonical")) || (key6 === "state"))){
const err32 = {instancePath:instancePath+"/next_upload",schemaPath:"#/oneOf/3/properties/next_upload/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
if(_errs45 === errors){
if(data19.proposal !== undefined){
const _errs46 = errors;
if(!(validate140(data19.proposal, {instancePath:instancePath+"/next_upload/proposal",parentData:data19,parentDataProperty:"proposal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate140.errors : vErrors.concat(validate140.errors);
errors = vErrors.length;
}
var valid11 = _errs46 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data19.canonical !== undefined){
let data21 = data19.canonical;
const _errs47 = errors;
if(errors === _errs47){
if(typeof data21 === "string"){
if(func2(data21) > 65536){
const err33 = {instancePath:instancePath+"/next_upload/canonical",schemaPath:"#/oneOf/3/properties/next_upload/properties/canonical/maxLength",keyword:"maxLength",params:{limit: 65536},message:"must NOT have more than 65536 characters"};
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
const err34 = {instancePath:instancePath+"/next_upload/canonical",schemaPath:"#/oneOf/3/properties/next_upload/properties/canonical/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err34];
}
else {
vErrors.push(err34);
}
errors++;
}
}
var valid11 = _errs47 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data19.state !== undefined){
const _errs49 = errors;
if(!(validate304(data19.state, {instancePath:instancePath+"/next_upload/state",parentData:data19,parentDataProperty:"state",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate304.errors : vErrors.concat(validate304.errors);
errors = vErrors.length;
}
var valid11 = _errs49 === errors;
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
const err35 = {instancePath:instancePath+"/next_upload",schemaPath:"#/oneOf/3/properties/next_upload/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
var _valid0 = _errs40 === errors;
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
const _errs50 = errors;
if(errors === _errs50){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing7;
if((data.next_cleanup === undefined) && (missing7 = "next_cleanup")){
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
const _errs52 = errors;
for(const key7 in data){
if(!(key7 === "next_cleanup")){
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
if(_errs52 === errors){
if(data.next_cleanup !== undefined){
let data23 = data.next_cleanup;
const _errs53 = errors;
if(errors === _errs53){
if(data23 && typeof data23 == "object" && !Array.isArray(data23)){
let missing8;
if(((data23.proposal === undefined) && (missing8 = "proposal")) || ((data23.state === undefined) && (missing8 = "state"))){
const err39 = {instancePath:instancePath+"/next_cleanup",schemaPath:"#/oneOf/4/properties/next_cleanup/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
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
for(const key8 in data23){
if(!((key8 === "proposal") || (key8 === "state"))){
const err40 = {instancePath:instancePath+"/next_cleanup",schemaPath:"#/oneOf/4/properties/next_cleanup/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
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
if(data23.proposal !== undefined){
const _errs56 = errors;
if(!(validate140(data23.proposal, {instancePath:instancePath+"/next_cleanup/proposal",parentData:data23,parentDataProperty:"proposal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate140.errors : vErrors.concat(validate140.errors);
errors = vErrors.length;
}
var valid13 = _errs56 === errors;
}
else {
var valid13 = true;
}
if(valid13){
if(data23.state !== undefined){
const _errs57 = errors;
if(!(validate304(data23.state, {instancePath:instancePath+"/next_cleanup/state",parentData:data23,parentDataProperty:"state",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate304.errors : vErrors.concat(validate304.errors);
errors = vErrors.length;
}
var valid13 = _errs57 === errors;
}
else {
var valid13 = true;
}
}
}
}
}
else {
const err41 = {instancePath:instancePath+"/next_cleanup",schemaPath:"#/oneOf/4/properties/next_cleanup/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err42 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err42];
}
else {
vErrors.push(err42);
}
errors++;
}
}
var _valid0 = _errs50 === errors;
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
const _errs58 = errors;
if(errors === _errs58){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing9;
if((data.prepare === undefined) && (missing9 = "prepare")){
const err43 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
if(vErrors === null){
vErrors = [err43];
}
else {
vErrors.push(err43);
}
errors++;
}
else {
const _errs60 = errors;
for(const key9 in data){
if(!(key9 === "prepare")){
const err44 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err44];
}
else {
vErrors.push(err44);
}
errors++;
break;
}
}
if(_errs60 === errors){
if(data.prepare !== undefined){
let data26 = data.prepare;
const _errs61 = errors;
if(errors === _errs61){
if(data26 && typeof data26 == "object" && !Array.isArray(data26)){
let missing10;
if((((data26.principal === undefined) && (missing10 = "principal")) || ((data26.sequence === undefined) && (missing10 = "sequence"))) || ((data26.command === undefined) && (missing10 = "command"))){
const err45 = {instancePath:instancePath+"/prepare",schemaPath:"#/oneOf/5/properties/prepare/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"};
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
for(const key10 in data26){
if(!(((key10 === "principal") || (key10 === "sequence")) || (key10 === "command"))){
const err46 = {instancePath:instancePath+"/prepare",schemaPath:"#/oneOf/5/properties/prepare/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"};
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
if(data26.principal !== undefined){
const _errs64 = errors;
if(!(validate56(data26.principal, {instancePath:instancePath+"/prepare/principal",parentData:data26,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid15 = _errs64 === errors;
}
else {
var valid15 = true;
}
if(valid15){
if(data26.sequence !== undefined){
const _errs65 = errors;
if(!(validate58(data26.sequence, {instancePath:instancePath+"/prepare/sequence",parentData:data26,parentDataProperty:"sequence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid15 = _errs65 === errors;
}
else {
var valid15 = true;
}
if(valid15){
if(data26.command !== undefined){
const _errs66 = errors;
if(!(validate195(data26.command, {instancePath:instancePath+"/prepare/command",parentData:data26,parentDataProperty:"command",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate195.errors : vErrors.concat(validate195.errors);
errors = vErrors.length;
}
var valid15 = _errs66 === errors;
}
else {
var valid15 = true;
}
}
}
}
}
}
else {
const err47 = {instancePath:instancePath+"/prepare",schemaPath:"#/oneOf/5/properties/prepare/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
}
else {
const err48 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err48];
}
else {
vErrors.push(err48);
}
errors++;
}
}
var _valid0 = _errs58 === errors;
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
const _errs67 = errors;
if(errors === _errs67){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing11;
if((data.submit === undefined) && (missing11 = "submit")){
const err49 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
if(vErrors === null){
vErrors = [err49];
}
else {
vErrors.push(err49);
}
errors++;
}
else {
const _errs69 = errors;
for(const key11 in data){
if(!(key11 === "submit")){
const err50 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err50];
}
else {
vErrors.push(err50);
}
errors++;
break;
}
}
if(_errs69 === errors){
if(data.submit !== undefined){
if(!(validate257(data.submit, {instancePath:instancePath+"/submit",parentData:data,parentDataProperty:"submit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate257.errors : vErrors.concat(validate257.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err51 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err51];
}
else {
vErrors.push(err51);
}
errors++;
}
}
var _valid0 = _errs67 === errors;
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
const _errs71 = errors;
if(errors === _errs71){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing12;
if((data.prepare_read === undefined) && (missing12 = "prepare_read")){
const err52 = {instancePath,schemaPath:"#/oneOf/7/required",keyword:"required",params:{missingProperty: missing12},message:"must have required property '"+missing12+"'"};
if(vErrors === null){
vErrors = [err52];
}
else {
vErrors.push(err52);
}
errors++;
}
else {
const _errs73 = errors;
for(const key12 in data){
if(!(key12 === "prepare_read")){
const err53 = {instancePath,schemaPath:"#/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key12},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err53];
}
else {
vErrors.push(err53);
}
errors++;
break;
}
}
if(_errs73 === errors){
if(data.prepare_read !== undefined){
let data31 = data.prepare_read;
const _errs74 = errors;
if(errors === _errs74){
if(data31 && typeof data31 == "object" && !Array.isArray(data31)){
let missing13;
if(((data31.principal === undefined) && (missing13 = "principal")) || ((data31.selection === undefined) && (missing13 = "selection"))){
const err54 = {instancePath:instancePath+"/prepare_read",schemaPath:"#/oneOf/7/properties/prepare_read/required",keyword:"required",params:{missingProperty: missing13},message:"must have required property '"+missing13+"'"};
if(vErrors === null){
vErrors = [err54];
}
else {
vErrors.push(err54);
}
errors++;
}
else {
const _errs76 = errors;
for(const key13 in data31){
if(!((key13 === "principal") || (key13 === "selection"))){
const err55 = {instancePath:instancePath+"/prepare_read",schemaPath:"#/oneOf/7/properties/prepare_read/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key13},message:"must NOT have additional properties"};
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
if(_errs76 === errors){
if(data31.principal !== undefined){
const _errs77 = errors;
if(!(validate56(data31.principal, {instancePath:instancePath+"/prepare_read/principal",parentData:data31,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid18 = _errs77 === errors;
}
else {
var valid18 = true;
}
if(valid18){
if(data31.selection !== undefined){
const _errs78 = errors;
if(!(validate268(data31.selection, {instancePath:instancePath+"/prepare_read/selection",parentData:data31,parentDataProperty:"selection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate268.errors : vErrors.concat(validate268.errors);
errors = vErrors.length;
}
var valid18 = _errs78 === errors;
}
else {
var valid18 = true;
}
}
}
}
}
else {
const err56 = {instancePath:instancePath+"/prepare_read",schemaPath:"#/oneOf/7/properties/prepare_read/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err57 = {instancePath,schemaPath:"#/oneOf/7/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err57];
}
else {
vErrors.push(err57);
}
errors++;
}
}
var _valid0 = _errs71 === errors;
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
const _errs79 = errors;
if(errors === _errs79){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing14;
if((data.read === undefined) && (missing14 = "read")){
const err58 = {instancePath,schemaPath:"#/oneOf/8/required",keyword:"required",params:{missingProperty: missing14},message:"must have required property '"+missing14+"'"};
if(vErrors === null){
vErrors = [err58];
}
else {
vErrors.push(err58);
}
errors++;
}
else {
const _errs81 = errors;
for(const key14 in data){
if(!(key14 === "read")){
const err59 = {instancePath,schemaPath:"#/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key14},message:"must NOT have additional properties"};
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
if(_errs81 === errors){
if(data.read !== undefined){
if(!(validate285(data.read, {instancePath:instancePath+"/read",parentData:data,parentDataProperty:"read",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate285.errors : vErrors.concat(validate285.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err60 = {instancePath,schemaPath:"#/oneOf/8/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err60];
}
else {
vErrors.push(err60);
}
errors++;
}
}
var _valid0 = _errs79 === errors;
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
}
}
}
}
}
}
}
}
if(!valid0){
const err61 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err61];
}
else {
vErrors.push(err61);
}
errors++;
validate477.errors = vErrors;
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
validate477.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate477.evaluated = {"dynamicProps":true,"dynamicItems":false};

export const HostResponse = validate499;
const schema150 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["info"],"properties":{"info":{"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"https://transit.invalid/generated-validator/31"},"program_bytes":{"$ref":"https://transit.invalid/generated-validator/9"},"part_bytes":{"$ref":"https://transit.invalid/generated-validator/3"}},"required":["scope"]}}},{"type":"object","additionalProperties":false,"required":["compiled"],"properties":{"compiled":{"type":"object","additionalProperties":false,"properties":{"definition":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","const":1},"name":{"$ref":"https://transit.invalid/generated-validator/0"},"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"revision":{"$ref":"https://transit.invalid/generated-validator/2"},"components":{"$ref":"https://transit.invalid/generated-validator/3"},"entry":{"$ref":"https://transit.invalid/generated-validator/0"},"theme":{"$ref":"https://transit.invalid/generated-validator/0"},"themes":{"type":"array","maxItems":2,"items":{"$ref":"#/$defs/Theme"}},"screens":{"type":"array","maxItems":16,"items":{"$ref":"#/$defs/Screen"}},"bindings":{"type":"array","maxItems":16,"items":{"$ref":"#/$defs/Binding"}},"actions":{"type":"array","maxItems":16,"items":{"$ref":"#/$defs/Action"}}},"required":["name","realm","revision","entry","theme","themes","screens","bindings","actions"]},"canonical":{"type":"string","maxLength":65536},"spec":{"$ref":"https://transit.invalid/generated-validator/10"}},"required":["definition","canonical","spec"]}}},{"type":"object","additionalProperties":false,"required":["builtin"],"properties":{"builtin":{"type":"object","additionalProperties":false,"properties":{"definition":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","const":1},"name":{"$ref":"https://transit.invalid/generated-validator/0"},"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"revision":{"$ref":"https://transit.invalid/generated-validator/2"},"components":{"$ref":"https://transit.invalid/generated-validator/3"},"entry":{"$ref":"https://transit.invalid/generated-validator/0"},"theme":{"$ref":"https://transit.invalid/generated-validator/0"},"themes":{"type":"array","maxItems":2,"items":{"$ref":"#/$defs/Theme"}},"screens":{"type":"array","maxItems":16,"items":{"$ref":"#/$defs/Screen"}},"bindings":{"type":"array","maxItems":16,"items":{"$ref":"#/$defs/Binding"}},"actions":{"type":"array","maxItems":16,"items":{"$ref":"#/$defs/Action"}}},"required":["name","realm","revision","entry","theme","themes","screens","bindings","actions"]},"canonical":{"type":"string","maxLength":65536},"spec":{"$ref":"https://transit.invalid/generated-validator/10"}},"required":["definition","canonical","spec"]}}},{"type":"object","additionalProperties":false,"required":["published"],"properties":{"published":{"type":"object","additionalProperties":false,"properties":{"head":{"$ref":"https://transit.invalid/generated-validator/19"},"compiled":{"type":"object","additionalProperties":false,"properties":{"definition":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","const":1},"name":{"$ref":"https://transit.invalid/generated-validator/0"},"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"revision":{"$ref":"https://transit.invalid/generated-validator/2"},"components":{"$ref":"https://transit.invalid/generated-validator/3"},"entry":{"$ref":"https://transit.invalid/generated-validator/0"},"theme":{"$ref":"https://transit.invalid/generated-validator/0"},"themes":{"type":"array","maxItems":2,"items":{"$ref":"#/$defs/Theme"}},"screens":{"type":"array","maxItems":16,"items":{"$ref":"#/$defs/Screen"}},"bindings":{"type":"array","maxItems":16,"items":{"$ref":"#/$defs/Binding"}},"actions":{"type":"array","maxItems":16,"items":{"$ref":"#/$defs/Action"}}},"required":["name","realm","revision","entry","theme","themes","screens","bindings","actions"]},"canonical":{"type":"string","maxLength":65536},"spec":{"$ref":"https://transit.invalid/generated-validator/10"}},"required":["definition","canonical","spec"]}},"required":["head","compiled"]}}},{"type":"object","additionalProperties":false,"required":["prepared"],"properties":{"prepared":{"$ref":"https://transit.invalid/generated-validator/32"}}},{"type":"object","additionalProperties":false,"required":["admitted"],"properties":{"admitted":{"type":"object","additionalProperties":false,"properties":{"position":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["position"]}}},{"type":"object","additionalProperties":false,"required":["next_upload"],"properties":{"next_upload":{"$ref":"https://transit.invalid/generated-validator/107"}}},{"type":"object","additionalProperties":false,"required":["next_cleanup"],"properties":{"next_cleanup":{"$ref":"https://transit.invalid/generated-validator/107"}}},{"type":"object","additionalProperties":false,"required":["prepared_read"],"properties":{"prepared_read":{"$ref":"https://transit.invalid/generated-validator/39"}}},{"type":"object","additionalProperties":false,"required":["observation"],"properties":{"observation":{"$ref":"https://transit.invalid/generated-validator/106"}}}]};
const schema151 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/30"},{"type":"null"}]};

function validate539(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate539.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate195(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate195.errors : vErrors.concat(validate195.errors);
errors = vErrors.length;
}
else {
var props0 = validate195.evaluated.props;
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
validate539.errors = vErrors;
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
validate539.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate539.evaluated = {"dynamicProps":true,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
let passing0 = null;
const _errs1 = errors;
if(!(validate292(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate292.errors : vErrors.concat(validate292.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs2 = errors;
if(!(validate303(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate303.errors : vErrors.concat(validate303.errors);
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
validate291.errors = vErrors;
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
validate291.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate291.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate499(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate499.evaluated;
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
if((data.info === undefined) && (missing0 = "info")){
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
if(!(key0 === "info")){
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
if(data.info !== undefined){
let data0 = data.info;
const _errs4 = errors;
if(errors === _errs4){
if(data0 && typeof data0 == "object" && !Array.isArray(data0)){
let missing1;
if((data0.scope === undefined) && (missing1 = "scope")){
const err2 = {instancePath:instancePath+"/info",schemaPath:"#/oneOf/0/properties/info/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
if(!(((key1 === "scope") || (key1 === "program_bytes")) || (key1 === "part_bytes"))){
const err3 = {instancePath:instancePath+"/info",schemaPath:"#/oneOf/0/properties/info/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(data0.scope !== undefined){
const _errs7 = errors;
if(!(validate233(data0.scope, {instancePath:instancePath+"/info/scope",parentData:data0,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate233.errors : vErrors.concat(validate233.errors);
errors = vErrors.length;
}
var valid2 = _errs7 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data0.program_bytes !== undefined){
const _errs8 = errors;
if(!(validate147(data0.program_bytes, {instancePath:instancePath+"/info/program_bytes",parentData:data0,parentDataProperty:"program_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate147.errors : vErrors.concat(validate147.errors);
errors = vErrors.length;
}
var valid2 = _errs8 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data0.part_bytes !== undefined){
const _errs9 = errors;
if(!(validate60(data0.part_bytes, {instancePath:instancePath+"/info/part_bytes",parentData:data0,parentDataProperty:"part_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate60.errors : vErrors.concat(validate60.errors);
errors = vErrors.length;
}
var valid2 = _errs9 === errors;
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
const err4 = {instancePath:instancePath+"/info",schemaPath:"#/oneOf/0/properties/info/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
}
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err5];
}
else {
vErrors.push(err5);
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
const _errs10 = errors;
if(errors === _errs10){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing2;
if((data.compiled === undefined) && (missing2 = "compiled")){
const err6 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
if(vErrors === null){
vErrors = [err6];
}
else {
vErrors.push(err6);
}
errors++;
}
else {
const _errs12 = errors;
for(const key2 in data){
if(!(key2 === "compiled")){
const err7 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(_errs12 === errors){
if(data.compiled !== undefined){
let data4 = data.compiled;
const _errs13 = errors;
if(errors === _errs13){
if(data4 && typeof data4 == "object" && !Array.isArray(data4)){
let missing3;
if((((data4.definition === undefined) && (missing3 = "definition")) || ((data4.canonical === undefined) && (missing3 = "canonical"))) || ((data4.spec === undefined) && (missing3 = "spec"))){
const err8 = {instancePath:instancePath+"/compiled",schemaPath:"#/oneOf/1/properties/compiled/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
if(vErrors === null){
vErrors = [err8];
}
else {
vErrors.push(err8);
}
errors++;
}
else {
const _errs15 = errors;
for(const key3 in data4){
if(!(((key3 === "definition") || (key3 === "canonical")) || (key3 === "spec"))){
const err9 = {instancePath:instancePath+"/compiled",schemaPath:"#/oneOf/1/properties/compiled/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
break;
}
}
if(_errs15 === errors){
if(data4.definition !== undefined){
let data5 = data4.definition;
const _errs16 = errors;
if(errors === _errs16){
if(data5 && typeof data5 == "object" && !Array.isArray(data5)){
let missing4;
if((((((((((data5.name === undefined) && (missing4 = "name")) || ((data5.realm === undefined) && (missing4 = "realm"))) || ((data5.revision === undefined) && (missing4 = "revision"))) || ((data5.entry === undefined) && (missing4 = "entry"))) || ((data5.theme === undefined) && (missing4 = "theme"))) || ((data5.themes === undefined) && (missing4 = "themes"))) || ((data5.screens === undefined) && (missing4 = "screens"))) || ((data5.bindings === undefined) && (missing4 = "bindings"))) || ((data5.actions === undefined) && (missing4 = "actions"))){
const err10 = {instancePath:instancePath+"/compiled/definition",schemaPath:"#/oneOf/1/properties/compiled/properties/definition/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
}
else {
const _errs18 = errors;
for(const key4 in data5){
if(!(func1.call(schema150.oneOf[1].properties.compiled.properties.definition.properties, key4))){
const err11 = {instancePath:instancePath+"/compiled/definition",schemaPath:"#/oneOf/1/properties/compiled/properties/definition/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(_errs18 === errors){
if(data5.version !== undefined){
let data6 = data5.version;
const _errs19 = errors;
if(!(((typeof data6 == "number") && (!(data6 % 1) && !isNaN(data6))) && (isFinite(data6)))){
const err12 = {instancePath:instancePath+"/compiled/definition/version",schemaPath:"#/oneOf/1/properties/compiled/properties/definition/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
}
if(1 !== data6){
const err13 = {instancePath:instancePath+"/compiled/definition/version",schemaPath:"#/oneOf/1/properties/compiled/properties/definition/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"};
if(vErrors === null){
vErrors = [err13];
}
else {
vErrors.push(err13);
}
errors++;
}
var valid5 = _errs19 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data5.name !== undefined){
const _errs21 = errors;
if(!(validate54(data5.name, {instancePath:instancePath+"/compiled/definition/name",parentData:data5,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid5 = _errs21 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data5.realm !== undefined){
const _errs22 = errors;
if(!(validate56(data5.realm, {instancePath:instancePath+"/compiled/definition/realm",parentData:data5,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid5 = _errs22 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data5.revision !== undefined){
const _errs23 = errors;
if(!(validate58(data5.revision, {instancePath:instancePath+"/compiled/definition/revision",parentData:data5,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid5 = _errs23 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data5.components !== undefined){
const _errs24 = errors;
if(!(validate60(data5.components, {instancePath:instancePath+"/compiled/definition/components",parentData:data5,parentDataProperty:"components",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate60.errors : vErrors.concat(validate60.errors);
errors = vErrors.length;
}
var valid5 = _errs24 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data5.entry !== undefined){
const _errs25 = errors;
if(!(validate54(data5.entry, {instancePath:instancePath+"/compiled/definition/entry",parentData:data5,parentDataProperty:"entry",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid5 = _errs25 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data5.theme !== undefined){
const _errs26 = errors;
if(!(validate54(data5.theme, {instancePath:instancePath+"/compiled/definition/theme",parentData:data5,parentDataProperty:"theme",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid5 = _errs26 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data5.themes !== undefined){
let data13 = data5.themes;
const _errs27 = errors;
if(errors === _errs27){
if(Array.isArray(data13)){
if(data13.length > 2){
const err14 = {instancePath:instancePath+"/compiled/definition/themes",schemaPath:"#/oneOf/1/properties/compiled/properties/definition/properties/themes/maxItems",keyword:"maxItems",params:{limit: 2},message:"must NOT have more than 2 items"};
if(vErrors === null){
vErrors = [err14];
}
else {
vErrors.push(err14);
}
errors++;
}
else {
var valid6 = true;
const len0 = data13.length;
for(let i0=0; i0<len0; i0++){
const _errs29 = errors;
if(!(validate64(data13[i0], {instancePath:instancePath+"/compiled/definition/themes/" + i0,parentData:data13,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
errors = vErrors.length;
}
var valid6 = _errs29 === errors;
if(!valid6){
break;
}
}
}
}
else {
const err15 = {instancePath:instancePath+"/compiled/definition/themes",schemaPath:"#/oneOf/1/properties/compiled/properties/definition/properties/themes/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
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
if(data5.screens !== undefined){
let data15 = data5.screens;
const _errs30 = errors;
if(errors === _errs30){
if(Array.isArray(data15)){
if(data15.length > 16){
const err16 = {instancePath:instancePath+"/compiled/definition/screens",schemaPath:"#/oneOf/1/properties/compiled/properties/definition/properties/screens/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"};
if(vErrors === null){
vErrors = [err16];
}
else {
vErrors.push(err16);
}
errors++;
}
else {
var valid7 = true;
const len1 = data15.length;
for(let i1=0; i1<len1; i1++){
const _errs32 = errors;
if(!(validate67(data15[i1], {instancePath:instancePath+"/compiled/definition/screens/" + i1,parentData:data15,parentDataProperty:i1,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate67.errors : vErrors.concat(validate67.errors);
errors = vErrors.length;
}
var valid7 = _errs32 === errors;
if(!valid7){
break;
}
}
}
}
else {
const err17 = {instancePath:instancePath+"/compiled/definition/screens",schemaPath:"#/oneOf/1/properties/compiled/properties/definition/properties/screens/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err17];
}
else {
vErrors.push(err17);
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
if(data5.bindings !== undefined){
let data17 = data5.bindings;
const _errs33 = errors;
if(errors === _errs33){
if(Array.isArray(data17)){
if(data17.length > 16){
const err18 = {instancePath:instancePath+"/compiled/definition/bindings",schemaPath:"#/oneOf/1/properties/compiled/properties/definition/properties/bindings/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
}
else {
var valid8 = true;
const len2 = data17.length;
for(let i2=0; i2<len2; i2++){
const _errs35 = errors;
if(!(validate73(data17[i2], {instancePath:instancePath+"/compiled/definition/bindings/" + i2,parentData:data17,parentDataProperty:i2,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate73.errors : vErrors.concat(validate73.errors);
errors = vErrors.length;
}
var valid8 = _errs35 === errors;
if(!valid8){
break;
}
}
}
}
else {
const err19 = {instancePath:instancePath+"/compiled/definition/bindings",schemaPath:"#/oneOf/1/properties/compiled/properties/definition/properties/bindings/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
}
}
var valid5 = _errs33 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data5.actions !== undefined){
let data19 = data5.actions;
const _errs36 = errors;
if(errors === _errs36){
if(Array.isArray(data19)){
if(data19.length > 16){
const err20 = {instancePath:instancePath+"/compiled/definition/actions",schemaPath:"#/oneOf/1/properties/compiled/properties/definition/properties/actions/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"};
if(vErrors === null){
vErrors = [err20];
}
else {
vErrors.push(err20);
}
errors++;
}
else {
var valid9 = true;
const len3 = data19.length;
for(let i3=0; i3<len3; i3++){
const _errs38 = errors;
if(!(validate88(data19[i3], {instancePath:instancePath+"/compiled/definition/actions/" + i3,parentData:data19,parentDataProperty:i3,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate88.errors : vErrors.concat(validate88.errors);
errors = vErrors.length;
}
var valid9 = _errs38 === errors;
if(!valid9){
break;
}
}
}
}
else {
const err21 = {instancePath:instancePath+"/compiled/definition/actions",schemaPath:"#/oneOf/1/properties/compiled/properties/definition/properties/actions/type",keyword:"type",params:{type: "array"},message:"must be array"};
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
}
}
}
}
}
}
}
}
else {
const err22 = {instancePath:instancePath+"/compiled/definition",schemaPath:"#/oneOf/1/properties/compiled/properties/definition/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err22];
}
else {
vErrors.push(err22);
}
errors++;
}
}
var valid4 = _errs16 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data4.canonical !== undefined){
let data21 = data4.canonical;
const _errs39 = errors;
if(errors === _errs39){
if(typeof data21 === "string"){
if(func2(data21) > 65536){
const err23 = {instancePath:instancePath+"/compiled/canonical",schemaPath:"#/oneOf/1/properties/compiled/properties/canonical/maxLength",keyword:"maxLength",params:{limit: 65536},message:"must NOT have more than 65536 characters"};
if(vErrors === null){
vErrors = [err23];
}
else {
vErrors.push(err23);
}
errors++;
}
}
else {
const err24 = {instancePath:instancePath+"/compiled/canonical",schemaPath:"#/oneOf/1/properties/compiled/properties/canonical/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
}
errors++;
}
}
var valid4 = _errs39 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data4.spec !== undefined){
const _errs41 = errors;
if(!(validate146(data4.spec, {instancePath:instancePath+"/compiled/spec",parentData:data4,parentDataProperty:"spec",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
errors = vErrors.length;
}
var valid4 = _errs41 === errors;
}
else {
var valid4 = true;
}
}
}
}
}
}
else {
const err25 = {instancePath:instancePath+"/compiled",schemaPath:"#/oneOf/1/properties/compiled/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err25];
}
else {
vErrors.push(err25);
}
errors++;
}
}
}
}
}
}
else {
const err26 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err26];
}
else {
vErrors.push(err26);
}
errors++;
}
}
var _valid0 = _errs10 === errors;
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
const _errs42 = errors;
if(errors === _errs42){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing5;
if((data.builtin === undefined) && (missing5 = "builtin")){
const err27 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
if(vErrors === null){
vErrors = [err27];
}
else {
vErrors.push(err27);
}
errors++;
}
else {
const _errs44 = errors;
for(const key5 in data){
if(!(key5 === "builtin")){
const err28 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(_errs44 === errors){
if(data.builtin !== undefined){
let data23 = data.builtin;
const _errs45 = errors;
if(errors === _errs45){
if(data23 && typeof data23 == "object" && !Array.isArray(data23)){
let missing6;
if((((data23.definition === undefined) && (missing6 = "definition")) || ((data23.canonical === undefined) && (missing6 = "canonical"))) || ((data23.spec === undefined) && (missing6 = "spec"))){
const err29 = {instancePath:instancePath+"/builtin",schemaPath:"#/oneOf/2/properties/builtin/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
if(vErrors === null){
vErrors = [err29];
}
else {
vErrors.push(err29);
}
errors++;
}
else {
const _errs47 = errors;
for(const key6 in data23){
if(!(((key6 === "definition") || (key6 === "canonical")) || (key6 === "spec"))){
const err30 = {instancePath:instancePath+"/builtin",schemaPath:"#/oneOf/2/properties/builtin/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
if(_errs47 === errors){
if(data23.definition !== undefined){
let data24 = data23.definition;
const _errs48 = errors;
if(errors === _errs48){
if(data24 && typeof data24 == "object" && !Array.isArray(data24)){
let missing7;
if((((((((((data24.name === undefined) && (missing7 = "name")) || ((data24.realm === undefined) && (missing7 = "realm"))) || ((data24.revision === undefined) && (missing7 = "revision"))) || ((data24.entry === undefined) && (missing7 = "entry"))) || ((data24.theme === undefined) && (missing7 = "theme"))) || ((data24.themes === undefined) && (missing7 = "themes"))) || ((data24.screens === undefined) && (missing7 = "screens"))) || ((data24.bindings === undefined) && (missing7 = "bindings"))) || ((data24.actions === undefined) && (missing7 = "actions"))){
const err31 = {instancePath:instancePath+"/builtin/definition",schemaPath:"#/oneOf/2/properties/builtin/properties/definition/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
if(vErrors === null){
vErrors = [err31];
}
else {
vErrors.push(err31);
}
errors++;
}
else {
const _errs50 = errors;
for(const key7 in data24){
if(!(func1.call(schema150.oneOf[2].properties.builtin.properties.definition.properties, key7))){
const err32 = {instancePath:instancePath+"/builtin/definition",schemaPath:"#/oneOf/2/properties/builtin/properties/definition/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
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
if(_errs50 === errors){
if(data24.version !== undefined){
let data25 = data24.version;
const _errs51 = errors;
if(!(((typeof data25 == "number") && (!(data25 % 1) && !isNaN(data25))) && (isFinite(data25)))){
const err33 = {instancePath:instancePath+"/builtin/definition/version",schemaPath:"#/oneOf/2/properties/builtin/properties/definition/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
if(1 !== data25){
const err34 = {instancePath:instancePath+"/builtin/definition/version",schemaPath:"#/oneOf/2/properties/builtin/properties/definition/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"};
if(vErrors === null){
vErrors = [err34];
}
else {
vErrors.push(err34);
}
errors++;
}
var valid12 = _errs51 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data24.name !== undefined){
const _errs53 = errors;
if(!(validate54(data24.name, {instancePath:instancePath+"/builtin/definition/name",parentData:data24,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid12 = _errs53 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data24.realm !== undefined){
const _errs54 = errors;
if(!(validate56(data24.realm, {instancePath:instancePath+"/builtin/definition/realm",parentData:data24,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid12 = _errs54 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data24.revision !== undefined){
const _errs55 = errors;
if(!(validate58(data24.revision, {instancePath:instancePath+"/builtin/definition/revision",parentData:data24,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid12 = _errs55 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data24.components !== undefined){
const _errs56 = errors;
if(!(validate60(data24.components, {instancePath:instancePath+"/builtin/definition/components",parentData:data24,parentDataProperty:"components",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate60.errors : vErrors.concat(validate60.errors);
errors = vErrors.length;
}
var valid12 = _errs56 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data24.entry !== undefined){
const _errs57 = errors;
if(!(validate54(data24.entry, {instancePath:instancePath+"/builtin/definition/entry",parentData:data24,parentDataProperty:"entry",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid12 = _errs57 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data24.theme !== undefined){
const _errs58 = errors;
if(!(validate54(data24.theme, {instancePath:instancePath+"/builtin/definition/theme",parentData:data24,parentDataProperty:"theme",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid12 = _errs58 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data24.themes !== undefined){
let data32 = data24.themes;
const _errs59 = errors;
if(errors === _errs59){
if(Array.isArray(data32)){
if(data32.length > 2){
const err35 = {instancePath:instancePath+"/builtin/definition/themes",schemaPath:"#/oneOf/2/properties/builtin/properties/definition/properties/themes/maxItems",keyword:"maxItems",params:{limit: 2},message:"must NOT have more than 2 items"};
if(vErrors === null){
vErrors = [err35];
}
else {
vErrors.push(err35);
}
errors++;
}
else {
var valid13 = true;
const len4 = data32.length;
for(let i4=0; i4<len4; i4++){
const _errs61 = errors;
if(!(validate64(data32[i4], {instancePath:instancePath+"/builtin/definition/themes/" + i4,parentData:data32,parentDataProperty:i4,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
errors = vErrors.length;
}
var valid13 = _errs61 === errors;
if(!valid13){
break;
}
}
}
}
else {
const err36 = {instancePath:instancePath+"/builtin/definition/themes",schemaPath:"#/oneOf/2/properties/builtin/properties/definition/properties/themes/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
}
}
var valid12 = _errs59 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data24.screens !== undefined){
let data34 = data24.screens;
const _errs62 = errors;
if(errors === _errs62){
if(Array.isArray(data34)){
if(data34.length > 16){
const err37 = {instancePath:instancePath+"/builtin/definition/screens",schemaPath:"#/oneOf/2/properties/builtin/properties/definition/properties/screens/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"};
if(vErrors === null){
vErrors = [err37];
}
else {
vErrors.push(err37);
}
errors++;
}
else {
var valid14 = true;
const len5 = data34.length;
for(let i5=0; i5<len5; i5++){
const _errs64 = errors;
if(!(validate67(data34[i5], {instancePath:instancePath+"/builtin/definition/screens/" + i5,parentData:data34,parentDataProperty:i5,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate67.errors : vErrors.concat(validate67.errors);
errors = vErrors.length;
}
var valid14 = _errs64 === errors;
if(!valid14){
break;
}
}
}
}
else {
const err38 = {instancePath:instancePath+"/builtin/definition/screens",schemaPath:"#/oneOf/2/properties/builtin/properties/definition/properties/screens/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err38];
}
else {
vErrors.push(err38);
}
errors++;
}
}
var valid12 = _errs62 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data24.bindings !== undefined){
let data36 = data24.bindings;
const _errs65 = errors;
if(errors === _errs65){
if(Array.isArray(data36)){
if(data36.length > 16){
const err39 = {instancePath:instancePath+"/builtin/definition/bindings",schemaPath:"#/oneOf/2/properties/builtin/properties/definition/properties/bindings/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"};
if(vErrors === null){
vErrors = [err39];
}
else {
vErrors.push(err39);
}
errors++;
}
else {
var valid15 = true;
const len6 = data36.length;
for(let i6=0; i6<len6; i6++){
const _errs67 = errors;
if(!(validate73(data36[i6], {instancePath:instancePath+"/builtin/definition/bindings/" + i6,parentData:data36,parentDataProperty:i6,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate73.errors : vErrors.concat(validate73.errors);
errors = vErrors.length;
}
var valid15 = _errs67 === errors;
if(!valid15){
break;
}
}
}
}
else {
const err40 = {instancePath:instancePath+"/builtin/definition/bindings",schemaPath:"#/oneOf/2/properties/builtin/properties/definition/properties/bindings/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err40];
}
else {
vErrors.push(err40);
}
errors++;
}
}
var valid12 = _errs65 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data24.actions !== undefined){
let data38 = data24.actions;
const _errs68 = errors;
if(errors === _errs68){
if(Array.isArray(data38)){
if(data38.length > 16){
const err41 = {instancePath:instancePath+"/builtin/definition/actions",schemaPath:"#/oneOf/2/properties/builtin/properties/definition/properties/actions/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"};
if(vErrors === null){
vErrors = [err41];
}
else {
vErrors.push(err41);
}
errors++;
}
else {
var valid16 = true;
const len7 = data38.length;
for(let i7=0; i7<len7; i7++){
const _errs70 = errors;
if(!(validate88(data38[i7], {instancePath:instancePath+"/builtin/definition/actions/" + i7,parentData:data38,parentDataProperty:i7,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate88.errors : vErrors.concat(validate88.errors);
errors = vErrors.length;
}
var valid16 = _errs70 === errors;
if(!valid16){
break;
}
}
}
}
else {
const err42 = {instancePath:instancePath+"/builtin/definition/actions",schemaPath:"#/oneOf/2/properties/builtin/properties/definition/properties/actions/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err42];
}
else {
vErrors.push(err42);
}
errors++;
}
}
var valid12 = _errs68 === errors;
}
else {
var valid12 = true;
}
}
}
}
}
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
const err43 = {instancePath:instancePath+"/builtin/definition",schemaPath:"#/oneOf/2/properties/builtin/properties/definition/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err43];
}
else {
vErrors.push(err43);
}
errors++;
}
}
var valid11 = _errs48 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data23.canonical !== undefined){
let data40 = data23.canonical;
const _errs71 = errors;
if(errors === _errs71){
if(typeof data40 === "string"){
if(func2(data40) > 65536){
const err44 = {instancePath:instancePath+"/builtin/canonical",schemaPath:"#/oneOf/2/properties/builtin/properties/canonical/maxLength",keyword:"maxLength",params:{limit: 65536},message:"must NOT have more than 65536 characters"};
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
const err45 = {instancePath:instancePath+"/builtin/canonical",schemaPath:"#/oneOf/2/properties/builtin/properties/canonical/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err45];
}
else {
vErrors.push(err45);
}
errors++;
}
}
var valid11 = _errs71 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data23.spec !== undefined){
const _errs73 = errors;
if(!(validate146(data23.spec, {instancePath:instancePath+"/builtin/spec",parentData:data23,parentDataProperty:"spec",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
errors = vErrors.length;
}
var valid11 = _errs73 === errors;
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
const err46 = {instancePath:instancePath+"/builtin",schemaPath:"#/oneOf/2/properties/builtin/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err47 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err47];
}
else {
vErrors.push(err47);
}
errors++;
}
}
var _valid0 = _errs42 === errors;
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
const _errs74 = errors;
if(errors === _errs74){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing8;
if((data.published === undefined) && (missing8 = "published")){
const err48 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
if(vErrors === null){
vErrors = [err48];
}
else {
vErrors.push(err48);
}
errors++;
}
else {
const _errs76 = errors;
for(const key8 in data){
if(!(key8 === "published")){
const err49 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
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
if(_errs76 === errors){
if(data.published !== undefined){
let data42 = data.published;
const _errs77 = errors;
if(errors === _errs77){
if(data42 && typeof data42 == "object" && !Array.isArray(data42)){
let missing9;
if(((data42.head === undefined) && (missing9 = "head")) || ((data42.compiled === undefined) && (missing9 = "compiled"))){
const err50 = {instancePath:instancePath+"/published",schemaPath:"#/oneOf/3/properties/published/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
if(vErrors === null){
vErrors = [err50];
}
else {
vErrors.push(err50);
}
errors++;
}
else {
const _errs79 = errors;
for(const key9 in data42){
if(!((key9 === "head") || (key9 === "compiled"))){
const err51 = {instancePath:instancePath+"/published",schemaPath:"#/oneOf/3/properties/published/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
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
if(_errs79 === errors){
if(data42.head !== undefined){
const _errs80 = errors;
if(!(validate181(data42.head, {instancePath:instancePath+"/published/head",parentData:data42,parentDataProperty:"head",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate181.errors : vErrors.concat(validate181.errors);
errors = vErrors.length;
}
var valid18 = _errs80 === errors;
}
else {
var valid18 = true;
}
if(valid18){
if(data42.compiled !== undefined){
let data44 = data42.compiled;
const _errs81 = errors;
if(errors === _errs81){
if(data44 && typeof data44 == "object" && !Array.isArray(data44)){
let missing10;
if((((data44.definition === undefined) && (missing10 = "definition")) || ((data44.canonical === undefined) && (missing10 = "canonical"))) || ((data44.spec === undefined) && (missing10 = "spec"))){
const err52 = {instancePath:instancePath+"/published/compiled",schemaPath:"#/oneOf/3/properties/published/properties/compiled/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"};
if(vErrors === null){
vErrors = [err52];
}
else {
vErrors.push(err52);
}
errors++;
}
else {
const _errs83 = errors;
for(const key10 in data44){
if(!(((key10 === "definition") || (key10 === "canonical")) || (key10 === "spec"))){
const err53 = {instancePath:instancePath+"/published/compiled",schemaPath:"#/oneOf/3/properties/published/properties/compiled/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err53];
}
else {
vErrors.push(err53);
}
errors++;
break;
}
}
if(_errs83 === errors){
if(data44.definition !== undefined){
let data45 = data44.definition;
const _errs84 = errors;
if(errors === _errs84){
if(data45 && typeof data45 == "object" && !Array.isArray(data45)){
let missing11;
if((((((((((data45.name === undefined) && (missing11 = "name")) || ((data45.realm === undefined) && (missing11 = "realm"))) || ((data45.revision === undefined) && (missing11 = "revision"))) || ((data45.entry === undefined) && (missing11 = "entry"))) || ((data45.theme === undefined) && (missing11 = "theme"))) || ((data45.themes === undefined) && (missing11 = "themes"))) || ((data45.screens === undefined) && (missing11 = "screens"))) || ((data45.bindings === undefined) && (missing11 = "bindings"))) || ((data45.actions === undefined) && (missing11 = "actions"))){
const err54 = {instancePath:instancePath+"/published/compiled/definition",schemaPath:"#/oneOf/3/properties/published/properties/compiled/properties/definition/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
if(vErrors === null){
vErrors = [err54];
}
else {
vErrors.push(err54);
}
errors++;
}
else {
const _errs86 = errors;
for(const key11 in data45){
if(!(func1.call(schema150.oneOf[3].properties.published.properties.compiled.properties.definition.properties, key11))){
const err55 = {instancePath:instancePath+"/published/compiled/definition",schemaPath:"#/oneOf/3/properties/published/properties/compiled/properties/definition/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
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
if(_errs86 === errors){
if(data45.version !== undefined){
let data46 = data45.version;
const _errs87 = errors;
if(!(((typeof data46 == "number") && (!(data46 % 1) && !isNaN(data46))) && (isFinite(data46)))){
const err56 = {instancePath:instancePath+"/published/compiled/definition/version",schemaPath:"#/oneOf/3/properties/published/properties/compiled/properties/definition/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err56];
}
else {
vErrors.push(err56);
}
errors++;
}
if(1 !== data46){
const err57 = {instancePath:instancePath+"/published/compiled/definition/version",schemaPath:"#/oneOf/3/properties/published/properties/compiled/properties/definition/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"};
if(vErrors === null){
vErrors = [err57];
}
else {
vErrors.push(err57);
}
errors++;
}
var valid20 = _errs87 === errors;
}
else {
var valid20 = true;
}
if(valid20){
if(data45.name !== undefined){
const _errs89 = errors;
if(!(validate54(data45.name, {instancePath:instancePath+"/published/compiled/definition/name",parentData:data45,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid20 = _errs89 === errors;
}
else {
var valid20 = true;
}
if(valid20){
if(data45.realm !== undefined){
const _errs90 = errors;
if(!(validate56(data45.realm, {instancePath:instancePath+"/published/compiled/definition/realm",parentData:data45,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid20 = _errs90 === errors;
}
else {
var valid20 = true;
}
if(valid20){
if(data45.revision !== undefined){
const _errs91 = errors;
if(!(validate58(data45.revision, {instancePath:instancePath+"/published/compiled/definition/revision",parentData:data45,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid20 = _errs91 === errors;
}
else {
var valid20 = true;
}
if(valid20){
if(data45.components !== undefined){
const _errs92 = errors;
if(!(validate60(data45.components, {instancePath:instancePath+"/published/compiled/definition/components",parentData:data45,parentDataProperty:"components",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate60.errors : vErrors.concat(validate60.errors);
errors = vErrors.length;
}
var valid20 = _errs92 === errors;
}
else {
var valid20 = true;
}
if(valid20){
if(data45.entry !== undefined){
const _errs93 = errors;
if(!(validate54(data45.entry, {instancePath:instancePath+"/published/compiled/definition/entry",parentData:data45,parentDataProperty:"entry",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid20 = _errs93 === errors;
}
else {
var valid20 = true;
}
if(valid20){
if(data45.theme !== undefined){
const _errs94 = errors;
if(!(validate54(data45.theme, {instancePath:instancePath+"/published/compiled/definition/theme",parentData:data45,parentDataProperty:"theme",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid20 = _errs94 === errors;
}
else {
var valid20 = true;
}
if(valid20){
if(data45.themes !== undefined){
let data53 = data45.themes;
const _errs95 = errors;
if(errors === _errs95){
if(Array.isArray(data53)){
if(data53.length > 2){
const err58 = {instancePath:instancePath+"/published/compiled/definition/themes",schemaPath:"#/oneOf/3/properties/published/properties/compiled/properties/definition/properties/themes/maxItems",keyword:"maxItems",params:{limit: 2},message:"must NOT have more than 2 items"};
if(vErrors === null){
vErrors = [err58];
}
else {
vErrors.push(err58);
}
errors++;
}
else {
var valid21 = true;
const len8 = data53.length;
for(let i8=0; i8<len8; i8++){
const _errs97 = errors;
if(!(validate64(data53[i8], {instancePath:instancePath+"/published/compiled/definition/themes/" + i8,parentData:data53,parentDataProperty:i8,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
errors = vErrors.length;
}
var valid21 = _errs97 === errors;
if(!valid21){
break;
}
}
}
}
else {
const err59 = {instancePath:instancePath+"/published/compiled/definition/themes",schemaPath:"#/oneOf/3/properties/published/properties/compiled/properties/definition/properties/themes/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err59];
}
else {
vErrors.push(err59);
}
errors++;
}
}
var valid20 = _errs95 === errors;
}
else {
var valid20 = true;
}
if(valid20){
if(data45.screens !== undefined){
let data55 = data45.screens;
const _errs98 = errors;
if(errors === _errs98){
if(Array.isArray(data55)){
if(data55.length > 16){
const err60 = {instancePath:instancePath+"/published/compiled/definition/screens",schemaPath:"#/oneOf/3/properties/published/properties/compiled/properties/definition/properties/screens/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"};
if(vErrors === null){
vErrors = [err60];
}
else {
vErrors.push(err60);
}
errors++;
}
else {
var valid22 = true;
const len9 = data55.length;
for(let i9=0; i9<len9; i9++){
const _errs100 = errors;
if(!(validate67(data55[i9], {instancePath:instancePath+"/published/compiled/definition/screens/" + i9,parentData:data55,parentDataProperty:i9,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate67.errors : vErrors.concat(validate67.errors);
errors = vErrors.length;
}
var valid22 = _errs100 === errors;
if(!valid22){
break;
}
}
}
}
else {
const err61 = {instancePath:instancePath+"/published/compiled/definition/screens",schemaPath:"#/oneOf/3/properties/published/properties/compiled/properties/definition/properties/screens/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err61];
}
else {
vErrors.push(err61);
}
errors++;
}
}
var valid20 = _errs98 === errors;
}
else {
var valid20 = true;
}
if(valid20){
if(data45.bindings !== undefined){
let data57 = data45.bindings;
const _errs101 = errors;
if(errors === _errs101){
if(Array.isArray(data57)){
if(data57.length > 16){
const err62 = {instancePath:instancePath+"/published/compiled/definition/bindings",schemaPath:"#/oneOf/3/properties/published/properties/compiled/properties/definition/properties/bindings/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"};
if(vErrors === null){
vErrors = [err62];
}
else {
vErrors.push(err62);
}
errors++;
}
else {
var valid23 = true;
const len10 = data57.length;
for(let i10=0; i10<len10; i10++){
const _errs103 = errors;
if(!(validate73(data57[i10], {instancePath:instancePath+"/published/compiled/definition/bindings/" + i10,parentData:data57,parentDataProperty:i10,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate73.errors : vErrors.concat(validate73.errors);
errors = vErrors.length;
}
var valid23 = _errs103 === errors;
if(!valid23){
break;
}
}
}
}
else {
const err63 = {instancePath:instancePath+"/published/compiled/definition/bindings",schemaPath:"#/oneOf/3/properties/published/properties/compiled/properties/definition/properties/bindings/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err63];
}
else {
vErrors.push(err63);
}
errors++;
}
}
var valid20 = _errs101 === errors;
}
else {
var valid20 = true;
}
if(valid20){
if(data45.actions !== undefined){
let data59 = data45.actions;
const _errs104 = errors;
if(errors === _errs104){
if(Array.isArray(data59)){
if(data59.length > 16){
const err64 = {instancePath:instancePath+"/published/compiled/definition/actions",schemaPath:"#/oneOf/3/properties/published/properties/compiled/properties/definition/properties/actions/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"};
if(vErrors === null){
vErrors = [err64];
}
else {
vErrors.push(err64);
}
errors++;
}
else {
var valid24 = true;
const len11 = data59.length;
for(let i11=0; i11<len11; i11++){
const _errs106 = errors;
if(!(validate88(data59[i11], {instancePath:instancePath+"/published/compiled/definition/actions/" + i11,parentData:data59,parentDataProperty:i11,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate88.errors : vErrors.concat(validate88.errors);
errors = vErrors.length;
}
var valid24 = _errs106 === errors;
if(!valid24){
break;
}
}
}
}
else {
const err65 = {instancePath:instancePath+"/published/compiled/definition/actions",schemaPath:"#/oneOf/3/properties/published/properties/compiled/properties/definition/properties/actions/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err65];
}
else {
vErrors.push(err65);
}
errors++;
}
}
var valid20 = _errs104 === errors;
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
}
}
}
}
}
else {
const err66 = {instancePath:instancePath+"/published/compiled/definition",schemaPath:"#/oneOf/3/properties/published/properties/compiled/properties/definition/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err66];
}
else {
vErrors.push(err66);
}
errors++;
}
}
var valid19 = _errs84 === errors;
}
else {
var valid19 = true;
}
if(valid19){
if(data44.canonical !== undefined){
let data61 = data44.canonical;
const _errs107 = errors;
if(errors === _errs107){
if(typeof data61 === "string"){
if(func2(data61) > 65536){
const err67 = {instancePath:instancePath+"/published/compiled/canonical",schemaPath:"#/oneOf/3/properties/published/properties/compiled/properties/canonical/maxLength",keyword:"maxLength",params:{limit: 65536},message:"must NOT have more than 65536 characters"};
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
const err68 = {instancePath:instancePath+"/published/compiled/canonical",schemaPath:"#/oneOf/3/properties/published/properties/compiled/properties/canonical/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err68];
}
else {
vErrors.push(err68);
}
errors++;
}
}
var valid19 = _errs107 === errors;
}
else {
var valid19 = true;
}
if(valid19){
if(data44.spec !== undefined){
const _errs109 = errors;
if(!(validate146(data44.spec, {instancePath:instancePath+"/published/compiled/spec",parentData:data44,parentDataProperty:"spec",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
errors = vErrors.length;
}
var valid19 = _errs109 === errors;
}
else {
var valid19 = true;
}
}
}
}
}
}
else {
const err69 = {instancePath:instancePath+"/published/compiled",schemaPath:"#/oneOf/3/properties/published/properties/compiled/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err69];
}
else {
vErrors.push(err69);
}
errors++;
}
}
var valid18 = _errs81 === errors;
}
else {
var valid18 = true;
}
}
}
}
}
else {
const err70 = {instancePath:instancePath+"/published",schemaPath:"#/oneOf/3/properties/published/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
else {
const err71 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err71];
}
else {
vErrors.push(err71);
}
errors++;
}
}
var _valid0 = _errs74 === errors;
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
const _errs110 = errors;
if(errors === _errs110){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing12;
if((data.prepared === undefined) && (missing12 = "prepared")){
const err72 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing12},message:"must have required property '"+missing12+"'"};
if(vErrors === null){
vErrors = [err72];
}
else {
vErrors.push(err72);
}
errors++;
}
else {
const _errs112 = errors;
for(const key12 in data){
if(!(key12 === "prepared")){
const err73 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key12},message:"must NOT have additional properties"};
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
if(_errs112 === errors){
if(data.prepared !== undefined){
if(!(validate245(data.prepared, {instancePath:instancePath+"/prepared",parentData:data,parentDataProperty:"prepared",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate245.errors : vErrors.concat(validate245.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err74 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err74];
}
else {
vErrors.push(err74);
}
errors++;
}
}
var _valid0 = _errs110 === errors;
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
const _errs114 = errors;
if(errors === _errs114){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing13;
if((data.admitted === undefined) && (missing13 = "admitted")){
const err75 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing13},message:"must have required property '"+missing13+"'"};
if(vErrors === null){
vErrors = [err75];
}
else {
vErrors.push(err75);
}
errors++;
}
else {
const _errs116 = errors;
for(const key13 in data){
if(!(key13 === "admitted")){
const err76 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key13},message:"must NOT have additional properties"};
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
if(_errs116 === errors){
if(data.admitted !== undefined){
let data64 = data.admitted;
const _errs117 = errors;
if(errors === _errs117){
if(data64 && typeof data64 == "object" && !Array.isArray(data64)){
let missing14;
if((data64.position === undefined) && (missing14 = "position")){
const err77 = {instancePath:instancePath+"/admitted",schemaPath:"#/oneOf/5/properties/admitted/required",keyword:"required",params:{missingProperty: missing14},message:"must have required property '"+missing14+"'"};
if(vErrors === null){
vErrors = [err77];
}
else {
vErrors.push(err77);
}
errors++;
}
else {
const _errs119 = errors;
for(const key14 in data64){
if(!(key14 === "position")){
const err78 = {instancePath:instancePath+"/admitted",schemaPath:"#/oneOf/5/properties/admitted/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key14},message:"must NOT have additional properties"};
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
if(_errs119 === errors){
if(data64.position !== undefined){
if(!(validate56(data64.position, {instancePath:instancePath+"/admitted/position",parentData:data64,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err79 = {instancePath:instancePath+"/admitted",schemaPath:"#/oneOf/5/properties/admitted/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err80 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err80];
}
else {
vErrors.push(err80);
}
errors++;
}
}
var _valid0 = _errs114 === errors;
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
const _errs121 = errors;
if(errors === _errs121){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing15;
if((data.next_upload === undefined) && (missing15 = "next_upload")){
const err81 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing15},message:"must have required property '"+missing15+"'"};
if(vErrors === null){
vErrors = [err81];
}
else {
vErrors.push(err81);
}
errors++;
}
else {
const _errs123 = errors;
for(const key15 in data){
if(!(key15 === "next_upload")){
const err82 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key15},message:"must NOT have additional properties"};
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
if(_errs123 === errors){
if(data.next_upload !== undefined){
if(!(validate539(data.next_upload, {instancePath:instancePath+"/next_upload",parentData:data,parentDataProperty:"next_upload",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate539.errors : vErrors.concat(validate539.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err83 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err83];
}
else {
vErrors.push(err83);
}
errors++;
}
}
var _valid0 = _errs121 === errors;
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
const _errs125 = errors;
if(errors === _errs125){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing16;
if((data.next_cleanup === undefined) && (missing16 = "next_cleanup")){
const err84 = {instancePath,schemaPath:"#/oneOf/7/required",keyword:"required",params:{missingProperty: missing16},message:"must have required property '"+missing16+"'"};
if(vErrors === null){
vErrors = [err84];
}
else {
vErrors.push(err84);
}
errors++;
}
else {
const _errs127 = errors;
for(const key16 in data){
if(!(key16 === "next_cleanup")){
const err85 = {instancePath,schemaPath:"#/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key16},message:"must NOT have additional properties"};
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
if(_errs127 === errors){
if(data.next_cleanup !== undefined){
if(!(validate539(data.next_cleanup, {instancePath:instancePath+"/next_cleanup",parentData:data,parentDataProperty:"next_cleanup",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate539.errors : vErrors.concat(validate539.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err86 = {instancePath,schemaPath:"#/oneOf/7/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err86];
}
else {
vErrors.push(err86);
}
errors++;
}
}
var _valid0 = _errs125 === errors;
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
const _errs129 = errors;
if(errors === _errs129){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing17;
if((data.prepared_read === undefined) && (missing17 = "prepared_read")){
const err87 = {instancePath,schemaPath:"#/oneOf/8/required",keyword:"required",params:{missingProperty: missing17},message:"must have required property '"+missing17+"'"};
if(vErrors === null){
vErrors = [err87];
}
else {
vErrors.push(err87);
}
errors++;
}
else {
const _errs131 = errors;
for(const key17 in data){
if(!(key17 === "prepared_read")){
const err88 = {instancePath,schemaPath:"#/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key17},message:"must NOT have additional properties"};
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
if(_errs131 === errors){
if(data.prepared_read !== undefined){
if(!(validate265(data.prepared_read, {instancePath:instancePath+"/prepared_read",parentData:data,parentDataProperty:"prepared_read",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate265.errors : vErrors.concat(validate265.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err89 = {instancePath,schemaPath:"#/oneOf/8/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err89];
}
else {
vErrors.push(err89);
}
errors++;
}
}
var _valid0 = _errs129 === errors;
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
const _errs133 = errors;
if(errors === _errs133){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing18;
if((data.observation === undefined) && (missing18 = "observation")){
const err90 = {instancePath,schemaPath:"#/oneOf/9/required",keyword:"required",params:{missingProperty: missing18},message:"must have required property '"+missing18+"'"};
if(vErrors === null){
vErrors = [err90];
}
else {
vErrors.push(err90);
}
errors++;
}
else {
const _errs135 = errors;
for(const key18 in data){
if(!(key18 === "observation")){
const err91 = {instancePath,schemaPath:"#/oneOf/9/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key18},message:"must NOT have additional properties"};
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
if(_errs135 === errors){
if(data.observation !== undefined){
if(!(validate291(data.observation, {instancePath:instancePath+"/observation",parentData:data,parentDataProperty:"observation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate291.errors : vErrors.concat(validate291.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err92 = {instancePath,schemaPath:"#/oneOf/9/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err92];
}
else {
vErrors.push(err92);
}
errors++;
}
}
var _valid0 = _errs133 === errors;
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
const err93 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err93];
}
else {
vErrors.push(err93);
}
errors++;
validate499.errors = vErrors;
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
validate499.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate499.evaluated = {"dynamicProps":true,"dynamicItems":false};

export const Compiled = validate545;
const schema152 = {"type":"object","additionalProperties":false,"properties":{"definition":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","const":1},"name":{"$ref":"https://transit.invalid/generated-validator/0"},"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"revision":{"$ref":"https://transit.invalid/generated-validator/2"},"components":{"$ref":"https://transit.invalid/generated-validator/3"},"entry":{"$ref":"https://transit.invalid/generated-validator/0"},"theme":{"$ref":"https://transit.invalid/generated-validator/0"},"themes":{"type":"array","maxItems":2,"items":{"$ref":"#/$defs/Theme"}},"screens":{"type":"array","maxItems":16,"items":{"$ref":"#/$defs/Screen"}},"bindings":{"type":"array","maxItems":16,"items":{"$ref":"#/$defs/Binding"}},"actions":{"type":"array","maxItems":16,"items":{"$ref":"#/$defs/Action"}}},"required":["name","realm","revision","entry","theme","themes","screens","bindings","actions"]},"canonical":{"type":"string","maxLength":65536},"spec":{"$ref":"https://transit.invalid/generated-validator/10"}},"required":["definition","canonical","spec"]};

function validate545(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate545.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.definition === undefined) && (missing0 = "definition")) || ((data.canonical === undefined) && (missing0 = "canonical"))) || ((data.spec === undefined) && (missing0 = "spec"))){
validate545.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "definition") || (key0 === "canonical")) || (key0 === "spec"))){
validate545.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
let data0 = data.definition;
const _errs2 = errors;
if(errors === _errs2){
if(data0 && typeof data0 == "object" && !Array.isArray(data0)){
let missing1;
if((((((((((data0.name === undefined) && (missing1 = "name")) || ((data0.realm === undefined) && (missing1 = "realm"))) || ((data0.revision === undefined) && (missing1 = "revision"))) || ((data0.entry === undefined) && (missing1 = "entry"))) || ((data0.theme === undefined) && (missing1 = "theme"))) || ((data0.themes === undefined) && (missing1 = "themes"))) || ((data0.screens === undefined) && (missing1 = "screens"))) || ((data0.bindings === undefined) && (missing1 = "bindings"))) || ((data0.actions === undefined) && (missing1 = "actions"))){
validate545.errors = [{instancePath:instancePath+"/definition",schemaPath:"#/properties/definition/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"}];
return false;
}
else {
const _errs4 = errors;
for(const key1 in data0){
if(!(func1.call(schema152.properties.definition.properties, key1))){
validate545.errors = [{instancePath:instancePath+"/definition",schemaPath:"#/properties/definition/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs4 === errors){
if(data0.version !== undefined){
let data1 = data0.version;
const _errs5 = errors;
if(!(((typeof data1 == "number") && (!(data1 % 1) && !isNaN(data1))) && (isFinite(data1)))){
validate545.errors = [{instancePath:instancePath+"/definition/version",schemaPath:"#/properties/definition/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(1 !== data1){
validate545.errors = [{instancePath:instancePath+"/definition/version",schemaPath:"#/properties/definition/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"}];
return false;
}
var valid1 = _errs5 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.name !== undefined){
const _errs7 = errors;
if(!(validate54(data0.name, {instancePath:instancePath+"/definition/name",parentData:data0,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid1 = _errs7 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.realm !== undefined){
const _errs8 = errors;
if(!(validate56(data0.realm, {instancePath:instancePath+"/definition/realm",parentData:data0,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid1 = _errs8 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.revision !== undefined){
const _errs9 = errors;
if(!(validate58(data0.revision, {instancePath:instancePath+"/definition/revision",parentData:data0,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid1 = _errs9 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.components !== undefined){
const _errs10 = errors;
if(!(validate60(data0.components, {instancePath:instancePath+"/definition/components",parentData:data0,parentDataProperty:"components",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate60.errors : vErrors.concat(validate60.errors);
errors = vErrors.length;
}
var valid1 = _errs10 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.entry !== undefined){
const _errs11 = errors;
if(!(validate54(data0.entry, {instancePath:instancePath+"/definition/entry",parentData:data0,parentDataProperty:"entry",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid1 = _errs11 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.theme !== undefined){
const _errs12 = errors;
if(!(validate54(data0.theme, {instancePath:instancePath+"/definition/theme",parentData:data0,parentDataProperty:"theme",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid1 = _errs12 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.themes !== undefined){
let data8 = data0.themes;
const _errs13 = errors;
if(errors === _errs13){
if(Array.isArray(data8)){
if(data8.length > 2){
validate545.errors = [{instancePath:instancePath+"/definition/themes",schemaPath:"#/properties/definition/properties/themes/maxItems",keyword:"maxItems",params:{limit: 2},message:"must NOT have more than 2 items"}];
return false;
}
else {
var valid2 = true;
const len0 = data8.length;
for(let i0=0; i0<len0; i0++){
const _errs15 = errors;
if(!(validate64(data8[i0], {instancePath:instancePath+"/definition/themes/" + i0,parentData:data8,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
errors = vErrors.length;
}
var valid2 = _errs15 === errors;
if(!valid2){
break;
}
}
}
}
else {
validate545.errors = [{instancePath:instancePath+"/definition/themes",schemaPath:"#/properties/definition/properties/themes/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid1 = _errs13 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.screens !== undefined){
let data10 = data0.screens;
const _errs16 = errors;
if(errors === _errs16){
if(Array.isArray(data10)){
if(data10.length > 16){
validate545.errors = [{instancePath:instancePath+"/definition/screens",schemaPath:"#/properties/definition/properties/screens/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
var valid3 = true;
const len1 = data10.length;
for(let i1=0; i1<len1; i1++){
const _errs18 = errors;
if(!(validate67(data10[i1], {instancePath:instancePath+"/definition/screens/" + i1,parentData:data10,parentDataProperty:i1,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate67.errors : vErrors.concat(validate67.errors);
errors = vErrors.length;
}
var valid3 = _errs18 === errors;
if(!valid3){
break;
}
}
}
}
else {
validate545.errors = [{instancePath:instancePath+"/definition/screens",schemaPath:"#/properties/definition/properties/screens/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid1 = _errs16 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.bindings !== undefined){
let data12 = data0.bindings;
const _errs19 = errors;
if(errors === _errs19){
if(Array.isArray(data12)){
if(data12.length > 16){
validate545.errors = [{instancePath:instancePath+"/definition/bindings",schemaPath:"#/properties/definition/properties/bindings/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
var valid4 = true;
const len2 = data12.length;
for(let i2=0; i2<len2; i2++){
const _errs21 = errors;
if(!(validate73(data12[i2], {instancePath:instancePath+"/definition/bindings/" + i2,parentData:data12,parentDataProperty:i2,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate73.errors : vErrors.concat(validate73.errors);
errors = vErrors.length;
}
var valid4 = _errs21 === errors;
if(!valid4){
break;
}
}
}
}
else {
validate545.errors = [{instancePath:instancePath+"/definition/bindings",schemaPath:"#/properties/definition/properties/bindings/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid1 = _errs19 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.actions !== undefined){
let data14 = data0.actions;
const _errs22 = errors;
if(errors === _errs22){
if(Array.isArray(data14)){
if(data14.length > 16){
validate545.errors = [{instancePath:instancePath+"/definition/actions",schemaPath:"#/properties/definition/properties/actions/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
var valid5 = true;
const len3 = data14.length;
for(let i3=0; i3<len3; i3++){
const _errs24 = errors;
if(!(validate88(data14[i3], {instancePath:instancePath+"/definition/actions/" + i3,parentData:data14,parentDataProperty:i3,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate88.errors : vErrors.concat(validate88.errors);
errors = vErrors.length;
}
var valid5 = _errs24 === errors;
if(!valid5){
break;
}
}
}
}
else {
validate545.errors = [{instancePath:instancePath+"/definition/actions",schemaPath:"#/properties/definition/properties/actions/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid1 = _errs22 === errors;
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
}
}
}
}
}
else {
validate545.errors = [{instancePath:instancePath+"/definition",schemaPath:"#/properties/definition/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.canonical !== undefined){
let data16 = data.canonical;
const _errs25 = errors;
if(errors === _errs25){
if(typeof data16 === "string"){
if(func2(data16) > 65536){
validate545.errors = [{instancePath:instancePath+"/canonical",schemaPath:"#/properties/canonical/maxLength",keyword:"maxLength",params:{limit: 65536},message:"must NOT have more than 65536 characters"}];
return false;
}
}
else {
validate545.errors = [{instancePath:instancePath+"/canonical",schemaPath:"#/properties/canonical/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs25 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.spec !== undefined){
const _errs27 = errors;
if(!(validate146(data.spec, {instancePath:instancePath+"/spec",parentData:data,parentDataProperty:"spec",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
errors = vErrors.length;
}
var valid0 = _errs27 === errors;
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
validate545.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate545.errors = vErrors;
return errors === 0;
}
validate545.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};
