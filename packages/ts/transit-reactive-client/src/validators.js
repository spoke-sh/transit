// Generated; no runtime code generation or eval.
import lengthModule from "ajv/dist/runtime/ucs2length.js";
const ucs2length = lengthModule.default ?? lengthModule;
"use strict";
export const SubjectProof = validate52;
const schema19 = {"type":"object","additionalProperties":false,"properties":{"claim":{"$ref":"https://transit.invalid/generated-validator/5"},"signature":{"$ref":"https://transit.invalid/generated-validator/6"}},"required":["claim","signature"]};
const schema20 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"https://transit.invalid/generated-validator/0"},"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"principal":{"$ref":"https://transit.invalid/generated-validator/1"},"credential_epoch":{"$ref":"https://transit.invalid/generated-validator/1"},"role":{"$ref":"https://transit.invalid/generated-validator/2"},"audience":{"$ref":"https://transit.invalid/generated-validator/1"},"context":{"$ref":"https://transit.invalid/generated-validator/4"}},"required":["definition","realm","principal","credential_epoch","role","audience","context"]};
const schema21 = {"type":"string","enum":["312fcb8d609365bc55ffa7ddbe0242493e843256539f96889a51a2fba0f2b9c0"]};

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
if(typeof data !== "string"){
validate54.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(data === "312fcb8d609365bc55ffa7ddbe0242493e843256539f96889a51a2fba0f2b9c0")){
validate54.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema21.enum},message:"must be equal to one of the allowed values"}];
return false;
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

const schema23 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/1"},{"type":"null"}]};

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
validate60.errors = vErrors;
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
validate60.errors = vErrors;
return errors === 0;
}
validate60.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema24 = {"type":"array","minItems":32,"maxItems":32,"items":{"$ref":"https://transit.invalid/generated-validator/3"}};
const schema25 = {"type":"integer","minimum":0,"maximum":255};

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
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate65.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate65.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate65.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate65.errors = vErrors;
return errors === 0;
}
validate65.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(Array.isArray(data)){
if(data.length > 32){
validate64.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"}];
return false;
}
else {
if(data.length < 32){
validate64.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate65(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
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
validate64.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate64.errors = vErrors;
return errors === 0;
}
validate64.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((data.definition === undefined) && (missing0 = "definition")) || ((data.realm === undefined) && (missing0 = "realm"))) || ((data.principal === undefined) && (missing0 = "principal"))) || ((data.credential_epoch === undefined) && (missing0 = "credential_epoch"))) || ((data.role === undefined) && (missing0 = "role"))) || ((data.audience === undefined) && (missing0 = "audience"))) || ((data.context === undefined) && (missing0 = "context"))){
validate53.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "definition") || (key0 === "realm")) || (key0 === "principal")) || (key0 === "credential_epoch")) || (key0 === "role")) || (key0 === "audience")) || (key0 === "context"))){
validate53.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate54(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.realm !== undefined){
const _errs3 = errors;
if(!(validate56(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.principal !== undefined){
const _errs4 = errors;
if(!(validate56(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate56(data.credential_epoch, {instancePath:instancePath+"/credential_epoch",parentData:data,parentDataProperty:"credential_epoch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate60(data.role, {instancePath:instancePath+"/role",parentData:data,parentDataProperty:"role",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate60.errors : vErrors.concat(validate60.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.audience !== undefined){
const _errs7 = errors;
if(!(validate56(data.audience, {instancePath:instancePath+"/audience",parentData:data,parentDataProperty:"audience",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.context !== undefined){
const _errs8 = errors;
if(!(validate64(data.context, {instancePath:instancePath+"/context",parentData:data,parentDataProperty:"context",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
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
validate53.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate53.errors = vErrors;
return errors === 0;
}
validate53.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema26 = {"type":"array","minItems":64,"maxItems":64,"items":{"$ref":"https://transit.invalid/generated-validator/3"}};

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
if(Array.isArray(data)){
if(data.length > 64){
validate69.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 64},message:"must NOT have more than 64 items"}];
return false;
}
else {
if(data.length < 64){
validate69.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 64},message:"must NOT have fewer than 64 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate65(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
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
validate69.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate69.errors = vErrors;
return errors === 0;
}
validate69.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate52(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate52.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.claim === undefined) && (missing0 = "claim")) || ((data.signature === undefined) && (missing0 = "signature"))){
validate52.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "claim") || (key0 === "signature"))){
validate52.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.claim !== undefined){
const _errs2 = errors;
if(!(validate53(data.claim, {instancePath:instancePath+"/claim",parentData:data,parentDataProperty:"claim",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
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
if(!(validate69(data.signature, {instancePath:instancePath+"/signature",parentData:data,parentDataProperty:"signature",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate69.errors : vErrors.concat(validate69.errors);
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
validate52.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate52.errors = vErrors;
return errors === 0;
}
validate52.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Diagnostic = validate72;
const schema27 = {"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"definition":{"$ref":"https://transit.invalid/generated-validator/0"},"code":{"type":"string","maxLength":96},"category":{"$ref":"https://transit.invalid/generated-validator/7"},"stage":{"$ref":"https://transit.invalid/generated-validator/8"},"outcome":{"$ref":"https://transit.invalid/generated-validator/9"},"evidence":{"$ref":"https://transit.invalid/generated-validator/10"},"message":{"type":"string","maxLength":384},"cause":{"$ref":"https://transit.invalid/generated-validator/11"},"identity":{"$ref":"https://transit.invalid/generated-validator/16"},"location":{"anyOf":[{"$ref":"https://transit.invalid/generated-validator/19"},{"type":"null"}]},"facts":{"type":"array","minItems":16,"maxItems":16,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"field":{"$ref":"https://transit.invalid/generated-validator/20"},"origin":{"$ref":"https://transit.invalid/generated-validator/21"},"availability":{"$ref":"https://transit.invalid/generated-validator/22"},"value":{"anyOf":[{"oneOf":[{"$ref":"https://transit.invalid/generated-validator/23"},{"$ref":"https://transit.invalid/generated-validator/25"},{"$ref":"https://transit.invalid/generated-validator/26"},{"$ref":"https://transit.invalid/generated-validator/27"},{"$ref":"https://transit.invalid/generated-validator/28"},{"type":"object","additionalProperties":false,"required":["location"],"properties":{"location":{"$ref":"https://transit.invalid/generated-validator/19"}}}]},{"type":"null"}]}},"required":["field","origin","availability","value"]},{"type":"null"}]}},"actions":{"type":"array","minItems":4,"maxItems":4,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"kind":{"$ref":"https://transit.invalid/generated-validator/29"},"target":{"$ref":"https://transit.invalid/generated-validator/16"}},"required":["kind","target"]},{"type":"null"}]}}},"required":["version","definition","code","category","stage","outcome","evidence","message","cause","identity","location","facts","actions"]};
const func1 = Object.prototype.hasOwnProperty;
const func2 = ucs2length;
const schema28 = {"type":"string","enum":["syntax","binding","unsupported","constraint","access","conflict","limit","lifecycle","integrity","unavailable","internal"]};

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
if(typeof data !== "string"){
validate74.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((data === "syntax") || (data === "binding")) || (data === "unsupported")) || (data === "constraint")) || (data === "access")) || (data === "conflict")) || (data === "limit")) || (data === "lifecycle")) || (data === "integrity")) || (data === "unavailable")) || (data === "internal"))){
validate74.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema28.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate74.errors = vErrors;
return errors === 0;
}
validate74.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema29 = {"type":"string","enum":["input","parse","compile","bind","prepare","submit","admission","execute","read","decode","output","reconcile","cleanup","control"]};

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
if(typeof data !== "string"){
validate76.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((((data === "input") || (data === "parse")) || (data === "compile")) || (data === "bind")) || (data === "prepare")) || (data === "submit")) || (data === "admission")) || (data === "execute")) || (data === "read")) || (data === "decode")) || (data === "output")) || (data === "reconcile")) || (data === "cleanup")) || (data === "control"))){
validate76.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema29.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate76.errors = vErrors;
return errors === 0;
}
validate76.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema30 = {"type":"string","enum":["not_applicable","not_submitted","not_dispatched","prepared","unknown","pending","input_rejected","rejected","applied","completed","failed","cancelled","retired","closed_unknown"]};

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
if(typeof data !== "string"){
validate78.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((((data === "not_applicable") || (data === "not_submitted")) || (data === "not_dispatched")) || (data === "prepared")) || (data === "unknown")) || (data === "pending")) || (data === "input_rejected")) || (data === "rejected")) || (data === "applied")) || (data === "completed")) || (data === "failed")) || (data === "cancelled")) || (data === "retired")) || (data === "closed_unknown"))){
validate78.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema30.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate78.errors = vErrors;
return errors === 0;
}
validate78.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema31 = {"type":"string","enum":["none","local_before_dispatch","saved_intent","native_receipt","domain_status"]};

function validate80(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate80.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate80.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((data === "none") || (data === "local_before_dispatch")) || (data === "saved_intent")) || (data === "native_receipt")) || (data === "domain_status"))){
validate80.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema31.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate80.errors = vErrors;
return errors === 0;
}
validate80.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema32 = {"anyOf":[{"type":"string","maxLength":96},{"type":"null"}]};

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
validate82.errors = vErrors;
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
validate82.errors = vErrors;
return errors === 0;
}
validate82.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema33 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/15"},{"type":"null"}]};
const schema34 = {"type":"object","additionalProperties":false,"properties":{"domain":{"$ref":"https://transit.invalid/generated-validator/12"},"id":{"$ref":"https://transit.invalid/generated-validator/13"},"realm":{"$ref":"https://transit.invalid/generated-validator/14"},"resource":{"$ref":"https://transit.invalid/generated-validator/14"},"sequence":{"$ref":"https://transit.invalid/generated-validator/14"}},"required":["domain","id","realm","resource","sequence"]};
const schema35 = {"type":"string","enum":["sql","query","mutation","catalog","application","publication","migration","reactive","serving","effect","exchange","transport","internal"]};

function validate86(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate86.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate86.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((((data === "sql") || (data === "query")) || (data === "mutation")) || (data === "catalog")) || (data === "application")) || (data === "publication")) || (data === "migration")) || (data === "reactive")) || (data === "serving")) || (data === "effect")) || (data === "exchange")) || (data === "transport")) || (data === "internal"))){
validate86.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema35.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate86.errors = vErrors;
return errors === 0;
}
validate86.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema36 = {"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"};
const pattern3 = new RegExp("^(0|[1-9][0-9]*)$", "u");

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
if(typeof data === "string"){
if(func2(data) > 20){
validate88.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern3.test(data)){
validate88.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate88.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate88.errors = vErrors;
return errors === 0;
}
validate88.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema37 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/13"},{"type":"null"}]};

function validate90(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate90.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate88(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate88.errors : vErrors.concat(validate88.errors);
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
validate90.errors = vErrors;
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
validate90.errors = vErrors;
return errors === 0;
}
validate90.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate85(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate85.evaluated;
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
validate85.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "domain") || (key0 === "id")) || (key0 === "realm")) || (key0 === "resource")) || (key0 === "sequence"))){
validate85.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.domain !== undefined){
const _errs2 = errors;
if(!(validate86(data.domain, {instancePath:instancePath+"/domain",parentData:data,parentDataProperty:"domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate86.errors : vErrors.concat(validate86.errors);
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
if(!(validate88(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate88.errors : vErrors.concat(validate88.errors);
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
if(!(validate90(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate90.errors : vErrors.concat(validate90.errors);
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
if(!(validate90(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate90.errors : vErrors.concat(validate90.errors);
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
if(!(validate90(data.sequence, {instancePath:instancePath+"/sequence",parentData:data,parentDataProperty:"sequence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate90.errors : vErrors.concat(validate90.errors);
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
validate85.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate85.errors = vErrors;
return errors === 0;
}
validate85.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate84(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate84.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate85(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate85.errors : vErrors.concat(validate85.errors);
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
validate84.errors = vErrors;
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
validate84.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate84.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema38 = {"type":"object","additionalProperties":false,"properties":{"source":{"$ref":"https://transit.invalid/generated-validator/17"},"source_encoding":{"$ref":"https://transit.invalid/generated-validator/18"},"source_truncated":{"type":"boolean"},"statement":{"$ref":"https://transit.invalid/generated-validator/14"},"offset":{"$ref":"https://transit.invalid/generated-validator/13"},"length":{"$ref":"https://transit.invalid/generated-validator/13"},"line":{"$ref":"https://transit.invalid/generated-validator/13"},"byte_column":{"$ref":"https://transit.invalid/generated-validator/13"}},"required":["source","source_encoding","source_truncated","statement","offset","length","line","byte_column"]};
const schema39 = {"anyOf":[{"type":"string","maxLength":512},{"type":"null"}]};

function validate98(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate98.evaluated;
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
validate98.errors = vErrors;
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
validate98.errors = vErrors;
return errors === 0;
}
validate98.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema40 = {"type":"string","enum":["utf8","escaped_bytes"]};

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
if(typeof data !== "string"){
validate100.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((data === "utf8") || (data === "escaped_bytes"))){
validate100.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema40.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate100.errors = vErrors;
return errors === 0;
}
validate100.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(((((((((data.source === undefined) && (missing0 = "source")) || ((data.source_encoding === undefined) && (missing0 = "source_encoding"))) || ((data.source_truncated === undefined) && (missing0 = "source_truncated"))) || ((data.statement === undefined) && (missing0 = "statement"))) || ((data.offset === undefined) && (missing0 = "offset"))) || ((data.length === undefined) && (missing0 = "length"))) || ((data.line === undefined) && (missing0 = "line"))) || ((data.byte_column === undefined) && (missing0 = "byte_column"))){
validate97.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "source") || (key0 === "source_encoding")) || (key0 === "source_truncated")) || (key0 === "statement")) || (key0 === "offset")) || (key0 === "length")) || (key0 === "line")) || (key0 === "byte_column"))){
validate97.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.source !== undefined){
const _errs2 = errors;
if(!(validate98(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate98.errors : vErrors.concat(validate98.errors);
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
if(!(validate100(data.source_encoding, {instancePath:instancePath+"/source_encoding",parentData:data,parentDataProperty:"source_encoding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate100.errors : vErrors.concat(validate100.errors);
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
validate97.errors = [{instancePath:instancePath+"/source_truncated",schemaPath:"#/properties/source_truncated/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
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
if(!(validate90(data.statement, {instancePath:instancePath+"/statement",parentData:data,parentDataProperty:"statement",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate90.errors : vErrors.concat(validate90.errors);
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
if(!(validate88(data.offset, {instancePath:instancePath+"/offset",parentData:data,parentDataProperty:"offset",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate88.errors : vErrors.concat(validate88.errors);
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
if(!(validate88(data.length, {instancePath:instancePath+"/length",parentData:data,parentDataProperty:"length",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate88.errors : vErrors.concat(validate88.errors);
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
if(!(validate88(data.line, {instancePath:instancePath+"/line",parentData:data,parentDataProperty:"line",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate88.errors : vErrors.concat(validate88.errors);
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
if(!(validate88(data.byte_column, {instancePath:instancePath+"/byte_column",parentData:data,parentDataProperty:"byte_column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate88.errors : vErrors.concat(validate88.errors);
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
validate97.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate97.errors = vErrors;
return errors === 0;
}
validate97.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema41 = {"type":"string","enum":["object","name","table","native_input","affected_rows","argument","option","permissions","scope","column","qualifier","constraint","key","input_row","first_occurrence","parameter","parameter_use","expected_count","actual_count","expected_type","actual_type","supplied_value","expected_value","expression","source_kind","source_basis","source_key","source_row","field_path","byte_offset","expected_resource","actual_resource","expected_source","actual_source","expected_revision","actual_revision","expected_schema","actual_schema","expected_policy","actual_policy","budget","limit","required","unit","completed_statements","emitted_rows","emitted_segments","completion","proposal","step","generation","attachment","lease","schema_origin","sampling_records","operation","native_cause","expected_bytes","presence","published","subscription","expected_codec","actual_codec","observed_clock","expected_namespace","actual_namespace","attempt","executor","resolution_reason","principal","deadline","authorization_policy","resolution_policy","protocol_status","native_effect","dependency","dependency_kind","dependency_owner"]};

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
if(typeof data !== "string"){
validate108.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((data === "object") || (data === "name")) || (data === "table")) || (data === "native_input")) || (data === "affected_rows")) || (data === "argument")) || (data === "option")) || (data === "permissions")) || (data === "scope")) || (data === "column")) || (data === "qualifier")) || (data === "constraint")) || (data === "key")) || (data === "input_row")) || (data === "first_occurrence")) || (data === "parameter")) || (data === "parameter_use")) || (data === "expected_count")) || (data === "actual_count")) || (data === "expected_type")) || (data === "actual_type")) || (data === "supplied_value")) || (data === "expected_value")) || (data === "expression")) || (data === "source_kind")) || (data === "source_basis")) || (data === "source_key")) || (data === "source_row")) || (data === "field_path")) || (data === "byte_offset")) || (data === "expected_resource")) || (data === "actual_resource")) || (data === "expected_source")) || (data === "actual_source")) || (data === "expected_revision")) || (data === "actual_revision")) || (data === "expected_schema")) || (data === "actual_schema")) || (data === "expected_policy")) || (data === "actual_policy")) || (data === "budget")) || (data === "limit")) || (data === "required")) || (data === "unit")) || (data === "completed_statements")) || (data === "emitted_rows")) || (data === "emitted_segments")) || (data === "completion")) || (data === "proposal")) || (data === "step")) || (data === "generation")) || (data === "attachment")) || (data === "lease")) || (data === "schema_origin")) || (data === "sampling_records")) || (data === "operation")) || (data === "native_cause")) || (data === "expected_bytes")) || (data === "presence")) || (data === "published")) || (data === "subscription")) || (data === "expected_codec")) || (data === "actual_codec")) || (data === "observed_clock")) || (data === "expected_namespace")) || (data === "actual_namespace")) || (data === "attempt")) || (data === "executor")) || (data === "resolution_reason")) || (data === "principal")) || (data === "deadline")) || (data === "authorization_policy")) || (data === "resolution_policy")) || (data === "protocol_status")) || (data === "native_effect")) || (data === "dependency")) || (data === "dependency_kind")) || (data === "dependency_owner"))){
validate108.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema41.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate108.errors = vErrors;
return errors === 0;
}
validate108.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema42 = {"type":"string","enum":["caller","execution","schema","authority","owner"]};

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
if(typeof data !== "string"){
validate110.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((data === "caller") || (data === "execution")) || (data === "schema")) || (data === "authority")) || (data === "owner"))){
validate110.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema42.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate110.errors = vErrors;
return errors === 0;
}
validate110.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema43 = {"type":"string","enum":["provided","truncated","unrecorded","unavailable","withheld","inapplicable"]};

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
if(typeof data !== "string"){
validate112.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((data === "provided") || (data === "truncated")) || (data === "unrecorded")) || (data === "unavailable")) || (data === "withheld")) || (data === "inapplicable"))){
validate112.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema43.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate112.errors = vErrors;
return errors === 0;
}
validate112.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema44 = {"type":"object","additionalProperties":false,"required":["text"],"properties":{"text":{"type":"string","maxLength":256}}};

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
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.text === undefined) && (missing0 = "text")){
validate114.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "text")){
validate114.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
validate114.errors = [{instancePath:instancePath+"/text",schemaPath:"#/properties/text/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"}];
return false;
}
}
else {
validate114.errors = [{instancePath:instancePath+"/text",schemaPath:"#/properties/text/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
}
}
}
}
else {
validate114.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate114.errors = vErrors;
return errors === 0;
}
validate114.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema45 = {"type":"object","additionalProperties":false,"required":["signed"],"properties":{"signed":{"$ref":"https://transit.invalid/generated-validator/24"}}};
const schema46 = {"type":"string","maxLength":20,"pattern":"^(0|-?[1-9][0-9]*)$"};
const pattern4 = new RegExp("^(0|-?[1-9][0-9]*)$", "u");

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
if(typeof data === "string"){
if(func2(data) > 20){
validate117.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern4.test(data)){
validate117.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(0|-?[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|-?[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate117.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate117.errors = vErrors;
return errors === 0;
}
validate117.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.signed === undefined) && (missing0 = "signed")){
validate116.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "signed")){
validate116.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.signed !== undefined){
if(!(validate117(data.signed, {instancePath:instancePath+"/signed",parentData:data,parentDataProperty:"signed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate117.errors : vErrors.concat(validate117.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate116.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate116.errors = vErrors;
return errors === 0;
}
validate116.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema47 = {"type":"object","additionalProperties":false,"required":["unsigned"],"properties":{"unsigned":{"$ref":"https://transit.invalid/generated-validator/13"}}};

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
if((data.unsigned === undefined) && (missing0 = "unsigned")){
validate120.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "unsigned")){
validate120.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.unsigned !== undefined){
if(!(validate88(data.unsigned, {instancePath:instancePath+"/unsigned",parentData:data,parentDataProperty:"unsigned",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate88.errors : vErrors.concat(validate88.errors);
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

const schema48 = {"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"type":"boolean"}}};

function validate123(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate123.evaluated;
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
validate123.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "boolean")){
validate123.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.boolean !== undefined){
if(typeof data.boolean !== "boolean"){
validate123.errors = [{instancePath:instancePath+"/boolean",schemaPath:"#/properties/boolean/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
}
}
}
}
else {
validate123.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate123.errors = vErrors;
return errors === 0;
}
validate123.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema49 = {"type":"object","additionalProperties":false,"required":["digest"],"properties":{"digest":{"$ref":"https://transit.invalid/generated-validator/4"}}};

function validate125(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate125.evaluated;
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
validate125.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "digest")){
validate125.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.digest !== undefined){
if(!(validate64(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate125.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate125.errors = vErrors;
return errors === 0;
}
validate125.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema50 = {"type":"string","enum":["correct_input","inspect_status","resume_exact","cancel_wait","cancel_mutation","refresh","recompile","retry_read","inspect_scope","reconcile_effect","contact_operator"]};

function validate129(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate129.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate129.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((data === "correct_input") || (data === "inspect_status")) || (data === "resume_exact")) || (data === "cancel_wait")) || (data === "cancel_mutation")) || (data === "refresh")) || (data === "recompile")) || (data === "retry_read")) || (data === "inspect_scope")) || (data === "reconcile_effect")) || (data === "contact_operator"))){
validate129.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema50.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate129.errors = vErrors;
return errors === 0;
}
validate129.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if((((((((((((((data.version === undefined) && (missing0 = "version")) || ((data.definition === undefined) && (missing0 = "definition"))) || ((data.code === undefined) && (missing0 = "code"))) || ((data.category === undefined) && (missing0 = "category"))) || ((data.stage === undefined) && (missing0 = "stage"))) || ((data.outcome === undefined) && (missing0 = "outcome"))) || ((data.evidence === undefined) && (missing0 = "evidence"))) || ((data.message === undefined) && (missing0 = "message"))) || ((data.cause === undefined) && (missing0 = "cause"))) || ((data.identity === undefined) && (missing0 = "identity"))) || ((data.location === undefined) && (missing0 = "location"))) || ((data.facts === undefined) && (missing0 = "facts"))) || ((data.actions === undefined) && (missing0 = "actions"))){
validate72.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema27.properties, key0))){
validate72.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate72.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"}];
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
if(!(validate54(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
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
validate72.errors = [{instancePath:instancePath+"/code",schemaPath:"#/properties/code/maxLength",keyword:"maxLength",params:{limit: 96},message:"must NOT have more than 96 characters"}];
return false;
}
}
else {
validate72.errors = [{instancePath:instancePath+"/code",schemaPath:"#/properties/code/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
if(!(validate74(data.category, {instancePath:instancePath+"/category",parentData:data,parentDataProperty:"category",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate74.errors : vErrors.concat(validate74.errors);
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
if(!(validate76(data.stage, {instancePath:instancePath+"/stage",parentData:data,parentDataProperty:"stage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate76.errors : vErrors.concat(validate76.errors);
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
if(!(validate78(data.outcome, {instancePath:instancePath+"/outcome",parentData:data,parentDataProperty:"outcome",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate78.errors : vErrors.concat(validate78.errors);
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
if(!(validate80(data.evidence, {instancePath:instancePath+"/evidence",parentData:data,parentDataProperty:"evidence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate80.errors : vErrors.concat(validate80.errors);
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
validate72.errors = [{instancePath:instancePath+"/message",schemaPath:"#/properties/message/maxLength",keyword:"maxLength",params:{limit: 384},message:"must NOT have more than 384 characters"}];
return false;
}
}
else {
validate72.errors = [{instancePath:instancePath+"/message",schemaPath:"#/properties/message/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
if(!(validate82(data.cause, {instancePath:instancePath+"/cause",parentData:data,parentDataProperty:"cause",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate82.errors : vErrors.concat(validate82.errors);
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
if(!(validate84(data.identity, {instancePath:instancePath+"/identity",parentData:data,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate84.errors : vErrors.concat(validate84.errors);
errors = vErrors.length;
}
var valid0 = _errs13 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.location !== undefined){
let data10 = data.location;
const _errs14 = errors;
const _errs15 = errors;
let valid1 = false;
const _errs16 = errors;
if(!(validate97(data10, {instancePath:instancePath+"/location",parentData:data,parentDataProperty:"location",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate97.errors : vErrors.concat(validate97.errors);
errors = vErrors.length;
}
var _valid0 = _errs16 === errors;
valid1 = valid1 || _valid0;
const _errs17 = errors;
if(data10 !== null){
const err0 = {instancePath:instancePath+"/location",schemaPath:"#/properties/location/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
}
var _valid0 = _errs17 === errors;
valid1 = valid1 || _valid0;
if(!valid1){
const err1 = {instancePath:instancePath+"/location",schemaPath:"#/properties/location/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate72.errors = vErrors;
return false;
}
else {
errors = _errs15;
if(vErrors !== null){
if(_errs15){
vErrors.length = _errs15;
}
else {
vErrors = null;
}
}
}
var valid0 = _errs14 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.facts !== undefined){
let data11 = data.facts;
const _errs19 = errors;
if(errors === _errs19){
if(Array.isArray(data11)){
if(data11.length > 16){
validate72.errors = [{instancePath:instancePath+"/facts",schemaPath:"#/properties/facts/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
if(data11.length < 16){
validate72.errors = [{instancePath:instancePath+"/facts",schemaPath:"#/properties/facts/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"}];
return false;
}
else {
var valid2 = true;
const len0 = data11.length;
for(let i0=0; i0<len0; i0++){
let data12 = data11[i0];
const _errs21 = errors;
const _errs22 = errors;
let valid3 = false;
const _errs23 = errors;
if(errors === _errs23){
if(data12 && typeof data12 == "object" && !Array.isArray(data12)){
let missing1;
if(((((data12.field === undefined) && (missing1 = "field")) || ((data12.origin === undefined) && (missing1 = "origin"))) || ((data12.availability === undefined) && (missing1 = "availability"))) || ((data12.value === undefined) && (missing1 = "value"))){
const err2 = {instancePath:instancePath+"/facts/" + i0,schemaPath:"#/properties/facts/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
if(vErrors === null){
vErrors = [err2];
}
else {
vErrors.push(err2);
}
errors++;
}
else {
const _errs25 = errors;
for(const key1 in data12){
if(!((((key1 === "field") || (key1 === "origin")) || (key1 === "availability")) || (key1 === "value"))){
const err3 = {instancePath:instancePath+"/facts/" + i0,schemaPath:"#/properties/facts/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(_errs25 === errors){
if(data12.field !== undefined){
const _errs26 = errors;
if(!(validate108(data12.field, {instancePath:instancePath+"/facts/" + i0+"/field",parentData:data12,parentDataProperty:"field",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate108.errors : vErrors.concat(validate108.errors);
errors = vErrors.length;
}
var valid4 = _errs26 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data12.origin !== undefined){
const _errs27 = errors;
if(!(validate110(data12.origin, {instancePath:instancePath+"/facts/" + i0+"/origin",parentData:data12,parentDataProperty:"origin",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate110.errors : vErrors.concat(validate110.errors);
errors = vErrors.length;
}
var valid4 = _errs27 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data12.availability !== undefined){
const _errs28 = errors;
if(!(validate112(data12.availability, {instancePath:instancePath+"/facts/" + i0+"/availability",parentData:data12,parentDataProperty:"availability",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate112.errors : vErrors.concat(validate112.errors);
errors = vErrors.length;
}
var valid4 = _errs28 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data12.value !== undefined){
let data16 = data12.value;
const _errs29 = errors;
const _errs30 = errors;
let valid5 = false;
const _errs31 = errors;
const _errs32 = errors;
let valid6 = false;
let passing0 = null;
const _errs33 = errors;
if(!(validate114(data16, {instancePath:instancePath+"/facts/" + i0+"/value",parentData:data12,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate114.errors : vErrors.concat(validate114.errors);
errors = vErrors.length;
}
var _valid3 = _errs33 === errors;
if(_valid3){
valid6 = true;
passing0 = 0;
var props2 = true;
}
const _errs34 = errors;
if(!(validate116(data16, {instancePath:instancePath+"/facts/" + i0+"/value",parentData:data12,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate116.errors : vErrors.concat(validate116.errors);
errors = vErrors.length;
}
var _valid3 = _errs34 === errors;
if(_valid3 && valid6){
valid6 = false;
passing0 = [passing0, 1];
}
else {
if(_valid3){
valid6 = true;
passing0 = 1;
if(props2 !== true){
props2 = true;
}
}
const _errs35 = errors;
if(!(validate120(data16, {instancePath:instancePath+"/facts/" + i0+"/value",parentData:data12,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate120.errors : vErrors.concat(validate120.errors);
errors = vErrors.length;
}
var _valid3 = _errs35 === errors;
if(_valid3 && valid6){
valid6 = false;
passing0 = [passing0, 2];
}
else {
if(_valid3){
valid6 = true;
passing0 = 2;
if(props2 !== true){
props2 = true;
}
}
const _errs36 = errors;
if(!(validate123(data16, {instancePath:instancePath+"/facts/" + i0+"/value",parentData:data12,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate123.errors : vErrors.concat(validate123.errors);
errors = vErrors.length;
}
var _valid3 = _errs36 === errors;
if(_valid3 && valid6){
valid6 = false;
passing0 = [passing0, 3];
}
else {
if(_valid3){
valid6 = true;
passing0 = 3;
if(props2 !== true){
props2 = true;
}
}
const _errs37 = errors;
if(!(validate125(data16, {instancePath:instancePath+"/facts/" + i0+"/value",parentData:data12,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate125.errors : vErrors.concat(validate125.errors);
errors = vErrors.length;
}
var _valid3 = _errs37 === errors;
if(_valid3 && valid6){
valid6 = false;
passing0 = [passing0, 4];
}
else {
if(_valid3){
valid6 = true;
passing0 = 4;
if(props2 !== true){
props2 = true;
}
}
const _errs38 = errors;
if(errors === _errs38){
if(data16 && typeof data16 == "object" && !Array.isArray(data16)){
let missing2;
if((data16.location === undefined) && (missing2 = "location")){
const err4 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
}
else {
const _errs40 = errors;
for(const key2 in data16){
if(!(key2 === "location")){
const err5 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(_errs40 === errors){
if(data16.location !== undefined){
if(!(validate97(data16.location, {instancePath:instancePath+"/facts/" + i0+"/value/location",parentData:data16,parentDataProperty:"location",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate97.errors : vErrors.concat(validate97.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err6 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err6];
}
else {
vErrors.push(err6);
}
errors++;
}
}
var _valid3 = _errs38 === errors;
if(_valid3 && valid6){
valid6 = false;
passing0 = [passing0, 5];
}
else {
if(_valid3){
valid6 = true;
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
if(!valid6){
const err7 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err7];
}
else {
vErrors.push(err7);
}
errors++;
}
else {
errors = _errs32;
if(vErrors !== null){
if(_errs32){
vErrors.length = _errs32;
}
else {
vErrors = null;
}
}
}
var _valid2 = _errs31 === errors;
valid5 = valid5 || _valid2;
const _errs42 = errors;
if(data16 !== null){
const err8 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err8];
}
else {
vErrors.push(err8);
}
errors++;
}
var _valid2 = _errs42 === errors;
valid5 = valid5 || _valid2;
if(!valid5){
const err9 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
}
else {
errors = _errs30;
if(vErrors !== null){
if(_errs30){
vErrors.length = _errs30;
}
else {
vErrors = null;
}
}
}
var valid4 = _errs29 === errors;
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
else {
const err10 = {instancePath:instancePath+"/facts/" + i0,schemaPath:"#/properties/facts/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
}
}
var _valid1 = _errs23 === errors;
valid3 = valid3 || _valid1;
const _errs44 = errors;
if(data12 !== null){
const err11 = {instancePath:instancePath+"/facts/" + i0,schemaPath:"#/properties/facts/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err11];
}
else {
vErrors.push(err11);
}
errors++;
}
var _valid1 = _errs44 === errors;
valid3 = valid3 || _valid1;
if(!valid3){
const err12 = {instancePath:instancePath+"/facts/" + i0,schemaPath:"#/properties/facts/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
validate72.errors = vErrors;
return false;
}
else {
errors = _errs22;
if(vErrors !== null){
if(_errs22){
vErrors.length = _errs22;
}
else {
vErrors = null;
}
}
}
var valid2 = _errs21 === errors;
if(!valid2){
break;
}
}
}
}
}
else {
validate72.errors = [{instancePath:instancePath+"/facts",schemaPath:"#/properties/facts/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid0 = _errs19 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.actions !== undefined){
let data18 = data.actions;
const _errs46 = errors;
if(errors === _errs46){
if(Array.isArray(data18)){
if(data18.length > 4){
validate72.errors = [{instancePath:instancePath+"/actions",schemaPath:"#/properties/actions/maxItems",keyword:"maxItems",params:{limit: 4},message:"must NOT have more than 4 items"}];
return false;
}
else {
if(data18.length < 4){
validate72.errors = [{instancePath:instancePath+"/actions",schemaPath:"#/properties/actions/minItems",keyword:"minItems",params:{limit: 4},message:"must NOT have fewer than 4 items"}];
return false;
}
else {
var valid8 = true;
const len1 = data18.length;
for(let i1=0; i1<len1; i1++){
let data19 = data18[i1];
const _errs48 = errors;
const _errs49 = errors;
let valid9 = false;
const _errs50 = errors;
if(errors === _errs50){
if(data19 && typeof data19 == "object" && !Array.isArray(data19)){
let missing3;
if(((data19.kind === undefined) && (missing3 = "kind")) || ((data19.target === undefined) && (missing3 = "target"))){
const err13 = {instancePath:instancePath+"/actions/" + i1,schemaPath:"#/properties/actions/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
if(vErrors === null){
vErrors = [err13];
}
else {
vErrors.push(err13);
}
errors++;
}
else {
const _errs52 = errors;
for(const key3 in data19){
if(!((key3 === "kind") || (key3 === "target"))){
const err14 = {instancePath:instancePath+"/actions/" + i1,schemaPath:"#/properties/actions/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(_errs52 === errors){
if(data19.kind !== undefined){
const _errs53 = errors;
if(!(validate129(data19.kind, {instancePath:instancePath+"/actions/" + i1+"/kind",parentData:data19,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate129.errors : vErrors.concat(validate129.errors);
errors = vErrors.length;
}
var valid10 = _errs53 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data19.target !== undefined){
const _errs54 = errors;
if(!(validate84(data19.target, {instancePath:instancePath+"/actions/" + i1+"/target",parentData:data19,parentDataProperty:"target",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate84.errors : vErrors.concat(validate84.errors);
errors = vErrors.length;
}
var valid10 = _errs54 === errors;
}
else {
var valid10 = true;
}
}
}
}
}
else {
const err15 = {instancePath:instancePath+"/actions/" + i1,schemaPath:"#/properties/actions/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
}
}
var _valid4 = _errs50 === errors;
valid9 = valid9 || _valid4;
const _errs55 = errors;
if(data19 !== null){
const err16 = {instancePath:instancePath+"/actions/" + i1,schemaPath:"#/properties/actions/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err16];
}
else {
vErrors.push(err16);
}
errors++;
}
var _valid4 = _errs55 === errors;
valid9 = valid9 || _valid4;
if(!valid9){
const err17 = {instancePath:instancePath+"/actions/" + i1,schemaPath:"#/properties/actions/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err17];
}
else {
vErrors.push(err17);
}
errors++;
validate72.errors = vErrors;
return false;
}
else {
errors = _errs49;
if(vErrors !== null){
if(_errs49){
vErrors.length = _errs49;
}
else {
vErrors = null;
}
}
}
var valid8 = _errs48 === errors;
if(!valid8){
break;
}
}
}
}
}
else {
validate72.errors = [{instancePath:instancePath+"/actions",schemaPath:"#/properties/actions/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid0 = _errs46 === errors;
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
validate72.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate72.errors = vErrors;
return errors === 0;
}
validate72.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const SignedCommand = validate132;
const schema51 = {"type":"object","additionalProperties":false,"properties":{"request":{"$ref":"https://transit.invalid/generated-validator/33"},"signature":{"$ref":"https://transit.invalid/generated-validator/6"}},"required":["request","signature"]};
const schema52 = {"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"definition":{"$ref":"https://transit.invalid/generated-validator/0"},"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"principal":{"$ref":"https://transit.invalid/generated-validator/1"},"sequence":{"$ref":"https://transit.invalid/generated-validator/1"},"command":{"$ref":"https://transit.invalid/generated-validator/32"}},"required":["definition","realm","principal","sequence","command"]};
const schema53 = {"type":"object","additionalProperties":false,"properties":{"send":{"$ref":"https://transit.invalid/generated-validator/31"}},"required":["send"]};
const schema54 = {"type":"object","additionalProperties":false,"properties":{"pid":{"$ref":"https://transit.invalid/generated-validator/1"},"value":{"$ref":"https://transit.invalid/generated-validator/30"},"role":{"$ref":"https://transit.invalid/generated-validator/2"}},"required":["pid","value"]};
const schema55 = {"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512};
const pattern5 = new RegExp("^(?:[0-9a-f]{2})*$", "u");

function validate141(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate141.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func2(data) > 512){
validate141.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"}];
return false;
}
else {
if(!pattern5.test(data)){
validate141.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""}];
return false;
}
}
}
else {
validate141.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate141.errors = vErrors;
return errors === 0;
}
validate141.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate139(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate139.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.pid === undefined) && (missing0 = "pid")) || ((data.value === undefined) && (missing0 = "value"))){
validate139.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "pid") || (key0 === "value")) || (key0 === "role"))){
validate139.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.pid !== undefined){
const _errs2 = errors;
if(!(validate56(data.pid, {instancePath:instancePath+"/pid",parentData:data,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate141(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate141.errors : vErrors.concat(validate141.errors);
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
if(!(validate60(data.role, {instancePath:instancePath+"/role",parentData:data,parentDataProperty:"role",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate60.errors : vErrors.concat(validate60.errors);
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
validate139.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate139.errors = vErrors;
return errors === 0;
}
validate139.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if((data.send === undefined) && (missing0 = "send")){
validate138.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "send")){
validate138.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.send !== undefined){
if(!(validate139(data.send, {instancePath:instancePath+"/send",parentData:data,parentDataProperty:"send",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate139.errors : vErrors.concat(validate139.errors);
errors = vErrors.length;
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
if((((((data.definition === undefined) && (missing0 = "definition")) || ((data.realm === undefined) && (missing0 = "realm"))) || ((data.principal === undefined) && (missing0 = "principal"))) || ((data.sequence === undefined) && (missing0 = "sequence"))) || ((data.command === undefined) && (missing0 = "command"))){
validate133.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "version") || (key0 === "definition")) || (key0 === "realm")) || (key0 === "principal")) || (key0 === "sequence")) || (key0 === "command"))){
validate133.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate133.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"}];
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
if(!(validate54(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
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
if(data.sequence !== undefined){
const _errs6 = errors;
if(!(validate56(data.sequence, {instancePath:instancePath+"/sequence",parentData:data,parentDataProperty:"sequence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.command !== undefined){
const _errs7 = errors;
if(!(validate138(data.command, {instancePath:instancePath+"/command",parentData:data,parentDataProperty:"command",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate138.errors : vErrors.concat(validate138.errors);
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
validate133.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate133.errors = vErrors;
return errors === 0;
}
validate133.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(((data.request === undefined) && (missing0 = "request")) || ((data.signature === undefined) && (missing0 = "signature"))){
validate132.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "request") || (key0 === "signature"))){
validate132.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.request !== undefined){
const _errs2 = errors;
if(!(validate133(data.request, {instancePath:instancePath+"/request",parentData:data,parentDataProperty:"request",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate133.errors : vErrors.concat(validate133.errors);
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
if(!(validate69(data.signature, {instancePath:instancePath+"/signature",parentData:data,parentDataProperty:"signature",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate69.errors : vErrors.concat(validate69.errors);
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
validate132.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate132.errors = vErrors;
return errors === 0;
}
validate132.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const ServingRead = validate148;
const schema56 = {"type":"object","additionalProperties":false,"properties":{"read":{"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"principal":{"$ref":"https://transit.invalid/generated-validator/1"},"service":{"$ref":"https://transit.invalid/generated-validator/1"},"ingress":{"$ref":"https://transit.invalid/generated-validator/1"},"kind":{"type":"string","enum":["discovery","status","result","disposition"]},"operation":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["realm","principal","service","ingress","kind"]},"proof":{"$ref":"SubjectProof"}},"required":["read","proof"]};

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
if(((data.read === undefined) && (missing0 = "read")) || ((data.proof === undefined) && (missing0 = "proof"))){
validate148.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "read") || (key0 === "proof"))){
validate148.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.read !== undefined){
let data0 = data.read;
const _errs2 = errors;
if(errors === _errs2){
if(data0 && typeof data0 == "object" && !Array.isArray(data0)){
let missing1;
if((((((data0.realm === undefined) && (missing1 = "realm")) || ((data0.principal === undefined) && (missing1 = "principal"))) || ((data0.service === undefined) && (missing1 = "service"))) || ((data0.ingress === undefined) && (missing1 = "ingress"))) || ((data0.kind === undefined) && (missing1 = "kind"))){
validate148.errors = [{instancePath:instancePath+"/read",schemaPath:"#/properties/read/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"}];
return false;
}
else {
const _errs4 = errors;
for(const key1 in data0){
if(!((((((key1 === "realm") || (key1 === "principal")) || (key1 === "service")) || (key1 === "ingress")) || (key1 === "kind")) || (key1 === "operation"))){
validate148.errors = [{instancePath:instancePath+"/read",schemaPath:"#/properties/read/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs4 === errors){
if(data0.realm !== undefined){
const _errs5 = errors;
if(!(validate56(data0.realm, {instancePath:instancePath+"/read/realm",parentData:data0,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid1 = _errs5 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.principal !== undefined){
const _errs6 = errors;
if(!(validate56(data0.principal, {instancePath:instancePath+"/read/principal",parentData:data0,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid1 = _errs6 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.service !== undefined){
const _errs7 = errors;
if(!(validate56(data0.service, {instancePath:instancePath+"/read/service",parentData:data0,parentDataProperty:"service",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid1 = _errs7 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.ingress !== undefined){
const _errs8 = errors;
if(!(validate56(data0.ingress, {instancePath:instancePath+"/read/ingress",parentData:data0,parentDataProperty:"ingress",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid1 = _errs8 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.kind !== undefined){
let data5 = data0.kind;
const _errs9 = errors;
if(typeof data5 !== "string"){
validate148.errors = [{instancePath:instancePath+"/read/kind",schemaPath:"#/properties/read/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((data5 === "discovery") || (data5 === "status")) || (data5 === "result")) || (data5 === "disposition"))){
validate148.errors = [{instancePath:instancePath+"/read/kind",schemaPath:"#/properties/read/properties/kind/enum",keyword:"enum",params:{allowedValues: schema56.properties.read.properties.kind.enum},message:"must be equal to one of the allowed values"}];
return false;
}
var valid1 = _errs9 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.operation !== undefined){
const _errs11 = errors;
if(!(validate56(data0.operation, {instancePath:instancePath+"/read/operation",parentData:data0,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid1 = _errs11 === errors;
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
validate148.errors = [{instancePath:instancePath+"/read",schemaPath:"#/properties/read/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.proof !== undefined){
const _errs12 = errors;
if(!(validate52(data.proof, {instancePath:instancePath+"/proof",parentData:data,parentDataProperty:"proof",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate52.errors : vErrors.concat(validate52.errors);
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
else {
validate148.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate148.errors = vErrors;
return errors === 0;
}
validate148.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const ServingResponse = validate155;
const schema57 = {"type":"object","additionalProperties":false,"properties":{"service":{"$ref":"https://transit.invalid/generated-validator/1"},"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"revision":{"$ref":"https://transit.invalid/generated-validator/1"},"policy_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"stage":{"$ref":"https://transit.invalid/generated-validator/34"},"binding":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"revision":{"$ref":"https://transit.invalid/generated-validator/1"},"target":{"$ref":"https://transit.invalid/generated-validator/1"},"codec":{"$ref":"https://transit.invalid/generated-validator/35"},"active_limit":{"$ref":"https://transit.invalid/generated-validator/3"},"wait_before_ms":{"$ref":"https://transit.invalid/generated-validator/1"},"published":{"type":"boolean"}},"required":["revision","target","codec","active_limit","wait_before_ms"]},{"type":"null"}]},"operation":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"principal":{"$ref":"https://transit.invalid/generated-validator/1"},"operation":{"$ref":"https://transit.invalid/generated-validator/1"},"binding":{"$ref":"https://transit.invalid/generated-validator/1"},"codec":{"$ref":"https://transit.invalid/generated-validator/35"},"deadline_ms":{"$ref":"https://transit.invalid/generated-validator/1"},"digest":{"$ref":"https://transit.invalid/generated-validator/4"},"target":{"$ref":"https://transit.invalid/generated-validator/1"},"correlation":{"$ref":"https://transit.invalid/generated-validator/1"},"policy_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"phase":{"$ref":"https://transit.invalid/generated-validator/36"},"resolution_input":{"$ref":"https://transit.invalid/generated-validator/1"},"result":{"$ref":"https://transit.invalid/generated-validator/30"},"reply_bytes":{"$ref":"https://transit.invalid/generated-validator/35"}},"required":["principal","operation","binding","codec","deadline_ms","digest","target","correlation","policy_revision"]},{"type":"null"}]},"diagnostic":{"anyOf":[{"$ref":"Diagnostic"},{"type":"null"}]},"disposition":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"record":{"$ref":"https://transit.invalid/generated-validator/39"},"diagnostic":{"anyOf":[{"$ref":"Diagnostic"},{"type":"null"}]}},"required":["record","diagnostic"]},{"type":"null"}]},"capabilities":{"type":"object","additionalProperties":false,"properties":{"http":{"type":"boolean"},"sse":{"type":"boolean"},"websocket":{"type":"boolean"},"grpc":{"type":"boolean"},"flight":{"type":"boolean"}},"required":[]}},"required":["service","resource","revision","policy_revision"]};
const schema58 = {"type":"string","enum":["ingress_accepted","not_observed","service_admitted","completed","cancelled","timed_out","failed","rejected"]};

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
if(typeof data !== "string"){
validate160.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((data === "ingress_accepted") || (data === "not_observed")) || (data === "service_admitted")) || (data === "completed")) || (data === "cancelled")) || (data === "timed_out")) || (data === "failed")) || (data === "rejected"))){
validate160.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema58.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate160.errors = vErrors;
return errors === 0;
}
validate160.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema59 = {"type":"integer","minimum":0,"maximum":65535};

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
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate164.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 65535 || isNaN(data)){
validate164.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate164.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate164.errors = vErrors;
return errors === 0;
}
validate164.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema60 = {"type":"string","enum":["admitted","completed","cancelled","timed_out","failed"]};

function validate177(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate177.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate177.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((data === "admitted") || (data === "completed")) || (data === "cancelled")) || (data === "timed_out")) || (data === "failed"))){
validate177.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema60.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate177.errors = vErrors;
return errors === 0;
}
validate177.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema61 = {"type":"object","additionalProperties":false,"properties":{"reason":{"$ref":"https://transit.invalid/generated-validator/37"},"input":{"$ref":"https://transit.invalid/generated-validator/1"},"kind":{"$ref":"https://transit.invalid/generated-validator/38"},"subject":{"$ref":"https://transit.invalid/generated-validator/13"},"generation":{"$ref":"https://transit.invalid/generated-validator/13"},"payload":{"$ref":"https://transit.invalid/generated-validator/4"},"cause":{"$ref":"https://transit.invalid/generated-validator/30"}},"required":["reason","input","kind","subject","generation","payload","cause"]};
const schema62 = {"type":"string","enum":["InvalidServingFrame","ServingExternalOriginRequired","UnexpectedServingOrigin","InvalidServingCommand","InvalidServingIdentity","InvalidServiceBinding","InvalidServicePolicy","ServingDenied","ServiceRevisionConflict","ServingIdentityConflict","ServingCapacity","ServiceUnpublished","InvalidWaitLifetime","ServingOperationNotFound","UnknownServingCorrelation","UnexpectedServingReplySource","UnexpectedTimerObserver","InvalidTimerObservation","PrematureTimer","UnsupportedServingFrame","InvalidReactiveSource","ReactiveSessionNotFound","ReactiveGenerationConflict","ReactiveSessionClosed","ReactiveSessionExpired","ReactiveResetRequired","InvalidReactiveLease","ReactiveCapacity","InvalidReactiveAttachment","ReactiveAttachmentConflict","ReactiveSubscriptionConflict","ReactiveLeaseConflict","InvalidRefreshBudget","InvalidRefreshTemplate","RefreshGenerationConflict","RefreshNotFound","RefreshResultConflict","UnexpectedRefreshWake","AccessDenied","QueryDenied","CatalogDenied","ResourceUnavailable","QuerySourceUnavailable","ResultUnavailable","PublicationNotPublished","UnsupportedReactiveSource","InvalidReactiveProgress","TableNotFound"]};

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
if(typeof data !== "string"){
validate184.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((((((((((((((((((((((((((((((((((((((data === "InvalidServingFrame") || (data === "ServingExternalOriginRequired")) || (data === "UnexpectedServingOrigin")) || (data === "InvalidServingCommand")) || (data === "InvalidServingIdentity")) || (data === "InvalidServiceBinding")) || (data === "InvalidServicePolicy")) || (data === "ServingDenied")) || (data === "ServiceRevisionConflict")) || (data === "ServingIdentityConflict")) || (data === "ServingCapacity")) || (data === "ServiceUnpublished")) || (data === "InvalidWaitLifetime")) || (data === "ServingOperationNotFound")) || (data === "UnknownServingCorrelation")) || (data === "UnexpectedServingReplySource")) || (data === "UnexpectedTimerObserver")) || (data === "InvalidTimerObservation")) || (data === "PrematureTimer")) || (data === "UnsupportedServingFrame")) || (data === "InvalidReactiveSource")) || (data === "ReactiveSessionNotFound")) || (data === "ReactiveGenerationConflict")) || (data === "ReactiveSessionClosed")) || (data === "ReactiveSessionExpired")) || (data === "ReactiveResetRequired")) || (data === "InvalidReactiveLease")) || (data === "ReactiveCapacity")) || (data === "InvalidReactiveAttachment")) || (data === "ReactiveAttachmentConflict")) || (data === "ReactiveSubscriptionConflict")) || (data === "ReactiveLeaseConflict")) || (data === "InvalidRefreshBudget")) || (data === "InvalidRefreshTemplate")) || (data === "RefreshGenerationConflict")) || (data === "RefreshNotFound")) || (data === "RefreshResultConflict")) || (data === "UnexpectedRefreshWake")) || (data === "AccessDenied")) || (data === "QueryDenied")) || (data === "CatalogDenied")) || (data === "ResourceUnavailable")) || (data === "QuerySourceUnavailable")) || (data === "ResultUnavailable")) || (data === "PublicationNotPublished")) || (data === "UnsupportedReactiveSource")) || (data === "InvalidReactiveProgress")) || (data === "TableNotFound"))){
validate184.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema62.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate184.errors = vErrors;
return errors === 0;
}
validate184.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema63 = {"type":"string","enum":["service","reactive","refresh"]};

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
if(!(((data === "service") || (data === "reactive")) || (data === "refresh"))){
validate187.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema63.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate187.errors = vErrors;
return errors === 0;
}
validate187.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if((((((((data.reason === undefined) && (missing0 = "reason")) || ((data.input === undefined) && (missing0 = "input"))) || ((data.kind === undefined) && (missing0 = "kind"))) || ((data.subject === undefined) && (missing0 = "subject"))) || ((data.generation === undefined) && (missing0 = "generation"))) || ((data.payload === undefined) && (missing0 = "payload"))) || ((data.cause === undefined) && (missing0 = "cause"))){
validate183.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "reason") || (key0 === "input")) || (key0 === "kind")) || (key0 === "subject")) || (key0 === "generation")) || (key0 === "payload")) || (key0 === "cause"))){
validate183.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.reason !== undefined){
const _errs2 = errors;
if(!(validate184(data.reason, {instancePath:instancePath+"/reason",parentData:data,parentDataProperty:"reason",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate184.errors : vErrors.concat(validate184.errors);
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
if(data.kind !== undefined){
const _errs4 = errors;
if(!(validate187(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate187.errors : vErrors.concat(validate187.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.subject !== undefined){
const _errs5 = errors;
if(!(validate88(data.subject, {instancePath:instancePath+"/subject",parentData:data,parentDataProperty:"subject",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate88.errors : vErrors.concat(validate88.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.generation !== undefined){
const _errs6 = errors;
if(!(validate88(data.generation, {instancePath:instancePath+"/generation",parentData:data,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate88.errors : vErrors.concat(validate88.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.payload !== undefined){
const _errs7 = errors;
if(!(validate64(data.payload, {instancePath:instancePath+"/payload",parentData:data,parentDataProperty:"payload",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.cause !== undefined){
const _errs8 = errors;
if(!(validate141(data.cause, {instancePath:instancePath+"/cause",parentData:data,parentDataProperty:"cause",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate141.errors : vErrors.concat(validate141.errors);
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
validate183.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate183.errors = vErrors;
return errors === 0;
}
validate183.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate155(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate155.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.service === undefined) && (missing0 = "service")) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.revision === undefined) && (missing0 = "revision"))) || ((data.policy_revision === undefined) && (missing0 = "policy_revision"))){
validate155.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema57.properties, key0))){
validate155.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.service !== undefined){
const _errs2 = errors;
if(!(validate56(data.service, {instancePath:instancePath+"/service",parentData:data,parentDataProperty:"service",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate56(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.revision !== undefined){
const _errs4 = errors;
if(!(validate56(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate56(data.policy_revision, {instancePath:instancePath+"/policy_revision",parentData:data,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate160(data.stage, {instancePath:instancePath+"/stage",parentData:data,parentDataProperty:"stage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate160.errors : vErrors.concat(validate160.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.binding !== undefined){
let data5 = data.binding;
const _errs7 = errors;
const _errs8 = errors;
let valid1 = false;
const _errs9 = errors;
if(errors === _errs9){
if(data5 && typeof data5 == "object" && !Array.isArray(data5)){
let missing1;
if((((((data5.revision === undefined) && (missing1 = "revision")) || ((data5.target === undefined) && (missing1 = "target"))) || ((data5.codec === undefined) && (missing1 = "codec"))) || ((data5.active_limit === undefined) && (missing1 = "active_limit"))) || ((data5.wait_before_ms === undefined) && (missing1 = "wait_before_ms"))){
const err0 = {instancePath:instancePath+"/binding",schemaPath:"#/properties/binding/anyOf/0/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
}
else {
const _errs11 = errors;
for(const key1 in data5){
if(!((((((key1 === "revision") || (key1 === "target")) || (key1 === "codec")) || (key1 === "active_limit")) || (key1 === "wait_before_ms")) || (key1 === "published"))){
const err1 = {instancePath:instancePath+"/binding",schemaPath:"#/properties/binding/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(_errs11 === errors){
if(data5.revision !== undefined){
const _errs12 = errors;
if(!(validate56(data5.revision, {instancePath:instancePath+"/binding/revision",parentData:data5,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid2 = _errs12 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data5.target !== undefined){
const _errs13 = errors;
if(!(validate56(data5.target, {instancePath:instancePath+"/binding/target",parentData:data5,parentDataProperty:"target",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid2 = _errs13 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data5.codec !== undefined){
const _errs14 = errors;
if(!(validate164(data5.codec, {instancePath:instancePath+"/binding/codec",parentData:data5,parentDataProperty:"codec",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate164.errors : vErrors.concat(validate164.errors);
errors = vErrors.length;
}
var valid2 = _errs14 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data5.active_limit !== undefined){
const _errs15 = errors;
if(!(validate65(data5.active_limit, {instancePath:instancePath+"/binding/active_limit",parentData:data5,parentDataProperty:"active_limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
errors = vErrors.length;
}
var valid2 = _errs15 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data5.wait_before_ms !== undefined){
const _errs16 = errors;
if(!(validate56(data5.wait_before_ms, {instancePath:instancePath+"/binding/wait_before_ms",parentData:data5,parentDataProperty:"wait_before_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid2 = _errs16 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data5.published !== undefined){
const _errs17 = errors;
if(typeof data5.published !== "boolean"){
const err2 = {instancePath:instancePath+"/binding/published",schemaPath:"#/properties/binding/anyOf/0/properties/published/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err2];
}
else {
vErrors.push(err2);
}
errors++;
}
var valid2 = _errs17 === errors;
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
const err3 = {instancePath:instancePath+"/binding",schemaPath:"#/properties/binding/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
}
var _valid0 = _errs9 === errors;
valid1 = valid1 || _valid0;
const _errs19 = errors;
if(data5 !== null){
const err4 = {instancePath:instancePath+"/binding",schemaPath:"#/properties/binding/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
}
var _valid0 = _errs19 === errors;
valid1 = valid1 || _valid0;
if(!valid1){
const err5 = {instancePath:instancePath+"/binding",schemaPath:"#/properties/binding/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err5];
}
else {
vErrors.push(err5);
}
errors++;
validate155.errors = vErrors;
return false;
}
else {
errors = _errs8;
if(vErrors !== null){
if(_errs8){
vErrors.length = _errs8;
}
else {
vErrors = null;
}
}
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.operation !== undefined){
let data12 = data.operation;
const _errs21 = errors;
const _errs22 = errors;
let valid3 = false;
const _errs23 = errors;
if(errors === _errs23){
if(data12 && typeof data12 == "object" && !Array.isArray(data12)){
let missing2;
if((((((((((data12.principal === undefined) && (missing2 = "principal")) || ((data12.operation === undefined) && (missing2 = "operation"))) || ((data12.binding === undefined) && (missing2 = "binding"))) || ((data12.codec === undefined) && (missing2 = "codec"))) || ((data12.deadline_ms === undefined) && (missing2 = "deadline_ms"))) || ((data12.digest === undefined) && (missing2 = "digest"))) || ((data12.target === undefined) && (missing2 = "target"))) || ((data12.correlation === undefined) && (missing2 = "correlation"))) || ((data12.policy_revision === undefined) && (missing2 = "policy_revision"))){
const err6 = {instancePath:instancePath+"/operation",schemaPath:"#/properties/operation/anyOf/0/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
if(vErrors === null){
vErrors = [err6];
}
else {
vErrors.push(err6);
}
errors++;
}
else {
const _errs25 = errors;
for(const key2 in data12){
if(!(func1.call(schema57.properties.operation.anyOf[0].properties, key2))){
const err7 = {instancePath:instancePath+"/operation",schemaPath:"#/properties/operation/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(_errs25 === errors){
if(data12.principal !== undefined){
const _errs26 = errors;
if(!(validate56(data12.principal, {instancePath:instancePath+"/operation/principal",parentData:data12,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid4 = _errs26 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data12.operation !== undefined){
const _errs27 = errors;
if(!(validate56(data12.operation, {instancePath:instancePath+"/operation/operation",parentData:data12,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid4 = _errs27 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data12.binding !== undefined){
const _errs28 = errors;
if(!(validate56(data12.binding, {instancePath:instancePath+"/operation/binding",parentData:data12,parentDataProperty:"binding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid4 = _errs28 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data12.codec !== undefined){
const _errs29 = errors;
if(!(validate164(data12.codec, {instancePath:instancePath+"/operation/codec",parentData:data12,parentDataProperty:"codec",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate164.errors : vErrors.concat(validate164.errors);
errors = vErrors.length;
}
var valid4 = _errs29 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data12.deadline_ms !== undefined){
const _errs30 = errors;
if(!(validate56(data12.deadline_ms, {instancePath:instancePath+"/operation/deadline_ms",parentData:data12,parentDataProperty:"deadline_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid4 = _errs30 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data12.digest !== undefined){
const _errs31 = errors;
if(!(validate64(data12.digest, {instancePath:instancePath+"/operation/digest",parentData:data12,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
errors = vErrors.length;
}
var valid4 = _errs31 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data12.target !== undefined){
const _errs32 = errors;
if(!(validate56(data12.target, {instancePath:instancePath+"/operation/target",parentData:data12,parentDataProperty:"target",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid4 = _errs32 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data12.correlation !== undefined){
const _errs33 = errors;
if(!(validate56(data12.correlation, {instancePath:instancePath+"/operation/correlation",parentData:data12,parentDataProperty:"correlation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid4 = _errs33 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data12.policy_revision !== undefined){
const _errs34 = errors;
if(!(validate56(data12.policy_revision, {instancePath:instancePath+"/operation/policy_revision",parentData:data12,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid4 = _errs34 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data12.phase !== undefined){
const _errs35 = errors;
if(!(validate177(data12.phase, {instancePath:instancePath+"/operation/phase",parentData:data12,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate177.errors : vErrors.concat(validate177.errors);
errors = vErrors.length;
}
var valid4 = _errs35 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data12.resolution_input !== undefined){
const _errs36 = errors;
if(!(validate56(data12.resolution_input, {instancePath:instancePath+"/operation/resolution_input",parentData:data12,parentDataProperty:"resolution_input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid4 = _errs36 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data12.result !== undefined){
const _errs37 = errors;
if(!(validate141(data12.result, {instancePath:instancePath+"/operation/result",parentData:data12,parentDataProperty:"result",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate141.errors : vErrors.concat(validate141.errors);
errors = vErrors.length;
}
var valid4 = _errs37 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data12.reply_bytes !== undefined){
const _errs38 = errors;
if(!(validate164(data12.reply_bytes, {instancePath:instancePath+"/operation/reply_bytes",parentData:data12,parentDataProperty:"reply_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate164.errors : vErrors.concat(validate164.errors);
errors = vErrors.length;
}
var valid4 = _errs38 === errors;
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
}
}
}
}
}
}
}
else {
const err8 = {instancePath:instancePath+"/operation",schemaPath:"#/properties/operation/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err8];
}
else {
vErrors.push(err8);
}
errors++;
}
}
var _valid1 = _errs23 === errors;
valid3 = valid3 || _valid1;
const _errs39 = errors;
if(data12 !== null){
const err9 = {instancePath:instancePath+"/operation",schemaPath:"#/properties/operation/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
}
var _valid1 = _errs39 === errors;
valid3 = valid3 || _valid1;
if(!valid3){
const err10 = {instancePath:instancePath+"/operation",schemaPath:"#/properties/operation/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
validate155.errors = vErrors;
return false;
}
else {
errors = _errs22;
if(vErrors !== null){
if(_errs22){
vErrors.length = _errs22;
}
else {
vErrors = null;
}
}
}
var valid0 = _errs21 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.diagnostic !== undefined){
let data26 = data.diagnostic;
const _errs41 = errors;
const _errs42 = errors;
let valid5 = false;
const _errs43 = errors;
if(!(validate72(data26, {instancePath:instancePath+"/diagnostic",parentData:data,parentDataProperty:"diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
errors = vErrors.length;
}
var _valid2 = _errs43 === errors;
valid5 = valid5 || _valid2;
const _errs44 = errors;
if(data26 !== null){
const err11 = {instancePath:instancePath+"/diagnostic",schemaPath:"#/properties/diagnostic/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err11];
}
else {
vErrors.push(err11);
}
errors++;
}
var _valid2 = _errs44 === errors;
valid5 = valid5 || _valid2;
if(!valid5){
const err12 = {instancePath:instancePath+"/diagnostic",schemaPath:"#/properties/diagnostic/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
validate155.errors = vErrors;
return false;
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
var valid0 = _errs41 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.disposition !== undefined){
let data27 = data.disposition;
const _errs46 = errors;
const _errs47 = errors;
let valid6 = false;
const _errs48 = errors;
if(errors === _errs48){
if(data27 && typeof data27 == "object" && !Array.isArray(data27)){
let missing3;
if(((data27.record === undefined) && (missing3 = "record")) || ((data27.diagnostic === undefined) && (missing3 = "diagnostic"))){
const err13 = {instancePath:instancePath+"/disposition",schemaPath:"#/properties/disposition/anyOf/0/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
if(vErrors === null){
vErrors = [err13];
}
else {
vErrors.push(err13);
}
errors++;
}
else {
const _errs50 = errors;
for(const key3 in data27){
if(!((key3 === "record") || (key3 === "diagnostic"))){
const err14 = {instancePath:instancePath+"/disposition",schemaPath:"#/properties/disposition/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(_errs50 === errors){
if(data27.record !== undefined){
const _errs51 = errors;
if(!(validate183(data27.record, {instancePath:instancePath+"/disposition/record",parentData:data27,parentDataProperty:"record",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate183.errors : vErrors.concat(validate183.errors);
errors = vErrors.length;
}
var valid7 = _errs51 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data27.diagnostic !== undefined){
let data29 = data27.diagnostic;
const _errs52 = errors;
const _errs53 = errors;
let valid8 = false;
const _errs54 = errors;
if(!(validate72(data29, {instancePath:instancePath+"/disposition/diagnostic",parentData:data27,parentDataProperty:"diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
errors = vErrors.length;
}
var _valid4 = _errs54 === errors;
valid8 = valid8 || _valid4;
const _errs55 = errors;
if(data29 !== null){
const err15 = {instancePath:instancePath+"/disposition/diagnostic",schemaPath:"#/properties/disposition/anyOf/0/properties/diagnostic/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
}
var _valid4 = _errs55 === errors;
valid8 = valid8 || _valid4;
if(!valid8){
const err16 = {instancePath:instancePath+"/disposition/diagnostic",schemaPath:"#/properties/disposition/anyOf/0/properties/diagnostic/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err16];
}
else {
vErrors.push(err16);
}
errors++;
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
var valid7 = _errs52 === errors;
}
else {
var valid7 = true;
}
}
}
}
}
else {
const err17 = {instancePath:instancePath+"/disposition",schemaPath:"#/properties/disposition/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err17];
}
else {
vErrors.push(err17);
}
errors++;
}
}
var _valid3 = _errs48 === errors;
valid6 = valid6 || _valid3;
const _errs57 = errors;
if(data27 !== null){
const err18 = {instancePath:instancePath+"/disposition",schemaPath:"#/properties/disposition/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
}
var _valid3 = _errs57 === errors;
valid6 = valid6 || _valid3;
if(!valid6){
const err19 = {instancePath:instancePath+"/disposition",schemaPath:"#/properties/disposition/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
validate155.errors = vErrors;
return false;
}
else {
errors = _errs47;
if(vErrors !== null){
if(_errs47){
vErrors.length = _errs47;
}
else {
vErrors = null;
}
}
}
var valid0 = _errs46 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.capabilities !== undefined){
let data30 = data.capabilities;
const _errs59 = errors;
if(errors === _errs59){
if(data30 && typeof data30 == "object" && !Array.isArray(data30)){
const _errs61 = errors;
for(const key4 in data30){
if(!(((((key4 === "http") || (key4 === "sse")) || (key4 === "websocket")) || (key4 === "grpc")) || (key4 === "flight"))){
validate155.errors = [{instancePath:instancePath+"/capabilities",schemaPath:"#/properties/capabilities/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs61 === errors){
if(data30.http !== undefined){
const _errs62 = errors;
if(typeof data30.http !== "boolean"){
validate155.errors = [{instancePath:instancePath+"/capabilities/http",schemaPath:"#/properties/capabilities/properties/http/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid9 = _errs62 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data30.sse !== undefined){
const _errs64 = errors;
if(typeof data30.sse !== "boolean"){
validate155.errors = [{instancePath:instancePath+"/capabilities/sse",schemaPath:"#/properties/capabilities/properties/sse/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid9 = _errs64 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data30.websocket !== undefined){
const _errs66 = errors;
if(typeof data30.websocket !== "boolean"){
validate155.errors = [{instancePath:instancePath+"/capabilities/websocket",schemaPath:"#/properties/capabilities/properties/websocket/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid9 = _errs66 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data30.grpc !== undefined){
const _errs68 = errors;
if(typeof data30.grpc !== "boolean"){
validate155.errors = [{instancePath:instancePath+"/capabilities/grpc",schemaPath:"#/properties/capabilities/properties/grpc/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid9 = _errs68 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data30.flight !== undefined){
const _errs70 = errors;
if(typeof data30.flight !== "boolean"){
validate155.errors = [{instancePath:instancePath+"/capabilities/flight",schemaPath:"#/properties/capabilities/properties/flight/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid9 = _errs70 === errors;
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
else {
validate155.errors = [{instancePath:instancePath+"/capabilities",schemaPath:"#/properties/capabilities/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
var valid0 = _errs59 === errors;
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
validate155.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate155.errors = vErrors;
return errors === 0;
}
validate155.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Receipt = validate195;
const schema64 = {"type":"object","additionalProperties":false,"properties":{"stage":{"$ref":"https://transit.invalid/generated-validator/34"},"receipt":{"$ref":"https://transit.invalid/generated-validator/40"}},"required":["receipt"]};
const schema65 = {"type":"object","additionalProperties":false,"properties":{"position":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["position"]};

function validate197(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate197.evaluated;
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
validate197.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "position")){
validate197.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.position !== undefined){
if(!(validate56(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate197.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate197.errors = vErrors;
return errors === 0;
}
validate197.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.receipt === undefined) && (missing0 = "receipt")){
validate195.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "stage") || (key0 === "receipt"))){
validate195.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.stage !== undefined){
const _errs2 = errors;
if(!(validate160(data.stage, {instancePath:instancePath+"/stage",parentData:data,parentDataProperty:"stage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate160.errors : vErrors.concat(validate160.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.receipt !== undefined){
const _errs3 = errors;
if(!(validate197(data.receipt, {instancePath:instancePath+"/receipt",parentData:data,parentDataProperty:"receipt",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate197.errors : vErrors.concat(validate197.errors);
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
validate195.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate195.errors = vErrors;
return errors === 0;
}
validate195.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const ReactiveRead = validate200;
const schema66 = {"type":"object","additionalProperties":false,"properties":{"read":{"$ref":"https://transit.invalid/generated-validator/48"},"proof":{"$ref":"SubjectProof"}},"required":["read","proof"]};
const schema67 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"https://transit.invalid/generated-validator/41"},"kind":{"$ref":"https://transit.invalid/generated-validator/42"},"attachment":{"$ref":"https://transit.invalid/generated-validator/1"},"nonce":{"$ref":"https://transit.invalid/generated-validator/43"},"cursor":{"$ref":"https://transit.invalid/generated-validator/47"}},"required":["scope","kind"]};
const schema68 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"principal":{"$ref":"https://transit.invalid/generated-validator/1"},"service":{"$ref":"https://transit.invalid/generated-validator/1"},"ingress":{"$ref":"https://transit.invalid/generated-validator/1"},"session":{"$ref":"https://transit.invalid/generated-validator/1"},"generation":{"$ref":"https://transit.invalid/generated-validator/1"},"subscription":{"$ref":"https://transit.invalid/generated-validator/1"},"subscription_generation":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["realm","principal","service","ingress","session","generation"]};

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
if(((((((data.realm === undefined) && (missing0 = "realm")) || ((data.principal === undefined) && (missing0 = "principal"))) || ((data.service === undefined) && (missing0 = "service"))) || ((data.ingress === undefined) && (missing0 = "ingress"))) || ((data.session === undefined) && (missing0 = "session"))) || ((data.generation === undefined) && (missing0 = "generation"))){
validate202.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "realm") || (key0 === "principal")) || (key0 === "service")) || (key0 === "ingress")) || (key0 === "session")) || (key0 === "generation")) || (key0 === "subscription")) || (key0 === "subscription_generation"))){
validate202.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
if(data.service !== undefined){
const _errs4 = errors;
if(!(validate56(data.service, {instancePath:instancePath+"/service",parentData:data,parentDataProperty:"service",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.ingress !== undefined){
const _errs5 = errors;
if(!(validate56(data.ingress, {instancePath:instancePath+"/ingress",parentData:data,parentDataProperty:"ingress",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.session !== undefined){
const _errs6 = errors;
if(!(validate56(data.session, {instancePath:instancePath+"/session",parentData:data,parentDataProperty:"session",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.generation !== undefined){
const _errs7 = errors;
if(!(validate56(data.generation, {instancePath:instancePath+"/generation",parentData:data,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.subscription !== undefined){
const _errs8 = errors;
if(!(validate56(data.subscription, {instancePath:instancePath+"/subscription",parentData:data,parentDataProperty:"subscription",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.subscription_generation !== undefined){
const _errs9 = errors;
if(!(validate56(data.subscription_generation, {instancePath:instancePath+"/subscription_generation",parentData:data,parentDataProperty:"subscription_generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
validate202.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate202.errors = vErrors;
return errors === 0;
}
validate202.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema69 = {"type":"string","enum":["session","snapshot","events"]};

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
if(typeof data !== "string"){
validate212.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((data === "session") || (data === "snapshot")) || (data === "events"))){
validate212.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema69.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate212.errors = vErrors;
return errors === 0;
}
validate212.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema70 = {"type":"array","minItems":16,"maxItems":16,"items":{"$ref":"https://transit.invalid/generated-validator/3"}};

function validate215(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate215.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 16){
validate215.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
if(data.length < 16){
validate215.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate65(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
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
validate215.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate215.errors = vErrors;
return errors === 0;
}
validate215.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema71 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/46"},{"type":"null"}]};
const schema72 = {"type":"object","additionalProperties":false,"properties":{"position":{"$ref":"https://transit.invalid/generated-validator/45"},"signature":{"$ref":"https://transit.invalid/generated-validator/6"}},"required":["position","signature"]};
const schema73 = {"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"scope":{"$ref":"https://transit.invalid/generated-validator/41"},"watch_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"schema":{"$ref":"https://transit.invalid/generated-validator/4"},"data_revision":{"$ref":"https://transit.invalid/generated-validator/44"},"outcome_position":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["scope","watch_revision","resource","schema","data_revision"]};
const schema74 = {"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20};

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
if(typeof data === "string"){
if(func2(data) > 20){
validate225.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern3.test(data)){
validate225.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate225.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate225.errors = vErrors;
return errors === 0;
}
validate225.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if((((((data.scope === undefined) && (missing0 = "scope")) || ((data.watch_revision === undefined) && (missing0 = "watch_revision"))) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.schema === undefined) && (missing0 = "schema"))) || ((data.data_revision === undefined) && (missing0 = "data_revision"))){
validate220.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "version") || (key0 === "scope")) || (key0 === "watch_revision")) || (key0 === "resource")) || (key0 === "schema")) || (key0 === "data_revision")) || (key0 === "outcome_position"))){
validate220.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate220.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"}];
return false;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.scope !== undefined){
const _errs3 = errors;
if(!(validate202(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate202.errors : vErrors.concat(validate202.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.watch_revision !== undefined){
const _errs4 = errors;
if(!(validate56(data.watch_revision, {instancePath:instancePath+"/watch_revision",parentData:data,parentDataProperty:"watch_revision",rootData,dynamicAnchors}))){
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
if(data.schema !== undefined){
const _errs6 = errors;
if(!(validate64(data.schema, {instancePath:instancePath+"/schema",parentData:data,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.data_revision !== undefined){
const _errs7 = errors;
if(!(validate225(data.data_revision, {instancePath:instancePath+"/data_revision",parentData:data,parentDataProperty:"data_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.outcome_position !== undefined){
const _errs8 = errors;
if(!(validate56(data.outcome_position, {instancePath:instancePath+"/outcome_position",parentData:data,parentDataProperty:"outcome_position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(((data.position === undefined) && (missing0 = "position")) || ((data.signature === undefined) && (missing0 = "signature"))){
validate219.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "position") || (key0 === "signature"))){
validate219.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.position !== undefined){
const _errs2 = errors;
if(!(validate220(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate220.errors : vErrors.concat(validate220.errors);
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
if(!(validate69(data.signature, {instancePath:instancePath+"/signature",parentData:data,parentDataProperty:"signature",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate69.errors : vErrors.concat(validate69.errors);
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
validate219.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate219.errors = vErrors;
return errors === 0;
}
validate219.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate218(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate218.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate219(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate219.errors : vErrors.concat(validate219.errors);
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
validate218.errors = vErrors;
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
validate218.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate218.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate201(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate201.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.scope === undefined) && (missing0 = "scope")) || ((data.kind === undefined) && (missing0 = "kind"))){
validate201.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "scope") || (key0 === "kind")) || (key0 === "attachment")) || (key0 === "nonce")) || (key0 === "cursor"))){
validate201.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate202(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate202.errors : vErrors.concat(validate202.errors);
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
if(!(validate212(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate212.errors : vErrors.concat(validate212.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.attachment !== undefined){
const _errs4 = errors;
if(!(validate56(data.attachment, {instancePath:instancePath+"/attachment",parentData:data,parentDataProperty:"attachment",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.nonce !== undefined){
const _errs5 = errors;
if(!(validate215(data.nonce, {instancePath:instancePath+"/nonce",parentData:data,parentDataProperty:"nonce",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate215.errors : vErrors.concat(validate215.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.cursor !== undefined){
const _errs6 = errors;
if(!(validate218(data.cursor, {instancePath:instancePath+"/cursor",parentData:data,parentDataProperty:"cursor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate218.errors : vErrors.concat(validate218.errors);
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
validate201.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate201.errors = vErrors;
return errors === 0;
}
validate201.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(((data.read === undefined) && (missing0 = "read")) || ((data.proof === undefined) && (missing0 = "proof"))){
validate200.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "read") || (key0 === "proof"))){
validate200.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.read !== undefined){
const _errs2 = errors;
if(!(validate201(data.read, {instancePath:instancePath+"/read",parentData:data,parentDataProperty:"read",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate201.errors : vErrors.concat(validate201.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.proof !== undefined){
const _errs3 = errors;
if(!(validate52(data.proof, {instancePath:instancePath+"/proof",parentData:data,parentDataProperty:"proof",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate52.errors : vErrors.concat(validate52.errors);
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
validate200.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate200.errors = vErrors;
return errors === 0;
}
validate200.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const ReactiveResponse = validate234;
const schema75 = {"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"session":{"$ref":"https://transit.invalid/generated-validator/50"},"source":{"$ref":"https://transit.invalid/generated-validator/52"},"snapshot":{"$ref":"https://transit.invalid/generated-validator/65"},"event":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"source_changed":{"type":"boolean"},"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"data_revision":{"$ref":"https://transit.invalid/generated-validator/44"},"outcome":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"operation":{"$ref":"https://transit.invalid/generated-validator/1"},"phase":{"$ref":"https://transit.invalid/generated-validator/36"},"resolution_input":{"$ref":"https://transit.invalid/generated-validator/1"},"diagnostic":{"anyOf":[{"$ref":"Diagnostic"},{"type":"null"}]}},"required":["resource","operation","phase","resolution_input"]},{"type":"null"}]}},"required":["source_changed","resource","data_revision"]},{"type":"null"}]},"cursor":{"$ref":"https://transit.invalid/generated-validator/47"}},"required":["session"]};
const schema76 = {"type":"object","additionalProperties":false,"properties":{"principal":{"$ref":"https://transit.invalid/generated-validator/1"},"session":{"$ref":"https://transit.invalid/generated-validator/1"},"generation":{"$ref":"https://transit.invalid/generated-validator/1"},"source_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"open_digest":{"$ref":"https://transit.invalid/generated-validator/4"},"lease_before_ms":{"$ref":"https://transit.invalid/generated-validator/1"},"phase":{"$ref":"https://transit.invalid/generated-validator/49"},"attachment":{"$ref":"https://transit.invalid/generated-validator/1"},"nonce":{"$ref":"https://transit.invalid/generated-validator/43"},"subscription":{"$ref":"https://transit.invalid/generated-validator/1"},"subscription_generation":{"$ref":"https://transit.invalid/generated-validator/1"},"operation":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["principal","session","generation","source_revision","open_digest","lease_before_ms"]};
const schema77 = {"type":"string","enum":["open","closed","expired"]};

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
if(typeof data !== "string"){
validate242.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((data === "open") || (data === "closed")) || (data === "expired"))){
validate242.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema77.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate242.errors = vErrors;
return errors === 0;
}
validate242.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate235(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate235.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((data.principal === undefined) && (missing0 = "principal")) || ((data.session === undefined) && (missing0 = "session"))) || ((data.generation === undefined) && (missing0 = "generation"))) || ((data.source_revision === undefined) && (missing0 = "source_revision"))) || ((data.open_digest === undefined) && (missing0 = "open_digest"))) || ((data.lease_before_ms === undefined) && (missing0 = "lease_before_ms"))){
validate235.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema76.properties, key0))){
validate235.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
if(data.session !== undefined){
const _errs3 = errors;
if(!(validate56(data.session, {instancePath:instancePath+"/session",parentData:data,parentDataProperty:"session",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate56(data.generation, {instancePath:instancePath+"/generation",parentData:data,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.source_revision !== undefined){
const _errs5 = errors;
if(!(validate56(data.source_revision, {instancePath:instancePath+"/source_revision",parentData:data,parentDataProperty:"source_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.open_digest !== undefined){
const _errs6 = errors;
if(!(validate64(data.open_digest, {instancePath:instancePath+"/open_digest",parentData:data,parentDataProperty:"open_digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.lease_before_ms !== undefined){
const _errs7 = errors;
if(!(validate56(data.lease_before_ms, {instancePath:instancePath+"/lease_before_ms",parentData:data,parentDataProperty:"lease_before_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.phase !== undefined){
const _errs8 = errors;
if(!(validate242(data.phase, {instancePath:instancePath+"/phase",parentData:data,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate242.errors : vErrors.concat(validate242.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.attachment !== undefined){
const _errs9 = errors;
if(!(validate56(data.attachment, {instancePath:instancePath+"/attachment",parentData:data,parentDataProperty:"attachment",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.nonce !== undefined){
const _errs10 = errors;
if(!(validate215(data.nonce, {instancePath:instancePath+"/nonce",parentData:data,parentDataProperty:"nonce",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate215.errors : vErrors.concat(validate215.errors);
errors = vErrors.length;
}
var valid0 = _errs10 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.subscription !== undefined){
const _errs11 = errors;
if(!(validate56(data.subscription, {instancePath:instancePath+"/subscription",parentData:data,parentDataProperty:"subscription",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs11 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.subscription_generation !== undefined){
const _errs12 = errors;
if(!(validate56(data.subscription_generation, {instancePath:instancePath+"/subscription_generation",parentData:data,parentDataProperty:"subscription_generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs12 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.operation !== undefined){
const _errs13 = errors;
if(!(validate56(data.operation, {instancePath:instancePath+"/operation",parentData:data,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
validate235.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate235.errors = vErrors;
return errors === 0;
}
validate235.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema78 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/51"},{"type":"null"}]};
const schema79 = {"type":"object","additionalProperties":false,"properties":{"revision":{"$ref":"https://transit.invalid/generated-validator/1"},"audience":{"$ref":"https://transit.invalid/generated-validator/1"},"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"catalog":{"$ref":"https://transit.invalid/generated-validator/44"},"branch":{"$ref":"https://transit.invalid/generated-validator/3"},"namespace":{"$ref":"https://transit.invalid/generated-validator/1"},"object":{"$ref":"https://transit.invalid/generated-validator/44"},"interpretation_revision":{"$ref":"https://transit.invalid/generated-validator/44"},"interpretation_digest":{"$ref":"https://transit.invalid/generated-validator/4"},"published":{"type":"boolean"}},"required":["revision","audience","resource","realm","catalog","branch","namespace","object","interpretation_revision","interpretation_digest"]};

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
if(((((((((((data.revision === undefined) && (missing0 = "revision")) || ((data.audience === undefined) && (missing0 = "audience"))) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.realm === undefined) && (missing0 = "realm"))) || ((data.catalog === undefined) && (missing0 = "catalog"))) || ((data.branch === undefined) && (missing0 = "branch"))) || ((data.namespace === undefined) && (missing0 = "namespace"))) || ((data.object === undefined) && (missing0 = "object"))) || ((data.interpretation_revision === undefined) && (missing0 = "interpretation_revision"))) || ((data.interpretation_digest === undefined) && (missing0 = "interpretation_digest"))){
validate251.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema79.properties, key0))){
validate251.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.revision !== undefined){
const _errs2 = errors;
if(!(validate56(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.audience !== undefined){
const _errs3 = errors;
if(!(validate56(data.audience, {instancePath:instancePath+"/audience",parentData:data,parentDataProperty:"audience",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.resource !== undefined){
const _errs4 = errors;
if(!(validate56(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(data.catalog !== undefined){
const _errs6 = errors;
if(!(validate225(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.branch !== undefined){
const _errs7 = errors;
if(!(validate65(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.namespace !== undefined){
const _errs8 = errors;
if(!(validate56(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.object !== undefined){
const _errs9 = errors;
if(!(validate225(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.interpretation_revision !== undefined){
const _errs10 = errors;
if(!(validate225(data.interpretation_revision, {instancePath:instancePath+"/interpretation_revision",parentData:data,parentDataProperty:"interpretation_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
errors = vErrors.length;
}
var valid0 = _errs10 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.interpretation_digest !== undefined){
const _errs11 = errors;
if(!(validate64(data.interpretation_digest, {instancePath:instancePath+"/interpretation_digest",parentData:data,parentDataProperty:"interpretation_digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
errors = vErrors.length;
}
var valid0 = _errs11 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.published !== undefined){
const _errs12 = errors;
if(typeof data.published !== "boolean"){
validate251.errors = [{instancePath:instancePath+"/published",schemaPath:"#/properties/published/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
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
validate251.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate251.errors = vErrors;
return errors === 0;
}
validate251.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate251(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate251.errors : vErrors.concat(validate251.errors);
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
validate250.errors = vErrors;
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
validate250.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate250.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema80 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/64"},{"type":"null"}]};
const schema81 = {"type":"object","additionalProperties":false,"properties":{"observation":{"$ref":"https://transit.invalid/generated-validator/58"},"rows":{"$ref":"https://transit.invalid/generated-validator/63"},"more":{"type":"boolean"}},"required":["observation"]};
const schema82 = {"type":"object","additionalProperties":false,"properties":{"data_revision":{"$ref":"https://transit.invalid/generated-validator/44"},"basis":{"$ref":"https://transit.invalid/generated-validator/53"},"schema":{"$ref":"https://transit.invalid/generated-validator/57"}},"required":["data_revision","basis","schema"]};
const schema83 = {"type":"object","additionalProperties":false,"properties":{"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"partition":{"$ref":"https://transit.invalid/generated-validator/44"},"accepted":{"$ref":"https://transit.invalid/generated-validator/44"},"contract":{"$ref":"https://transit.invalid/generated-validator/4"},"schema":{"$ref":"https://transit.invalid/generated-validator/4"}},"required":["resource","partition","accepted","contract","schema"]};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.resource === undefined) && (missing0 = "resource")) || ((data.partition === undefined) && (missing0 = "partition"))) || ((data.accepted === undefined) && (missing0 = "accepted"))) || ((data.contract === undefined) && (missing0 = "contract"))) || ((data.schema === undefined) && (missing0 = "schema"))){
validate268.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "resource") || (key0 === "partition")) || (key0 === "accepted")) || (key0 === "contract")) || (key0 === "schema"))){
validate268.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.resource !== undefined){
const _errs2 = errors;
if(!(validate56(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate225(data.partition, {instancePath:instancePath+"/partition",parentData:data,parentDataProperty:"partition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
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
if(!(validate225(data.accepted, {instancePath:instancePath+"/accepted",parentData:data,parentDataProperty:"accepted",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
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
if(!(validate64(data.contract, {instancePath:instancePath+"/contract",parentData:data,parentDataProperty:"contract",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
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
if(!(validate64(data.schema, {instancePath:instancePath+"/schema",parentData:data,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
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
validate268.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate268.errors = vErrors;
return errors === 0;
}
validate268.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema84 = {"type":"object","additionalProperties":false,"properties":{"names":{"$ref":"https://transit.invalid/generated-validator/56"},"value_type":{"type":"string","enum":["int64"]}},"required":["names"]};
const schema85 = {"type":"array","minItems":2,"maxItems":2,"items":{"$ref":"https://transit.invalid/generated-validator/55"}};
const schema86 = {"type":"object","additionalProperties":false,"properties":{"len":{"$ref":"https://transit.invalid/generated-validator/3"},"data":{"$ref":"https://transit.invalid/generated-validator/54"}},"required":["len"]};
const schema87 = {"type":"array","minItems":255,"maxItems":255,"items":{"$ref":"https://transit.invalid/generated-validator/3"}};

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
if(Array.isArray(data)){
if(data.length > 255){
validate279.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 255},message:"must NOT have more than 255 items"}];
return false;
}
else {
if(data.length < 255){
validate279.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 255},message:"must NOT have fewer than 255 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate65(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
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
validate279.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate279.errors = vErrors;
return errors === 0;
}
validate279.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.len === undefined) && (missing0 = "len")){
validate277.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "len") || (key0 === "data"))){
validate277.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.len !== undefined){
const _errs2 = errors;
if(!(validate65(data.len, {instancePath:instancePath+"/len",parentData:data,parentDataProperty:"len",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.data !== undefined){
const _errs3 = errors;
if(!(validate279(data.data, {instancePath:instancePath+"/data",parentData:data,parentDataProperty:"data",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate279.errors : vErrors.concat(validate279.errors);
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
validate277.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate277.errors = vErrors;
return errors === 0;
}
validate277.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 2){
validate276.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 2},message:"must NOT have more than 2 items"}];
return false;
}
else {
if(data.length < 2){
validate276.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 2},message:"must NOT have fewer than 2 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate277(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate277.errors : vErrors.concat(validate277.errors);
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
validate276.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate276.errors = vErrors;
return errors === 0;
}
validate276.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.names === undefined) && (missing0 = "names")){
validate275.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "names") || (key0 === "value_type"))){
validate275.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.names !== undefined){
const _errs2 = errors;
if(!(validate276(data.names, {instancePath:instancePath+"/names",parentData:data,parentDataProperty:"names",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate276.errors : vErrors.concat(validate276.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.value_type !== undefined){
let data1 = data.value_type;
const _errs3 = errors;
if(typeof data1 !== "string"){
validate275.errors = [{instancePath:instancePath+"/value_type",schemaPath:"#/properties/value_type/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(data1 === "int64")){
validate275.errors = [{instancePath:instancePath+"/value_type",schemaPath:"#/properties/value_type/enum",keyword:"enum",params:{allowedValues: schema84.properties.value_type.enum},message:"must be equal to one of the allowed values"}];
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
validate275.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate275.errors = vErrors;
return errors === 0;
}
validate275.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.data_revision === undefined) && (missing0 = "data_revision")) || ((data.basis === undefined) && (missing0 = "basis"))) || ((data.schema === undefined) && (missing0 = "schema"))){
validate266.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "data_revision") || (key0 === "basis")) || (key0 === "schema"))){
validate266.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.data_revision !== undefined){
const _errs2 = errors;
if(!(validate225(data.data_revision, {instancePath:instancePath+"/data_revision",parentData:data,parentDataProperty:"data_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.basis !== undefined){
const _errs3 = errors;
if(!(validate268(data.basis, {instancePath:instancePath+"/basis",parentData:data,parentDataProperty:"basis",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate268.errors : vErrors.concat(validate268.errors);
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
if(!(validate275(data.schema, {instancePath:instancePath+"/schema",parentData:data,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate275.errors : vErrors.concat(validate275.errors);
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
validate266.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate266.errors = vErrors;
return errors === 0;
}
validate266.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema88 = {"type":"array","minItems":8,"maxItems":8,"items":{"$ref":"https://transit.invalid/generated-validator/62"}};
const schema89 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/61"},{"type":"null"}]};
const schema90 = {"type":"object","additionalProperties":false,"properties":{"key":{"$ref":"https://transit.invalid/generated-validator/59"},"value":{"$ref":"https://transit.invalid/generated-validator/60"}},"required":["key","value"]};
const schema91 = {"type":"string","pattern":"^(0|-[1-9][0-9]*|[1-9][0-9]*)$","maxLength":20};
const pattern7 = new RegExp("^(0|-[1-9][0-9]*|[1-9][0-9]*)$", "u");

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
if(errors === 0){
if(typeof data === "string"){
if(func2(data) > 20){
validate289.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern7.test(data)){
validate289.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(0|-[1-9][0-9]*|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|-[1-9][0-9]*|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate289.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate289.errors = vErrors;
return errors === 0;
}
validate289.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema92 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/59"},{"type":"null"}]};

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
const _errs1 = errors;
if(!(validate289(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate289.errors : vErrors.concat(validate289.errors);
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
return errors === 0;
}
validate291.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(((data.key === undefined) && (missing0 = "key")) || ((data.value === undefined) && (missing0 = "value"))){
validate288.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "key") || (key0 === "value"))){
validate288.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.key !== undefined){
const _errs2 = errors;
if(!(validate289(data.key, {instancePath:instancePath+"/key",parentData:data,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate289.errors : vErrors.concat(validate289.errors);
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
if(!(validate291(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate291.errors : vErrors.concat(validate291.errors);
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
if(data.length > 8){
validate286.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
if(data.length < 8){
validate286.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 8},message:"must NOT have fewer than 8 items"}];
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
if((data.observation === undefined) && (missing0 = "observation")){
validate265.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "observation") || (key0 === "rows")) || (key0 === "more"))){
validate265.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.observation !== undefined){
const _errs2 = errors;
if(!(validate266(data.observation, {instancePath:instancePath+"/observation",parentData:data,parentDataProperty:"observation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate266.errors : vErrors.concat(validate266.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.rows !== undefined){
const _errs3 = errors;
if(!(validate286(data.rows, {instancePath:instancePath+"/rows",parentData:data,parentDataProperty:"rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate286.errors : vErrors.concat(validate286.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.more !== undefined){
const _errs4 = errors;
if(typeof data.more !== "boolean"){
validate265.errors = [{instancePath:instancePath+"/more",schemaPath:"#/properties/more/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate265(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate265.errors : vErrors.concat(validate265.errors);
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
validate264.errors = vErrors;
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
validate264.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate264.evaluated = {"dynamicProps":true,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.session === undefined) && (missing0 = "session")){
validate234.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "version") || (key0 === "session")) || (key0 === "source")) || (key0 === "snapshot")) || (key0 === "event")) || (key0 === "cursor"))){
validate234.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate234.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"}];
return false;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.session !== undefined){
const _errs3 = errors;
if(!(validate235(data.session, {instancePath:instancePath+"/session",parentData:data,parentDataProperty:"session",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate235.errors : vErrors.concat(validate235.errors);
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
if(!(validate250(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate250.errors : vErrors.concat(validate250.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.snapshot !== undefined){
const _errs5 = errors;
if(!(validate264(data.snapshot, {instancePath:instancePath+"/snapshot",parentData:data,parentDataProperty:"snapshot",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate264.errors : vErrors.concat(validate264.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.event !== undefined){
let data4 = data.event;
const _errs6 = errors;
const _errs7 = errors;
let valid1 = false;
const _errs8 = errors;
if(errors === _errs8){
if(data4 && typeof data4 == "object" && !Array.isArray(data4)){
let missing1;
if((((data4.source_changed === undefined) && (missing1 = "source_changed")) || ((data4.resource === undefined) && (missing1 = "resource"))) || ((data4.data_revision === undefined) && (missing1 = "data_revision"))){
const err0 = {instancePath:instancePath+"/event",schemaPath:"#/properties/event/anyOf/0/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
for(const key1 in data4){
if(!((((key1 === "source_changed") || (key1 === "resource")) || (key1 === "data_revision")) || (key1 === "outcome"))){
const err1 = {instancePath:instancePath+"/event",schemaPath:"#/properties/event/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(data4.source_changed !== undefined){
const _errs11 = errors;
if(typeof data4.source_changed !== "boolean"){
const err2 = {instancePath:instancePath+"/event/source_changed",schemaPath:"#/properties/event/anyOf/0/properties/source_changed/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err2];
}
else {
vErrors.push(err2);
}
errors++;
}
var valid2 = _errs11 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data4.resource !== undefined){
const _errs13 = errors;
if(!(validate56(data4.resource, {instancePath:instancePath+"/event/resource",parentData:data4,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid2 = _errs13 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data4.data_revision !== undefined){
const _errs14 = errors;
if(!(validate225(data4.data_revision, {instancePath:instancePath+"/event/data_revision",parentData:data4,parentDataProperty:"data_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
errors = vErrors.length;
}
var valid2 = _errs14 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data4.outcome !== undefined){
let data8 = data4.outcome;
const _errs15 = errors;
const _errs16 = errors;
let valid3 = false;
const _errs17 = errors;
if(errors === _errs17){
if(data8 && typeof data8 == "object" && !Array.isArray(data8)){
let missing2;
if(((((data8.resource === undefined) && (missing2 = "resource")) || ((data8.operation === undefined) && (missing2 = "operation"))) || ((data8.phase === undefined) && (missing2 = "phase"))) || ((data8.resolution_input === undefined) && (missing2 = "resolution_input"))){
const err3 = {instancePath:instancePath+"/event/outcome",schemaPath:"#/properties/event/anyOf/0/properties/outcome/anyOf/0/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
else {
const _errs19 = errors;
for(const key2 in data8){
if(!(((((key2 === "resource") || (key2 === "operation")) || (key2 === "phase")) || (key2 === "resolution_input")) || (key2 === "diagnostic"))){
const err4 = {instancePath:instancePath+"/event/outcome",schemaPath:"#/properties/event/anyOf/0/properties/outcome/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(_errs19 === errors){
if(data8.resource !== undefined){
const _errs20 = errors;
if(!(validate56(data8.resource, {instancePath:instancePath+"/event/outcome/resource",parentData:data8,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid4 = _errs20 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data8.operation !== undefined){
const _errs21 = errors;
if(!(validate56(data8.operation, {instancePath:instancePath+"/event/outcome/operation",parentData:data8,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid4 = _errs21 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data8.phase !== undefined){
const _errs22 = errors;
if(!(validate177(data8.phase, {instancePath:instancePath+"/event/outcome/phase",parentData:data8,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate177.errors : vErrors.concat(validate177.errors);
errors = vErrors.length;
}
var valid4 = _errs22 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data8.resolution_input !== undefined){
const _errs23 = errors;
if(!(validate56(data8.resolution_input, {instancePath:instancePath+"/event/outcome/resolution_input",parentData:data8,parentDataProperty:"resolution_input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid4 = _errs23 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data8.diagnostic !== undefined){
let data13 = data8.diagnostic;
const _errs24 = errors;
const _errs25 = errors;
let valid5 = false;
const _errs26 = errors;
if(!(validate72(data13, {instancePath:instancePath+"/event/outcome/diagnostic",parentData:data8,parentDataProperty:"diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
errors = vErrors.length;
}
var _valid2 = _errs26 === errors;
valid5 = valid5 || _valid2;
const _errs27 = errors;
if(data13 !== null){
const err5 = {instancePath:instancePath+"/event/outcome/diagnostic",schemaPath:"#/properties/event/anyOf/0/properties/outcome/anyOf/0/properties/diagnostic/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err5];
}
else {
vErrors.push(err5);
}
errors++;
}
var _valid2 = _errs27 === errors;
valid5 = valid5 || _valid2;
if(!valid5){
const err6 = {instancePath:instancePath+"/event/outcome/diagnostic",schemaPath:"#/properties/event/anyOf/0/properties/outcome/anyOf/0/properties/diagnostic/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err6];
}
else {
vErrors.push(err6);
}
errors++;
}
else {
errors = _errs25;
if(vErrors !== null){
if(_errs25){
vErrors.length = _errs25;
}
else {
vErrors = null;
}
}
}
var valid4 = _errs24 === errors;
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
else {
const err7 = {instancePath:instancePath+"/event/outcome",schemaPath:"#/properties/event/anyOf/0/properties/outcome/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err7];
}
else {
vErrors.push(err7);
}
errors++;
}
}
var _valid1 = _errs17 === errors;
valid3 = valid3 || _valid1;
const _errs29 = errors;
if(data8 !== null){
const err8 = {instancePath:instancePath+"/event/outcome",schemaPath:"#/properties/event/anyOf/0/properties/outcome/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err8];
}
else {
vErrors.push(err8);
}
errors++;
}
var _valid1 = _errs29 === errors;
valid3 = valid3 || _valid1;
if(!valid3){
const err9 = {instancePath:instancePath+"/event/outcome",schemaPath:"#/properties/event/anyOf/0/properties/outcome/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
}
else {
errors = _errs16;
if(vErrors !== null){
if(_errs16){
vErrors.length = _errs16;
}
else {
vErrors = null;
}
}
}
var valid2 = _errs15 === errors;
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
else {
const err10 = {instancePath:instancePath+"/event",schemaPath:"#/properties/event/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
}
}
var _valid0 = _errs8 === errors;
valid1 = valid1 || _valid0;
const _errs31 = errors;
if(data4 !== null){
const err11 = {instancePath:instancePath+"/event",schemaPath:"#/properties/event/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err11];
}
else {
vErrors.push(err11);
}
errors++;
}
var _valid0 = _errs31 === errors;
valid1 = valid1 || _valid0;
if(!valid1){
const err12 = {instancePath:instancePath+"/event",schemaPath:"#/properties/event/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
validate234.errors = vErrors;
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
if(valid0){
if(data.cursor !== undefined){
const _errs33 = errors;
if(!(validate218(data.cursor, {instancePath:instancePath+"/cursor",parentData:data,parentDataProperty:"cursor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate218.errors : vErrors.concat(validate218.errors);
errors = vErrors.length;
}
var valid0 = _errs33 === errors;
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
validate234.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate234.errors = vErrors;
return errors === 0;
}
validate234.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Bootstrap = validate307;
const schema93 = {"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"attach":{"$ref":"https://transit.invalid/generated-validator/66"},"read":{"type":"object","additionalProperties":false,"properties":{"read":{"$ref":"https://transit.invalid/generated-validator/48"},"proof":{"$ref":"SubjectProof"}},"required":["read","proof"]}},"required":["attach","read"]};
const schema94 = {"type":"object","additionalProperties":false,"properties":{"request":{"$ref":"https://transit.invalid/generated-validator/33"},"signature":{"$ref":"https://transit.invalid/generated-validator/6"}},"required":["request","signature"]};

function validate308(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate308.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.request === undefined) && (missing0 = "request")) || ((data.signature === undefined) && (missing0 = "signature"))){
validate308.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "request") || (key0 === "signature"))){
validate308.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.request !== undefined){
const _errs2 = errors;
if(!(validate133(data.request, {instancePath:instancePath+"/request",parentData:data,parentDataProperty:"request",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate133.errors : vErrors.concat(validate133.errors);
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
if(!(validate69(data.signature, {instancePath:instancePath+"/signature",parentData:data,parentDataProperty:"signature",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate69.errors : vErrors.concat(validate69.errors);
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
validate308.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate308.errors = vErrors;
return errors === 0;
}
validate308.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(((data.attach === undefined) && (missing0 = "attach")) || ((data.read === undefined) && (missing0 = "read"))){
validate307.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "version") || (key0 === "attach")) || (key0 === "read"))){
validate307.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate307.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"}];
return false;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.attach !== undefined){
const _errs3 = errors;
if(!(validate308(data.attach, {instancePath:instancePath+"/attach",parentData:data,parentDataProperty:"attach",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate308.errors : vErrors.concat(validate308.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.read !== undefined){
let data2 = data.read;
const _errs4 = errors;
if(errors === _errs4){
if(data2 && typeof data2 == "object" && !Array.isArray(data2)){
let missing1;
if(((data2.read === undefined) && (missing1 = "read")) || ((data2.proof === undefined) && (missing1 = "proof"))){
validate307.errors = [{instancePath:instancePath+"/read",schemaPath:"#/properties/read/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"}];
return false;
}
else {
const _errs6 = errors;
for(const key1 in data2){
if(!((key1 === "read") || (key1 === "proof"))){
validate307.errors = [{instancePath:instancePath+"/read",schemaPath:"#/properties/read/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs6 === errors){
if(data2.read !== undefined){
const _errs7 = errors;
if(!(validate201(data2.read, {instancePath:instancePath+"/read/read",parentData:data2,parentDataProperty:"read",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate201.errors : vErrors.concat(validate201.errors);
errors = vErrors.length;
}
var valid1 = _errs7 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data2.proof !== undefined){
const _errs8 = errors;
if(!(validate52(data2.proof, {instancePath:instancePath+"/read/proof",parentData:data2,parentDataProperty:"proof",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate52.errors : vErrors.concat(validate52.errors);
errors = vErrors.length;
}
var valid1 = _errs8 === errors;
}
else {
var valid1 = true;
}
}
}
}
}
else {
validate307.errors = [{instancePath:instancePath+"/read",schemaPath:"#/properties/read/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
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
validate307.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate307.errors = vErrors;
return errors === 0;
}
validate307.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const ClientMessage = validate314;
const schema95 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["attach"],"properties":{"attach":{"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"attach":{"$ref":"https://transit.invalid/generated-validator/66"},"read":{"type":"object","additionalProperties":false,"properties":{"read":{"$ref":"https://transit.invalid/generated-validator/48"},"proof":{"$ref":"SubjectProof"}},"required":["read","proof"]}},"required":["attach","read"]}}},{"type":"object","additionalProperties":false,"required":["command"],"properties":{"command":{"$ref":"https://transit.invalid/generated-validator/66"}}},{"type":"object","additionalProperties":false,"required":["control"],"properties":{"control":{"$ref":"https://transit.invalid/generated-validator/66"}}},{"type":"object","additionalProperties":false,"required":["read"],"properties":{"read":{"type":"object","additionalProperties":false,"properties":{"read":{"$ref":"https://transit.invalid/generated-validator/48"},"proof":{"$ref":"SubjectProof"}},"required":["read","proof"]}}}]};

function validate314(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate314.evaluated;
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
if((data.attach === undefined) && (missing0 = "attach")){
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
if(!(key0 === "attach")){
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
if(data.attach !== undefined){
let data0 = data.attach;
const _errs4 = errors;
if(errors === _errs4){
if(data0 && typeof data0 == "object" && !Array.isArray(data0)){
let missing1;
if(((data0.attach === undefined) && (missing1 = "attach")) || ((data0.read === undefined) && (missing1 = "read"))){
const err2 = {instancePath:instancePath+"/attach",schemaPath:"#/oneOf/0/properties/attach/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
if(!(((key1 === "version") || (key1 === "attach")) || (key1 === "read"))){
const err3 = {instancePath:instancePath+"/attach",schemaPath:"#/oneOf/0/properties/attach/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(data0.version !== undefined){
const _errs7 = errors;
if(1 !== data0.version){
const err4 = {instancePath:instancePath+"/attach/version",schemaPath:"#/oneOf/0/properties/attach/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
}
var valid2 = _errs7 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data0.attach !== undefined){
const _errs8 = errors;
if(!(validate308(data0.attach, {instancePath:instancePath+"/attach/attach",parentData:data0,parentDataProperty:"attach",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate308.errors : vErrors.concat(validate308.errors);
errors = vErrors.length;
}
var valid2 = _errs8 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data0.read !== undefined){
let data3 = data0.read;
const _errs9 = errors;
if(errors === _errs9){
if(data3 && typeof data3 == "object" && !Array.isArray(data3)){
let missing2;
if(((data3.read === undefined) && (missing2 = "read")) || ((data3.proof === undefined) && (missing2 = "proof"))){
const err5 = {instancePath:instancePath+"/attach/read",schemaPath:"#/oneOf/0/properties/attach/properties/read/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
if(vErrors === null){
vErrors = [err5];
}
else {
vErrors.push(err5);
}
errors++;
}
else {
const _errs11 = errors;
for(const key2 in data3){
if(!((key2 === "read") || (key2 === "proof"))){
const err6 = {instancePath:instancePath+"/attach/read",schemaPath:"#/oneOf/0/properties/attach/properties/read/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(_errs11 === errors){
if(data3.read !== undefined){
const _errs12 = errors;
if(!(validate201(data3.read, {instancePath:instancePath+"/attach/read/read",parentData:data3,parentDataProperty:"read",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate201.errors : vErrors.concat(validate201.errors);
errors = vErrors.length;
}
var valid3 = _errs12 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data3.proof !== undefined){
const _errs13 = errors;
if(!(validate52(data3.proof, {instancePath:instancePath+"/attach/read/proof",parentData:data3,parentDataProperty:"proof",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate52.errors : vErrors.concat(validate52.errors);
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
const err7 = {instancePath:instancePath+"/attach/read",schemaPath:"#/oneOf/0/properties/attach/properties/read/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err7];
}
else {
vErrors.push(err7);
}
errors++;
}
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
const err8 = {instancePath:instancePath+"/attach",schemaPath:"#/oneOf/0/properties/attach/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err9 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
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
const _errs14 = errors;
if(errors === _errs14){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing3;
if((data.command === undefined) && (missing3 = "command")){
const err10 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
}
else {
const _errs16 = errors;
for(const key3 in data){
if(!(key3 === "command")){
const err11 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(_errs16 === errors){
if(data.command !== undefined){
if(!(validate308(data.command, {instancePath:instancePath+"/command",parentData:data,parentDataProperty:"command",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate308.errors : vErrors.concat(validate308.errors);
errors = vErrors.length;
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
var _valid0 = _errs14 === errors;
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
const _errs18 = errors;
if(errors === _errs18){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing4;
if((data.control === undefined) && (missing4 = "control")){
const err13 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
if(vErrors === null){
vErrors = [err13];
}
else {
vErrors.push(err13);
}
errors++;
}
else {
const _errs20 = errors;
for(const key4 in data){
if(!(key4 === "control")){
const err14 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(_errs20 === errors){
if(data.control !== undefined){
if(!(validate308(data.control, {instancePath:instancePath+"/control",parentData:data,parentDataProperty:"control",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate308.errors : vErrors.concat(validate308.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err15 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
}
}
var _valid0 = _errs18 === errors;
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
const _errs22 = errors;
if(errors === _errs22){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing5;
if((data.read === undefined) && (missing5 = "read")){
const err16 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
if(vErrors === null){
vErrors = [err16];
}
else {
vErrors.push(err16);
}
errors++;
}
else {
const _errs24 = errors;
for(const key5 in data){
if(!(key5 === "read")){
const err17 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err17];
}
else {
vErrors.push(err17);
}
errors++;
break;
}
}
if(_errs24 === errors){
if(data.read !== undefined){
let data8 = data.read;
const _errs25 = errors;
if(errors === _errs25){
if(data8 && typeof data8 == "object" && !Array.isArray(data8)){
let missing6;
if(((data8.read === undefined) && (missing6 = "read")) || ((data8.proof === undefined) && (missing6 = "proof"))){
const err18 = {instancePath:instancePath+"/read",schemaPath:"#/oneOf/3/properties/read/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
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
for(const key6 in data8){
if(!((key6 === "read") || (key6 === "proof"))){
const err19 = {instancePath:instancePath+"/read",schemaPath:"#/oneOf/3/properties/read/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
if(data8.read !== undefined){
const _errs28 = errors;
if(!(validate201(data8.read, {instancePath:instancePath+"/read/read",parentData:data8,parentDataProperty:"read",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate201.errors : vErrors.concat(validate201.errors);
errors = vErrors.length;
}
var valid7 = _errs28 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data8.proof !== undefined){
const _errs29 = errors;
if(!(validate52(data8.proof, {instancePath:instancePath+"/read/proof",parentData:data8,parentDataProperty:"proof",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate52.errors : vErrors.concat(validate52.errors);
errors = vErrors.length;
}
var valid7 = _errs29 === errors;
}
else {
var valid7 = true;
}
}
}
}
}
else {
const err20 = {instancePath:instancePath+"/read",schemaPath:"#/oneOf/3/properties/read/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err21 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
}
errors++;
}
}
var _valid0 = _errs22 === errors;
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
const err22 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err22];
}
else {
vErrors.push(err22);
}
errors++;
validate314.errors = vErrors;
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
validate314.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate314.evaluated = {"dynamicProps":true,"dynamicItems":false};

export const ServerMessage = validate322;
const schema96 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["challenge"],"properties":{"challenge":{"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"nonce":{"$ref":"https://transit.invalid/generated-validator/43"},"valid_for_ms":{"$ref":"https://transit.invalid/generated-validator/67"}},"required":["nonce"]}}},{"type":"object","additionalProperties":false,"required":["attached"],"properties":{"attached":{"type":"object","additionalProperties":false,"properties":{"session":{"$ref":"https://transit.invalid/generated-validator/1"},"generation":{"$ref":"https://transit.invalid/generated-validator/1"},"attachment":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["session","generation","attachment"]}}},{"$ref":"https://transit.invalid/generated-validator/69"},{"type":"object","additionalProperties":false,"required":["observation"],"properties":{"observation":{"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"session":{"$ref":"https://transit.invalid/generated-validator/50"},"source":{"$ref":"https://transit.invalid/generated-validator/52"},"snapshot":{"$ref":"https://transit.invalid/generated-validator/65"},"event":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"source_changed":{"type":"boolean"},"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"data_revision":{"$ref":"https://transit.invalid/generated-validator/44"},"outcome":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"operation":{"$ref":"https://transit.invalid/generated-validator/1"},"phase":{"$ref":"https://transit.invalid/generated-validator/36"},"resolution_input":{"$ref":"https://transit.invalid/generated-validator/1"},"diagnostic":{"anyOf":[{"$ref":"Diagnostic"},{"type":"null"}]}},"required":["resource","operation","phase","resolution_input"]},{"type":"null"}]}},"required":["source_changed","resource","data_revision"]},{"type":"null"}]},"cursor":{"$ref":"https://transit.invalid/generated-validator/47"}},"required":["session"]}}},{"type":"object","additionalProperties":false,"required":["event"],"properties":{"event":{"type":"object","additionalProperties":false,"properties":{"cursor":{"$ref":"https://transit.invalid/generated-validator/46"},"event":{"type":"object","additionalProperties":false,"properties":{"source_changed":{"type":"boolean"},"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"data_revision":{"$ref":"https://transit.invalid/generated-validator/44"},"outcome":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"operation":{"$ref":"https://transit.invalid/generated-validator/1"},"phase":{"$ref":"https://transit.invalid/generated-validator/36"},"resolution_input":{"$ref":"https://transit.invalid/generated-validator/1"},"diagnostic":{"anyOf":[{"$ref":"Diagnostic"},{"type":"null"}]}},"required":["resource","operation","phase","resolution_input"]},{"type":"null"}]}},"required":["source_changed","resource","data_revision"]}},"required":["cursor","event"]}}},{"type":"object","additionalProperties":false,"required":["heartbeat"],"properties":{"heartbeat":{"type":"object","additionalProperties":false,"properties":{"version":{"const":1}},"required":[]}}},{"type":"object","additionalProperties":false,"required":["terminal"],"properties":{"terminal":{"type":"object","additionalProperties":false,"properties":{"reason":{"type":"string","enum":["denied","closed","expired","fenced","reset_required","interrupted","invalid_message","capacity"]},"diagnostic":{"anyOf":[{"$ref":"Diagnostic"},{"type":"null"}]}},"required":["reason"]}}}]};
const schema97 = {"type":"integer","minimum":0,"maximum":4294967295};

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
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate324.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 4294967295 || isNaN(data)){
validate324.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate324.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate324.errors = vErrors;
return errors === 0;
}
validate324.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema98 = {"type":"object","additionalProperties":false,"required":["receipt"],"properties":{"receipt":{"$ref":"https://transit.invalid/generated-validator/68"}}};
const schema99 = {"type":"object","additionalProperties":false,"properties":{"stage":{"$ref":"https://transit.invalid/generated-validator/34"},"receipt":{"$ref":"https://transit.invalid/generated-validator/40"}},"required":["receipt"]};

function validate330(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate330.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.receipt === undefined) && (missing0 = "receipt")){
validate330.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "stage") || (key0 === "receipt"))){
validate330.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.stage !== undefined){
const _errs2 = errors;
if(!(validate160(data.stage, {instancePath:instancePath+"/stage",parentData:data,parentDataProperty:"stage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate160.errors : vErrors.concat(validate160.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.receipt !== undefined){
const _errs3 = errors;
if(!(validate197(data.receipt, {instancePath:instancePath+"/receipt",parentData:data,parentDataProperty:"receipt",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate197.errors : vErrors.concat(validate197.errors);
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
validate330.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate330.errors = vErrors;
return errors === 0;
}
validate330.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.receipt === undefined) && (missing0 = "receipt")){
validate329.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "receipt")){
validate329.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.receipt !== undefined){
if(!(validate330(data.receipt, {instancePath:instancePath+"/receipt",parentData:data,parentDataProperty:"receipt",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate330.errors : vErrors.concat(validate330.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate329.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate329.errors = vErrors;
return errors === 0;
}
validate329.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate322(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate322.evaluated;
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
if((data.challenge === undefined) && (missing0 = "challenge")){
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
if(!(key0 === "challenge")){
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
if(data.challenge !== undefined){
let data0 = data.challenge;
const _errs4 = errors;
if(errors === _errs4){
if(data0 && typeof data0 == "object" && !Array.isArray(data0)){
let missing1;
if((data0.nonce === undefined) && (missing1 = "nonce")){
const err2 = {instancePath:instancePath+"/challenge",schemaPath:"#/oneOf/0/properties/challenge/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
if(!(((key1 === "version") || (key1 === "nonce")) || (key1 === "valid_for_ms"))){
const err3 = {instancePath:instancePath+"/challenge",schemaPath:"#/oneOf/0/properties/challenge/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(data0.version !== undefined){
const _errs7 = errors;
if(1 !== data0.version){
const err4 = {instancePath:instancePath+"/challenge/version",schemaPath:"#/oneOf/0/properties/challenge/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
}
var valid2 = _errs7 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data0.nonce !== undefined){
const _errs8 = errors;
if(!(validate215(data0.nonce, {instancePath:instancePath+"/challenge/nonce",parentData:data0,parentDataProperty:"nonce",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate215.errors : vErrors.concat(validate215.errors);
errors = vErrors.length;
}
var valid2 = _errs8 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data0.valid_for_ms !== undefined){
const _errs9 = errors;
if(!(validate324(data0.valid_for_ms, {instancePath:instancePath+"/challenge/valid_for_ms",parentData:data0,parentDataProperty:"valid_for_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate324.errors : vErrors.concat(validate324.errors);
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
const err5 = {instancePath:instancePath+"/challenge",schemaPath:"#/oneOf/0/properties/challenge/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err5];
}
else {
vErrors.push(err5);
}
errors++;
}
}
}
}
}
}
else {
const err6 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err6];
}
else {
vErrors.push(err6);
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
if((data.attached === undefined) && (missing2 = "attached")){
const err7 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
if(vErrors === null){
vErrors = [err7];
}
else {
vErrors.push(err7);
}
errors++;
}
else {
const _errs12 = errors;
for(const key2 in data){
if(!(key2 === "attached")){
const err8 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(_errs12 === errors){
if(data.attached !== undefined){
let data4 = data.attached;
const _errs13 = errors;
if(errors === _errs13){
if(data4 && typeof data4 == "object" && !Array.isArray(data4)){
let missing3;
if((((data4.session === undefined) && (missing3 = "session")) || ((data4.generation === undefined) && (missing3 = "generation"))) || ((data4.attachment === undefined) && (missing3 = "attachment"))){
const err9 = {instancePath:instancePath+"/attached",schemaPath:"#/oneOf/1/properties/attached/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
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
for(const key3 in data4){
if(!(((key3 === "session") || (key3 === "generation")) || (key3 === "attachment"))){
const err10 = {instancePath:instancePath+"/attached",schemaPath:"#/oneOf/1/properties/attached/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(data4.session !== undefined){
const _errs16 = errors;
if(!(validate56(data4.session, {instancePath:instancePath+"/attached/session",parentData:data4,parentDataProperty:"session",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid4 = _errs16 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data4.generation !== undefined){
const _errs17 = errors;
if(!(validate56(data4.generation, {instancePath:instancePath+"/attached/generation",parentData:data4,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid4 = _errs17 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data4.attachment !== undefined){
const _errs18 = errors;
if(!(validate56(data4.attachment, {instancePath:instancePath+"/attached/attachment",parentData:data4,parentDataProperty:"attachment",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid4 = _errs18 === errors;
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
const err11 = {instancePath:instancePath+"/attached",schemaPath:"#/oneOf/1/properties/attached/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const _errs19 = errors;
if(!(validate329(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate329.errors : vErrors.concat(validate329.errors);
errors = vErrors.length;
}
var _valid0 = _errs19 === errors;
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
const _errs20 = errors;
if(errors === _errs20){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing4;
if((data.observation === undefined) && (missing4 = "observation")){
const err13 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
if(vErrors === null){
vErrors = [err13];
}
else {
vErrors.push(err13);
}
errors++;
}
else {
const _errs22 = errors;
for(const key4 in data){
if(!(key4 === "observation")){
const err14 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(_errs22 === errors){
if(data.observation !== undefined){
let data8 = data.observation;
const _errs23 = errors;
if(errors === _errs23){
if(data8 && typeof data8 == "object" && !Array.isArray(data8)){
let missing5;
if((data8.session === undefined) && (missing5 = "session")){
const err15 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/3/properties/observation/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
}
else {
const _errs25 = errors;
for(const key5 in data8){
if(!((((((key5 === "version") || (key5 === "session")) || (key5 === "source")) || (key5 === "snapshot")) || (key5 === "event")) || (key5 === "cursor"))){
const err16 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/3/properties/observation/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(_errs25 === errors){
if(data8.version !== undefined){
const _errs26 = errors;
if(1 !== data8.version){
const err17 = {instancePath:instancePath+"/observation/version",schemaPath:"#/oneOf/3/properties/observation/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"};
if(vErrors === null){
vErrors = [err17];
}
else {
vErrors.push(err17);
}
errors++;
}
var valid6 = _errs26 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data8.session !== undefined){
const _errs27 = errors;
if(!(validate235(data8.session, {instancePath:instancePath+"/observation/session",parentData:data8,parentDataProperty:"session",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate235.errors : vErrors.concat(validate235.errors);
errors = vErrors.length;
}
var valid6 = _errs27 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data8.source !== undefined){
const _errs28 = errors;
if(!(validate250(data8.source, {instancePath:instancePath+"/observation/source",parentData:data8,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate250.errors : vErrors.concat(validate250.errors);
errors = vErrors.length;
}
var valid6 = _errs28 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data8.snapshot !== undefined){
const _errs29 = errors;
if(!(validate264(data8.snapshot, {instancePath:instancePath+"/observation/snapshot",parentData:data8,parentDataProperty:"snapshot",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate264.errors : vErrors.concat(validate264.errors);
errors = vErrors.length;
}
var valid6 = _errs29 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data8.event !== undefined){
let data13 = data8.event;
const _errs30 = errors;
const _errs31 = errors;
let valid7 = false;
const _errs32 = errors;
if(errors === _errs32){
if(data13 && typeof data13 == "object" && !Array.isArray(data13)){
let missing6;
if((((data13.source_changed === undefined) && (missing6 = "source_changed")) || ((data13.resource === undefined) && (missing6 = "resource"))) || ((data13.data_revision === undefined) && (missing6 = "data_revision"))){
const err18 = {instancePath:instancePath+"/observation/event",schemaPath:"#/oneOf/3/properties/observation/properties/event/anyOf/0/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
}
else {
const _errs34 = errors;
for(const key6 in data13){
if(!((((key6 === "source_changed") || (key6 === "resource")) || (key6 === "data_revision")) || (key6 === "outcome"))){
const err19 = {instancePath:instancePath+"/observation/event",schemaPath:"#/oneOf/3/properties/observation/properties/event/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
if(_errs34 === errors){
if(data13.source_changed !== undefined){
const _errs35 = errors;
if(typeof data13.source_changed !== "boolean"){
const err20 = {instancePath:instancePath+"/observation/event/source_changed",schemaPath:"#/oneOf/3/properties/observation/properties/event/anyOf/0/properties/source_changed/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err20];
}
else {
vErrors.push(err20);
}
errors++;
}
var valid8 = _errs35 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data13.resource !== undefined){
const _errs37 = errors;
if(!(validate56(data13.resource, {instancePath:instancePath+"/observation/event/resource",parentData:data13,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid8 = _errs37 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data13.data_revision !== undefined){
const _errs38 = errors;
if(!(validate225(data13.data_revision, {instancePath:instancePath+"/observation/event/data_revision",parentData:data13,parentDataProperty:"data_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
errors = vErrors.length;
}
var valid8 = _errs38 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data13.outcome !== undefined){
let data17 = data13.outcome;
const _errs39 = errors;
const _errs40 = errors;
let valid9 = false;
const _errs41 = errors;
if(errors === _errs41){
if(data17 && typeof data17 == "object" && !Array.isArray(data17)){
let missing7;
if(((((data17.resource === undefined) && (missing7 = "resource")) || ((data17.operation === undefined) && (missing7 = "operation"))) || ((data17.phase === undefined) && (missing7 = "phase"))) || ((data17.resolution_input === undefined) && (missing7 = "resolution_input"))){
const err21 = {instancePath:instancePath+"/observation/event/outcome",schemaPath:"#/oneOf/3/properties/observation/properties/event/anyOf/0/properties/outcome/anyOf/0/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
}
errors++;
}
else {
const _errs43 = errors;
for(const key7 in data17){
if(!(((((key7 === "resource") || (key7 === "operation")) || (key7 === "phase")) || (key7 === "resolution_input")) || (key7 === "diagnostic"))){
const err22 = {instancePath:instancePath+"/observation/event/outcome",schemaPath:"#/oneOf/3/properties/observation/properties/event/anyOf/0/properties/outcome/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
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
if(_errs43 === errors){
if(data17.resource !== undefined){
const _errs44 = errors;
if(!(validate56(data17.resource, {instancePath:instancePath+"/observation/event/outcome/resource",parentData:data17,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid10 = _errs44 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data17.operation !== undefined){
const _errs45 = errors;
if(!(validate56(data17.operation, {instancePath:instancePath+"/observation/event/outcome/operation",parentData:data17,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid10 = _errs45 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data17.phase !== undefined){
const _errs46 = errors;
if(!(validate177(data17.phase, {instancePath:instancePath+"/observation/event/outcome/phase",parentData:data17,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate177.errors : vErrors.concat(validate177.errors);
errors = vErrors.length;
}
var valid10 = _errs46 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data17.resolution_input !== undefined){
const _errs47 = errors;
if(!(validate56(data17.resolution_input, {instancePath:instancePath+"/observation/event/outcome/resolution_input",parentData:data17,parentDataProperty:"resolution_input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid10 = _errs47 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data17.diagnostic !== undefined){
let data22 = data17.diagnostic;
const _errs48 = errors;
const _errs49 = errors;
let valid11 = false;
const _errs50 = errors;
if(!(validate72(data22, {instancePath:instancePath+"/observation/event/outcome/diagnostic",parentData:data17,parentDataProperty:"diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
errors = vErrors.length;
}
var _valid3 = _errs50 === errors;
valid11 = valid11 || _valid3;
const _errs51 = errors;
if(data22 !== null){
const err23 = {instancePath:instancePath+"/observation/event/outcome/diagnostic",schemaPath:"#/oneOf/3/properties/observation/properties/event/anyOf/0/properties/outcome/anyOf/0/properties/diagnostic/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err23];
}
else {
vErrors.push(err23);
}
errors++;
}
var _valid3 = _errs51 === errors;
valid11 = valid11 || _valid3;
if(!valid11){
const err24 = {instancePath:instancePath+"/observation/event/outcome/diagnostic",schemaPath:"#/oneOf/3/properties/observation/properties/event/anyOf/0/properties/outcome/anyOf/0/properties/diagnostic/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
}
errors++;
}
else {
errors = _errs49;
if(vErrors !== null){
if(_errs49){
vErrors.length = _errs49;
}
else {
vErrors = null;
}
}
}
var valid10 = _errs48 === errors;
}
else {
var valid10 = true;
}
}
}
}
}
}
}
}
else {
const err25 = {instancePath:instancePath+"/observation/event/outcome",schemaPath:"#/oneOf/3/properties/observation/properties/event/anyOf/0/properties/outcome/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err25];
}
else {
vErrors.push(err25);
}
errors++;
}
}
var _valid2 = _errs41 === errors;
valid9 = valid9 || _valid2;
const _errs53 = errors;
if(data17 !== null){
const err26 = {instancePath:instancePath+"/observation/event/outcome",schemaPath:"#/oneOf/3/properties/observation/properties/event/anyOf/0/properties/outcome/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err26];
}
else {
vErrors.push(err26);
}
errors++;
}
var _valid2 = _errs53 === errors;
valid9 = valid9 || _valid2;
if(!valid9){
const err27 = {instancePath:instancePath+"/observation/event/outcome",schemaPath:"#/oneOf/3/properties/observation/properties/event/anyOf/0/properties/outcome/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err27];
}
else {
vErrors.push(err27);
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
}
}
else {
const err28 = {instancePath:instancePath+"/observation/event",schemaPath:"#/oneOf/3/properties/observation/properties/event/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err28];
}
else {
vErrors.push(err28);
}
errors++;
}
}
var _valid1 = _errs32 === errors;
valid7 = valid7 || _valid1;
const _errs55 = errors;
if(data13 !== null){
const err29 = {instancePath:instancePath+"/observation/event",schemaPath:"#/oneOf/3/properties/observation/properties/event/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err29];
}
else {
vErrors.push(err29);
}
errors++;
}
var _valid1 = _errs55 === errors;
valid7 = valid7 || _valid1;
if(!valid7){
const err30 = {instancePath:instancePath+"/observation/event",schemaPath:"#/oneOf/3/properties/observation/properties/event/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
}
errors++;
}
else {
errors = _errs31;
if(vErrors !== null){
if(_errs31){
vErrors.length = _errs31;
}
else {
vErrors = null;
}
}
}
var valid6 = _errs30 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data8.cursor !== undefined){
const _errs57 = errors;
if(!(validate218(data8.cursor, {instancePath:instancePath+"/observation/cursor",parentData:data8,parentDataProperty:"cursor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate218.errors : vErrors.concat(validate218.errors);
errors = vErrors.length;
}
var valid6 = _errs57 === errors;
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
const err31 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/3/properties/observation/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err31];
}
else {
vErrors.push(err31);
}
errors++;
}
}
}
}
}
}
else {
const err32 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err32];
}
else {
vErrors.push(err32);
}
errors++;
}
}
var _valid0 = _errs20 === errors;
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
const _errs58 = errors;
if(errors === _errs58){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing8;
if((data.event === undefined) && (missing8 = "event")){
const err33 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
else {
const _errs60 = errors;
for(const key8 in data){
if(!(key8 === "event")){
const err34 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
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
if(_errs60 === errors){
if(data.event !== undefined){
let data24 = data.event;
const _errs61 = errors;
if(errors === _errs61){
if(data24 && typeof data24 == "object" && !Array.isArray(data24)){
let missing9;
if(((data24.cursor === undefined) && (missing9 = "cursor")) || ((data24.event === undefined) && (missing9 = "event"))){
const err35 = {instancePath:instancePath+"/event",schemaPath:"#/oneOf/4/properties/event/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
if(vErrors === null){
vErrors = [err35];
}
else {
vErrors.push(err35);
}
errors++;
}
else {
const _errs63 = errors;
for(const key9 in data24){
if(!((key9 === "cursor") || (key9 === "event"))){
const err36 = {instancePath:instancePath+"/event",schemaPath:"#/oneOf/4/properties/event/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
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
if(_errs63 === errors){
if(data24.cursor !== undefined){
const _errs64 = errors;
if(!(validate219(data24.cursor, {instancePath:instancePath+"/event/cursor",parentData:data24,parentDataProperty:"cursor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate219.errors : vErrors.concat(validate219.errors);
errors = vErrors.length;
}
var valid13 = _errs64 === errors;
}
else {
var valid13 = true;
}
if(valid13){
if(data24.event !== undefined){
let data26 = data24.event;
const _errs65 = errors;
if(errors === _errs65){
if(data26 && typeof data26 == "object" && !Array.isArray(data26)){
let missing10;
if((((data26.source_changed === undefined) && (missing10 = "source_changed")) || ((data26.resource === undefined) && (missing10 = "resource"))) || ((data26.data_revision === undefined) && (missing10 = "data_revision"))){
const err37 = {instancePath:instancePath+"/event/event",schemaPath:"#/oneOf/4/properties/event/properties/event/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"};
if(vErrors === null){
vErrors = [err37];
}
else {
vErrors.push(err37);
}
errors++;
}
else {
const _errs67 = errors;
for(const key10 in data26){
if(!((((key10 === "source_changed") || (key10 === "resource")) || (key10 === "data_revision")) || (key10 === "outcome"))){
const err38 = {instancePath:instancePath+"/event/event",schemaPath:"#/oneOf/4/properties/event/properties/event/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"};
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
if(_errs67 === errors){
if(data26.source_changed !== undefined){
const _errs68 = errors;
if(typeof data26.source_changed !== "boolean"){
const err39 = {instancePath:instancePath+"/event/event/source_changed",schemaPath:"#/oneOf/4/properties/event/properties/event/properties/source_changed/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err39];
}
else {
vErrors.push(err39);
}
errors++;
}
var valid14 = _errs68 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data26.resource !== undefined){
const _errs70 = errors;
if(!(validate56(data26.resource, {instancePath:instancePath+"/event/event/resource",parentData:data26,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid14 = _errs70 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data26.data_revision !== undefined){
const _errs71 = errors;
if(!(validate225(data26.data_revision, {instancePath:instancePath+"/event/event/data_revision",parentData:data26,parentDataProperty:"data_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
errors = vErrors.length;
}
var valid14 = _errs71 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data26.outcome !== undefined){
let data30 = data26.outcome;
const _errs72 = errors;
const _errs73 = errors;
let valid15 = false;
const _errs74 = errors;
if(errors === _errs74){
if(data30 && typeof data30 == "object" && !Array.isArray(data30)){
let missing11;
if(((((data30.resource === undefined) && (missing11 = "resource")) || ((data30.operation === undefined) && (missing11 = "operation"))) || ((data30.phase === undefined) && (missing11 = "phase"))) || ((data30.resolution_input === undefined) && (missing11 = "resolution_input"))){
const err40 = {instancePath:instancePath+"/event/event/outcome",schemaPath:"#/oneOf/4/properties/event/properties/event/properties/outcome/anyOf/0/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
if(vErrors === null){
vErrors = [err40];
}
else {
vErrors.push(err40);
}
errors++;
}
else {
const _errs76 = errors;
for(const key11 in data30){
if(!(((((key11 === "resource") || (key11 === "operation")) || (key11 === "phase")) || (key11 === "resolution_input")) || (key11 === "diagnostic"))){
const err41 = {instancePath:instancePath+"/event/event/outcome",schemaPath:"#/oneOf/4/properties/event/properties/event/properties/outcome/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
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
if(_errs76 === errors){
if(data30.resource !== undefined){
const _errs77 = errors;
if(!(validate56(data30.resource, {instancePath:instancePath+"/event/event/outcome/resource",parentData:data30,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid16 = _errs77 === errors;
}
else {
var valid16 = true;
}
if(valid16){
if(data30.operation !== undefined){
const _errs78 = errors;
if(!(validate56(data30.operation, {instancePath:instancePath+"/event/event/outcome/operation",parentData:data30,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid16 = _errs78 === errors;
}
else {
var valid16 = true;
}
if(valid16){
if(data30.phase !== undefined){
const _errs79 = errors;
if(!(validate177(data30.phase, {instancePath:instancePath+"/event/event/outcome/phase",parentData:data30,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate177.errors : vErrors.concat(validate177.errors);
errors = vErrors.length;
}
var valid16 = _errs79 === errors;
}
else {
var valid16 = true;
}
if(valid16){
if(data30.resolution_input !== undefined){
const _errs80 = errors;
if(!(validate56(data30.resolution_input, {instancePath:instancePath+"/event/event/outcome/resolution_input",parentData:data30,parentDataProperty:"resolution_input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid16 = _errs80 === errors;
}
else {
var valid16 = true;
}
if(valid16){
if(data30.diagnostic !== undefined){
let data35 = data30.diagnostic;
const _errs81 = errors;
const _errs82 = errors;
let valid17 = false;
const _errs83 = errors;
if(!(validate72(data35, {instancePath:instancePath+"/event/event/outcome/diagnostic",parentData:data30,parentDataProperty:"diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
errors = vErrors.length;
}
var _valid5 = _errs83 === errors;
valid17 = valid17 || _valid5;
const _errs84 = errors;
if(data35 !== null){
const err42 = {instancePath:instancePath+"/event/event/outcome/diagnostic",schemaPath:"#/oneOf/4/properties/event/properties/event/properties/outcome/anyOf/0/properties/diagnostic/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err42];
}
else {
vErrors.push(err42);
}
errors++;
}
var _valid5 = _errs84 === errors;
valid17 = valid17 || _valid5;
if(!valid17){
const err43 = {instancePath:instancePath+"/event/event/outcome/diagnostic",schemaPath:"#/oneOf/4/properties/event/properties/event/properties/outcome/anyOf/0/properties/diagnostic/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err43];
}
else {
vErrors.push(err43);
}
errors++;
}
else {
errors = _errs82;
if(vErrors !== null){
if(_errs82){
vErrors.length = _errs82;
}
else {
vErrors = null;
}
}
}
var valid16 = _errs81 === errors;
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
else {
const err44 = {instancePath:instancePath+"/event/event/outcome",schemaPath:"#/oneOf/4/properties/event/properties/event/properties/outcome/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err44];
}
else {
vErrors.push(err44);
}
errors++;
}
}
var _valid4 = _errs74 === errors;
valid15 = valid15 || _valid4;
const _errs86 = errors;
if(data30 !== null){
const err45 = {instancePath:instancePath+"/event/event/outcome",schemaPath:"#/oneOf/4/properties/event/properties/event/properties/outcome/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err45];
}
else {
vErrors.push(err45);
}
errors++;
}
var _valid4 = _errs86 === errors;
valid15 = valid15 || _valid4;
if(!valid15){
const err46 = {instancePath:instancePath+"/event/event/outcome",schemaPath:"#/oneOf/4/properties/event/properties/event/properties/outcome/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err46];
}
else {
vErrors.push(err46);
}
errors++;
}
else {
errors = _errs73;
if(vErrors !== null){
if(_errs73){
vErrors.length = _errs73;
}
else {
vErrors = null;
}
}
}
var valid14 = _errs72 === errors;
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
const err47 = {instancePath:instancePath+"/event/event",schemaPath:"#/oneOf/4/properties/event/properties/event/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err47];
}
else {
vErrors.push(err47);
}
errors++;
}
}
var valid13 = _errs65 === errors;
}
else {
var valid13 = true;
}
}
}
}
}
else {
const err48 = {instancePath:instancePath+"/event",schemaPath:"#/oneOf/4/properties/event/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err49 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err49];
}
else {
vErrors.push(err49);
}
errors++;
}
}
var _valid0 = _errs58 === errors;
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
const _errs88 = errors;
if(errors === _errs88){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing12;
if((data.heartbeat === undefined) && (missing12 = "heartbeat")){
const err50 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing12},message:"must have required property '"+missing12+"'"};
if(vErrors === null){
vErrors = [err50];
}
else {
vErrors.push(err50);
}
errors++;
}
else {
const _errs90 = errors;
for(const key12 in data){
if(!(key12 === "heartbeat")){
const err51 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key12},message:"must NOT have additional properties"};
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
if(_errs90 === errors){
if(data.heartbeat !== undefined){
let data36 = data.heartbeat;
const _errs91 = errors;
if(errors === _errs91){
if(data36 && typeof data36 == "object" && !Array.isArray(data36)){
const _errs93 = errors;
for(const key13 in data36){
if(!(key13 === "version")){
const err52 = {instancePath:instancePath+"/heartbeat",schemaPath:"#/oneOf/5/properties/heartbeat/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key13},message:"must NOT have additional properties"};
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
if(_errs93 === errors){
if(data36.version !== undefined){
if(1 !== data36.version){
const err53 = {instancePath:instancePath+"/heartbeat/version",schemaPath:"#/oneOf/5/properties/heartbeat/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"};
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
else {
const err54 = {instancePath:instancePath+"/heartbeat",schemaPath:"#/oneOf/5/properties/heartbeat/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err55 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err55];
}
else {
vErrors.push(err55);
}
errors++;
}
}
var _valid0 = _errs88 === errors;
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
const _errs95 = errors;
if(errors === _errs95){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing13;
if((data.terminal === undefined) && (missing13 = "terminal")){
const err56 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing13},message:"must have required property '"+missing13+"'"};
if(vErrors === null){
vErrors = [err56];
}
else {
vErrors.push(err56);
}
errors++;
}
else {
const _errs97 = errors;
for(const key14 in data){
if(!(key14 === "terminal")){
const err57 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key14},message:"must NOT have additional properties"};
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
if(_errs97 === errors){
if(data.terminal !== undefined){
let data38 = data.terminal;
const _errs98 = errors;
if(errors === _errs98){
if(data38 && typeof data38 == "object" && !Array.isArray(data38)){
let missing14;
if((data38.reason === undefined) && (missing14 = "reason")){
const err58 = {instancePath:instancePath+"/terminal",schemaPath:"#/oneOf/6/properties/terminal/required",keyword:"required",params:{missingProperty: missing14},message:"must have required property '"+missing14+"'"};
if(vErrors === null){
vErrors = [err58];
}
else {
vErrors.push(err58);
}
errors++;
}
else {
const _errs100 = errors;
for(const key15 in data38){
if(!((key15 === "reason") || (key15 === "diagnostic"))){
const err59 = {instancePath:instancePath+"/terminal",schemaPath:"#/oneOf/6/properties/terminal/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key15},message:"must NOT have additional properties"};
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
if(_errs100 === errors){
if(data38.reason !== undefined){
let data39 = data38.reason;
const _errs101 = errors;
if(typeof data39 !== "string"){
const err60 = {instancePath:instancePath+"/terminal/reason",schemaPath:"#/oneOf/6/properties/terminal/properties/reason/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err60];
}
else {
vErrors.push(err60);
}
errors++;
}
if(!((((((((data39 === "denied") || (data39 === "closed")) || (data39 === "expired")) || (data39 === "fenced")) || (data39 === "reset_required")) || (data39 === "interrupted")) || (data39 === "invalid_message")) || (data39 === "capacity"))){
const err61 = {instancePath:instancePath+"/terminal/reason",schemaPath:"#/oneOf/6/properties/terminal/properties/reason/enum",keyword:"enum",params:{allowedValues: schema96.oneOf[6].properties.terminal.properties.reason.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err61];
}
else {
vErrors.push(err61);
}
errors++;
}
var valid21 = _errs101 === errors;
}
else {
var valid21 = true;
}
if(valid21){
if(data38.diagnostic !== undefined){
let data40 = data38.diagnostic;
const _errs103 = errors;
const _errs104 = errors;
let valid22 = false;
const _errs105 = errors;
if(!(validate72(data40, {instancePath:instancePath+"/terminal/diagnostic",parentData:data38,parentDataProperty:"diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
errors = vErrors.length;
}
var _valid6 = _errs105 === errors;
valid22 = valid22 || _valid6;
const _errs106 = errors;
if(data40 !== null){
const err62 = {instancePath:instancePath+"/terminal/diagnostic",schemaPath:"#/oneOf/6/properties/terminal/properties/diagnostic/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err62];
}
else {
vErrors.push(err62);
}
errors++;
}
var _valid6 = _errs106 === errors;
valid22 = valid22 || _valid6;
if(!valid22){
const err63 = {instancePath:instancePath+"/terminal/diagnostic",schemaPath:"#/oneOf/6/properties/terminal/properties/diagnostic/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err63];
}
else {
vErrors.push(err63);
}
errors++;
}
else {
errors = _errs104;
if(vErrors !== null){
if(_errs104){
vErrors.length = _errs104;
}
else {
vErrors = null;
}
}
}
var valid21 = _errs103 === errors;
}
else {
var valid21 = true;
}
}
}
}
}
else {
const err64 = {instancePath:instancePath+"/terminal",schemaPath:"#/oneOf/6/properties/terminal/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err65 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err65];
}
else {
vErrors.push(err65);
}
errors++;
}
}
var _valid0 = _errs95 === errors;
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
const err66 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err66];
}
else {
vErrors.push(err66);
}
errors++;
validate322.errors = vErrors;
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
validate322.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate322.evaluated = {"dynamicProps":true,"dynamicItems":false};

export const Discovery = validate355;
const schema100 = {"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"service":{"$ref":"https://transit.invalid/generated-validator/1"},"ingress":{"$ref":"https://transit.invalid/generated-validator/1"},"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"binding_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"watch_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"sse":{"type":"boolean"},"websocket":{"type":"boolean"},"subprotocol":{"type":"string","maxLength":256},"openapi_sha256":{"$ref":"https://transit.invalid/generated-validator/4"},"asyncapi_sha256":{"$ref":"https://transit.invalid/generated-validator/4"}},"required":["service","ingress","resource","binding_revision","watch_revision","openapi_sha256","asyncapi_sha256"]};

function validate355(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate355.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((data.service === undefined) && (missing0 = "service")) || ((data.ingress === undefined) && (missing0 = "ingress"))) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.binding_revision === undefined) && (missing0 = "binding_revision"))) || ((data.watch_revision === undefined) && (missing0 = "watch_revision"))) || ((data.openapi_sha256 === undefined) && (missing0 = "openapi_sha256"))) || ((data.asyncapi_sha256 === undefined) && (missing0 = "asyncapi_sha256"))){
validate355.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema100.properties, key0))){
validate355.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate355.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"}];
return false;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.service !== undefined){
const _errs3 = errors;
if(!(validate56(data.service, {instancePath:instancePath+"/service",parentData:data,parentDataProperty:"service",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.ingress !== undefined){
const _errs4 = errors;
if(!(validate56(data.ingress, {instancePath:instancePath+"/ingress",parentData:data,parentDataProperty:"ingress",rootData,dynamicAnchors}))){
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
if(data.binding_revision !== undefined){
const _errs6 = errors;
if(!(validate56(data.binding_revision, {instancePath:instancePath+"/binding_revision",parentData:data,parentDataProperty:"binding_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.watch_revision !== undefined){
const _errs7 = errors;
if(!(validate56(data.watch_revision, {instancePath:instancePath+"/watch_revision",parentData:data,parentDataProperty:"watch_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.sse !== undefined){
const _errs8 = errors;
if(typeof data.sse !== "boolean"){
validate355.errors = [{instancePath:instancePath+"/sse",schemaPath:"#/properties/sse/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.websocket !== undefined){
const _errs10 = errors;
if(typeof data.websocket !== "boolean"){
validate355.errors = [{instancePath:instancePath+"/websocket",schemaPath:"#/properties/websocket/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs10 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.subprotocol !== undefined){
let data8 = data.subprotocol;
const _errs12 = errors;
if(errors === _errs12){
if(typeof data8 === "string"){
if(func2(data8) > 256){
validate355.errors = [{instancePath:instancePath+"/subprotocol",schemaPath:"#/properties/subprotocol/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"}];
return false;
}
}
else {
validate355.errors = [{instancePath:instancePath+"/subprotocol",schemaPath:"#/properties/subprotocol/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs12 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.openapi_sha256 !== undefined){
const _errs14 = errors;
if(!(validate64(data.openapi_sha256, {instancePath:instancePath+"/openapi_sha256",parentData:data,parentDataProperty:"openapi_sha256",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
errors = vErrors.length;
}
var valid0 = _errs14 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.asyncapi_sha256 !== undefined){
const _errs15 = errors;
if(!(validate64(data.asyncapi_sha256, {instancePath:instancePath+"/asyncapi_sha256",parentData:data,parentDataProperty:"asyncapi_sha256",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
errors = vErrors.length;
}
var valid0 = _errs15 === errors;
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
validate355.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate355.errors = vErrors;
return errors === 0;
}
validate355.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Error = validate363;
const schema101 = {"type":"object","additionalProperties":false,"properties":{"err":{"type":"string","enum":["ServingRequestFailed","HttpCapacity","InvalidHttpRequest"]},"reason":{"anyOf":[{"type":"string","enum":["denied","closed","expired","fenced","reset_required","not_found","conflict","result_not_completed","unavailable","capacity","invalid_request","internal_failure"]},{"type":"null"}]},"diagnostic":{"anyOf":[{"$ref":"Diagnostic"},{"type":"null"}]}},"required":["err"]};

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
if((data.err === undefined) && (missing0 = "err")){
validate363.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "err") || (key0 === "reason")) || (key0 === "diagnostic"))){
validate363.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.err !== undefined){
let data0 = data.err;
const _errs2 = errors;
if(typeof data0 !== "string"){
validate363.errors = [{instancePath:instancePath+"/err",schemaPath:"#/properties/err/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((data0 === "ServingRequestFailed") || (data0 === "HttpCapacity")) || (data0 === "InvalidHttpRequest"))){
validate363.errors = [{instancePath:instancePath+"/err",schemaPath:"#/properties/err/enum",keyword:"enum",params:{allowedValues: schema101.properties.err.enum},message:"must be equal to one of the allowed values"}];
return false;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.reason !== undefined){
let data1 = data.reason;
const _errs4 = errors;
const _errs5 = errors;
let valid1 = false;
const _errs6 = errors;
if(typeof data1 !== "string"){
const err0 = {instancePath:instancePath+"/reason",schemaPath:"#/properties/reason/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
}
if(!((((((((((((data1 === "denied") || (data1 === "closed")) || (data1 === "expired")) || (data1 === "fenced")) || (data1 === "reset_required")) || (data1 === "not_found")) || (data1 === "conflict")) || (data1 === "result_not_completed")) || (data1 === "unavailable")) || (data1 === "capacity")) || (data1 === "invalid_request")) || (data1 === "internal_failure"))){
const err1 = {instancePath:instancePath+"/reason",schemaPath:"#/properties/reason/anyOf/0/enum",keyword:"enum",params:{allowedValues: schema101.properties.reason.anyOf[0].enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
}
var _valid0 = _errs6 === errors;
valid1 = valid1 || _valid0;
const _errs8 = errors;
if(data1 !== null){
const err2 = {instancePath:instancePath+"/reason",schemaPath:"#/properties/reason/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err2];
}
else {
vErrors.push(err2);
}
errors++;
}
var _valid0 = _errs8 === errors;
valid1 = valid1 || _valid0;
if(!valid1){
const err3 = {instancePath:instancePath+"/reason",schemaPath:"#/properties/reason/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
validate363.errors = vErrors;
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
if(valid0){
if(data.diagnostic !== undefined){
let data2 = data.diagnostic;
const _errs10 = errors;
const _errs11 = errors;
let valid2 = false;
const _errs12 = errors;
if(!(validate72(data2, {instancePath:instancePath+"/diagnostic",parentData:data,parentDataProperty:"diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
errors = vErrors.length;
}
var _valid1 = _errs12 === errors;
valid2 = valid2 || _valid1;
const _errs13 = errors;
if(data2 !== null){
const err4 = {instancePath:instancePath+"/diagnostic",schemaPath:"#/properties/diagnostic/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
}
var _valid1 = _errs13 === errors;
valid2 = valid2 || _valid1;
if(!valid2){
const err5 = {instancePath:instancePath+"/diagnostic",schemaPath:"#/properties/diagnostic/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err5];
}
else {
vErrors.push(err5);
}
errors++;
validate363.errors = vErrors;
return false;
}
else {
errors = _errs11;
if(vErrors !== null){
if(_errs11){
vErrors.length = _errs11;
}
else {
vErrors = null;
}
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
else {
validate363.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate363.errors = vErrors;
return errors === 0;
}
validate363.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const SseItem = validate365;
const schema102 = {"type":"object","additionalProperties":false,"properties":{"event":{"type":"string","enum":["attached","event","heartbeat","terminal"]},"data":{"type":"string","maxLength":8192},"id":{"type":"string","pattern":"^(?:[0-9a-f]{2})+$","maxLength":512}},"required":["event","data"]};
const pattern8 = new RegExp("^(?:[0-9a-f]{2})+$", "u");

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
if(((data.event === undefined) && (missing0 = "event")) || ((data.data === undefined) && (missing0 = "data"))){
validate365.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "event") || (key0 === "data")) || (key0 === "id"))){
validate365.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.event !== undefined){
let data0 = data.event;
const _errs2 = errors;
if(typeof data0 !== "string"){
validate365.errors = [{instancePath:instancePath+"/event",schemaPath:"#/properties/event/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((data0 === "attached") || (data0 === "event")) || (data0 === "heartbeat")) || (data0 === "terminal"))){
validate365.errors = [{instancePath:instancePath+"/event",schemaPath:"#/properties/event/enum",keyword:"enum",params:{allowedValues: schema102.properties.event.enum},message:"must be equal to one of the allowed values"}];
return false;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.data !== undefined){
let data1 = data.data;
const _errs4 = errors;
if(errors === _errs4){
if(typeof data1 === "string"){
if(func2(data1) > 8192){
validate365.errors = [{instancePath:instancePath+"/data",schemaPath:"#/properties/data/maxLength",keyword:"maxLength",params:{limit: 8192},message:"must NOT have more than 8192 characters"}];
return false;
}
}
else {
validate365.errors = [{instancePath:instancePath+"/data",schemaPath:"#/properties/data/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.id !== undefined){
let data2 = data.id;
const _errs6 = errors;
if(errors === _errs6){
if(typeof data2 === "string"){
if(func2(data2) > 512){
validate365.errors = [{instancePath:instancePath+"/id",schemaPath:"#/properties/id/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"}];
return false;
}
else {
if(!pattern8.test(data2)){
validate365.errors = [{instancePath:instancePath+"/id",schemaPath:"#/properties/id/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})+$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})+$"+"\""}];
return false;
}
}
}
else {
validate365.errors = [{instancePath:instancePath+"/id",schemaPath:"#/properties/id/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
validate365.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate365.errors = vErrors;
return errors === 0;
}
validate365.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const HostRequest = validate366;
const schema103 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["describe"],"properties":{"describe":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["clock"],"properties":{"clock":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["inspect"],"properties":{"inspect":{"$ref":"https://transit.invalid/generated-validator/48"}}},{"type":"object","additionalProperties":false,"required":["covered"],"properties":{"covered":{"type":"object","additionalProperties":false,"properties":{"observation":{"$ref":"https://transit.invalid/generated-validator/58"},"captured":{"$ref":"https://transit.invalid/generated-validator/53"}},"required":["observation","captured"]}}},{"type":"object","additionalProperties":false,"required":["prepare"],"properties":{"prepare":{"oneOf":[{"type":"object","additionalProperties":false,"required":["open"],"properties":{"open":{"type":"object","additionalProperties":false,"properties":{"session":{"$ref":"https://transit.invalid/generated-validator/1"},"source_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"lease_before_ms":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["session","source_revision","lease_before_ms"]}}},{"type":"object","additionalProperties":false,"required":["attach"],"properties":{"attach":{"type":"object","additionalProperties":false,"properties":{"identity":{"$ref":"https://transit.invalid/generated-validator/70"},"expected":{"$ref":"https://transit.invalid/generated-validator/1"},"nonce":{"$ref":"https://transit.invalid/generated-validator/43"}},"required":["identity","expected","nonce"]}}},{"type":"object","additionalProperties":false,"required":["subscribe"],"properties":{"subscribe":{"type":"object","additionalProperties":false,"properties":{"identity":{"$ref":"https://transit.invalid/generated-validator/70"},"expected":{"$ref":"https://transit.invalid/generated-validator/1"},"subscription":{"$ref":"https://transit.invalid/generated-validator/1"},"operation":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["identity","expected","subscription"]}}},{"type":"object","additionalProperties":false,"required":["renew"],"properties":{"renew":{"type":"object","additionalProperties":false,"properties":{"identity":{"$ref":"https://transit.invalid/generated-validator/70"},"expected":{"$ref":"https://transit.invalid/generated-validator/1"},"lease_before_ms":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["identity","expected","lease_before_ms"]}}},{"type":"object","additionalProperties":false,"required":["unsubscribe"],"properties":{"unsubscribe":{"type":"object","additionalProperties":false,"properties":{"identity":{"$ref":"https://transit.invalid/generated-validator/70"},"subscription":{"$ref":"https://transit.invalid/generated-validator/1"},"generation":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["identity","subscription","generation"]}}},{"type":"object","additionalProperties":false,"required":["close"],"properties":{"close":{"$ref":"https://transit.invalid/generated-validator/70"}}}]}}},{"type":"object","additionalProperties":false,"required":["submit"],"properties":{"submit":{"$ref":"https://transit.invalid/generated-validator/66"}}},{"type":"object","additionalProperties":false,"required":["observe"],"properties":{"observe":{"$ref":"https://transit.invalid/generated-validator/66"}}},{"type":"object","additionalProperties":false,"required":["sign_read"],"properties":{"sign_read":{"$ref":"https://transit.invalid/generated-validator/48"}}},{"type":"object","additionalProperties":false,"required":["refresh_prepare"],"properties":{"refresh_prepare":{"oneOf":[{"type":"object","additionalProperties":false,"required":["follow"],"properties":{"follow":{"type":"object","additionalProperties":false,"properties":{"session":{"$ref":"https://transit.invalid/generated-validator/70"},"expected":{"$ref":"https://transit.invalid/generated-validator/1"},"template":{"$ref":"https://transit.invalid/generated-validator/44"},"captures":{"type":"array","minItems":8,"maxItems":8,"items":{"$ref":"https://transit.invalid/generated-validator/44"}},"limit":{"$ref":"https://transit.invalid/generated-validator/3"}},"required":["session","expected","template","captures","limit"]}}},{"type":"object","additionalProperties":false,"required":["invalidate"],"properties":{"invalidate":{"$ref":"https://transit.invalid/generated-validator/71"}}},{"type":"object","additionalProperties":false,"required":["acknowledged"],"properties":{"acknowledged":{"type":"object","additionalProperties":false,"properties":{"selection":{"$ref":"https://transit.invalid/generated-validator/71"},"namespace":{"$ref":"https://transit.invalid/generated-validator/44"}},"required":["selection","namespace"]}}},{"type":"object","additionalProperties":false,"required":["pause"],"properties":{"pause":{"$ref":"https://transit.invalid/generated-validator/71"}}}]}}},{"type":"object","additionalProperties":false,"required":["refresh_status"],"properties":{"refresh_status":{"$ref":"https://transit.invalid/generated-validator/71"}}}]};
const schema104 = {"type":"object","additionalProperties":false,"properties":{"session":{"$ref":"https://transit.invalid/generated-validator/1"},"generation":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["session","generation"]};

function validate373(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate373.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.session === undefined) && (missing0 = "session")) || ((data.generation === undefined) && (missing0 = "generation"))){
validate373.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "session") || (key0 === "generation"))){
validate373.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.session !== undefined){
const _errs2 = errors;
if(!(validate56(data.session, {instancePath:instancePath+"/session",parentData:data,parentDataProperty:"session",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate56(data.generation, {instancePath:instancePath+"/generation",parentData:data,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
validate373.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate373.errors = vErrors;
return errors === 0;
}
validate373.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema105 = {"type":"object","additionalProperties":false,"properties":{"session":{"$ref":"https://transit.invalid/generated-validator/70"},"generation":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["session","generation"]};

function validate398(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate398.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.session === undefined) && (missing0 = "session")) || ((data.generation === undefined) && (missing0 = "generation"))){
validate398.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "session") || (key0 === "generation"))){
validate398.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.session !== undefined){
const _errs2 = errors;
if(!(validate373(data.session, {instancePath:instancePath+"/session",parentData:data,parentDataProperty:"session",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate373.errors : vErrors.concat(validate373.errors);
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
if(!(validate56(data.generation, {instancePath:instancePath+"/generation",parentData:data,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
validate398.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate398.errors = vErrors;
return errors === 0;
}
validate398.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate366(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate366.evaluated;
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
if((data.clock === undefined) && (missing1 = "clock")){
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
if(!(key1 === "clock")){
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
if(data.clock !== undefined){
let data1 = data.clock;
const _errs9 = errors;
if(errors === _errs9){
if(data1 && typeof data1 == "object" && !Array.isArray(data1)){
if(Object.keys(data1).length > 0){
const err7 = {instancePath:instancePath+"/clock",schemaPath:"#/oneOf/1/properties/clock/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
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
const err8 = {instancePath:instancePath+"/clock",schemaPath:"#/oneOf/1/properties/clock/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.inspect === undefined) && (missing2 = "inspect")){
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
if(!(key2 === "inspect")){
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
if(data.inspect !== undefined){
if(!(validate201(data.inspect, {instancePath:instancePath+"/inspect",parentData:data,parentDataProperty:"inspect",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate201.errors : vErrors.concat(validate201.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err12 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
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
const _errs15 = errors;
if(errors === _errs15){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing3;
if((data.covered === undefined) && (missing3 = "covered")){
const err13 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
if(vErrors === null){
vErrors = [err13];
}
else {
vErrors.push(err13);
}
errors++;
}
else {
const _errs17 = errors;
for(const key3 in data){
if(!(key3 === "covered")){
const err14 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(_errs17 === errors){
if(data.covered !== undefined){
let data3 = data.covered;
const _errs18 = errors;
if(errors === _errs18){
if(data3 && typeof data3 == "object" && !Array.isArray(data3)){
let missing4;
if(((data3.observation === undefined) && (missing4 = "observation")) || ((data3.captured === undefined) && (missing4 = "captured"))){
const err15 = {instancePath:instancePath+"/covered",schemaPath:"#/oneOf/3/properties/covered/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
}
else {
const _errs20 = errors;
for(const key4 in data3){
if(!((key4 === "observation") || (key4 === "captured"))){
const err16 = {instancePath:instancePath+"/covered",schemaPath:"#/oneOf/3/properties/covered/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(_errs20 === errors){
if(data3.observation !== undefined){
const _errs21 = errors;
if(!(validate266(data3.observation, {instancePath:instancePath+"/covered/observation",parentData:data3,parentDataProperty:"observation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate266.errors : vErrors.concat(validate266.errors);
errors = vErrors.length;
}
var valid5 = _errs21 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data3.captured !== undefined){
const _errs22 = errors;
if(!(validate268(data3.captured, {instancePath:instancePath+"/covered/captured",parentData:data3,parentDataProperty:"captured",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate268.errors : vErrors.concat(validate268.errors);
errors = vErrors.length;
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
const err17 = {instancePath:instancePath+"/covered",schemaPath:"#/oneOf/3/properties/covered/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err18 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
}
}
var _valid0 = _errs15 === errors;
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
const _errs23 = errors;
if(errors === _errs23){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing5;
if((data.prepare === undefined) && (missing5 = "prepare")){
const err19 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
}
else {
const _errs25 = errors;
for(const key5 in data){
if(!(key5 === "prepare")){
const err20 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err20];
}
else {
vErrors.push(err20);
}
errors++;
break;
}
}
if(_errs25 === errors){
if(data.prepare !== undefined){
let data6 = data.prepare;
const _errs27 = errors;
let valid7 = false;
let passing1 = null;
const _errs28 = errors;
if(errors === _errs28){
if(data6 && typeof data6 == "object" && !Array.isArray(data6)){
let missing6;
if((data6.open === undefined) && (missing6 = "open")){
const err21 = {instancePath:instancePath+"/prepare",schemaPath:"#/oneOf/4/properties/prepare/oneOf/0/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
}
errors++;
}
else {
const _errs30 = errors;
for(const key6 in data6){
if(!(key6 === "open")){
const err22 = {instancePath:instancePath+"/prepare",schemaPath:"#/oneOf/4/properties/prepare/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
if(_errs30 === errors){
if(data6.open !== undefined){
let data7 = data6.open;
const _errs31 = errors;
if(errors === _errs31){
if(data7 && typeof data7 == "object" && !Array.isArray(data7)){
let missing7;
if((((data7.session === undefined) && (missing7 = "session")) || ((data7.source_revision === undefined) && (missing7 = "source_revision"))) || ((data7.lease_before_ms === undefined) && (missing7 = "lease_before_ms"))){
const err23 = {instancePath:instancePath+"/prepare/open",schemaPath:"#/oneOf/4/properties/prepare/oneOf/0/properties/open/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
if(vErrors === null){
vErrors = [err23];
}
else {
vErrors.push(err23);
}
errors++;
}
else {
const _errs33 = errors;
for(const key7 in data7){
if(!(((key7 === "session") || (key7 === "source_revision")) || (key7 === "lease_before_ms"))){
const err24 = {instancePath:instancePath+"/prepare/open",schemaPath:"#/oneOf/4/properties/prepare/oneOf/0/properties/open/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
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
if(_errs33 === errors){
if(data7.session !== undefined){
const _errs34 = errors;
if(!(validate56(data7.session, {instancePath:instancePath+"/prepare/open/session",parentData:data7,parentDataProperty:"session",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid9 = _errs34 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data7.source_revision !== undefined){
const _errs35 = errors;
if(!(validate56(data7.source_revision, {instancePath:instancePath+"/prepare/open/source_revision",parentData:data7,parentDataProperty:"source_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid9 = _errs35 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data7.lease_before_ms !== undefined){
const _errs36 = errors;
if(!(validate56(data7.lease_before_ms, {instancePath:instancePath+"/prepare/open/lease_before_ms",parentData:data7,parentDataProperty:"lease_before_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid9 = _errs36 === errors;
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
const err25 = {instancePath:instancePath+"/prepare/open",schemaPath:"#/oneOf/4/properties/prepare/oneOf/0/properties/open/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err26 = {instancePath:instancePath+"/prepare",schemaPath:"#/oneOf/4/properties/prepare/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err26];
}
else {
vErrors.push(err26);
}
errors++;
}
}
var _valid1 = _errs28 === errors;
if(_valid1){
valid7 = true;
passing1 = 0;
var props1 = true;
}
const _errs37 = errors;
if(errors === _errs37){
if(data6 && typeof data6 == "object" && !Array.isArray(data6)){
let missing8;
if((data6.attach === undefined) && (missing8 = "attach")){
const err27 = {instancePath:instancePath+"/prepare",schemaPath:"#/oneOf/4/properties/prepare/oneOf/1/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
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
for(const key8 in data6){
if(!(key8 === "attach")){
const err28 = {instancePath:instancePath+"/prepare",schemaPath:"#/oneOf/4/properties/prepare/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
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
if(data6.attach !== undefined){
let data11 = data6.attach;
const _errs40 = errors;
if(errors === _errs40){
if(data11 && typeof data11 == "object" && !Array.isArray(data11)){
let missing9;
if((((data11.identity === undefined) && (missing9 = "identity")) || ((data11.expected === undefined) && (missing9 = "expected"))) || ((data11.nonce === undefined) && (missing9 = "nonce"))){
const err29 = {instancePath:instancePath+"/prepare/attach",schemaPath:"#/oneOf/4/properties/prepare/oneOf/1/properties/attach/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
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
for(const key9 in data11){
if(!(((key9 === "identity") || (key9 === "expected")) || (key9 === "nonce"))){
const err30 = {instancePath:instancePath+"/prepare/attach",schemaPath:"#/oneOf/4/properties/prepare/oneOf/1/properties/attach/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
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
if(data11.identity !== undefined){
const _errs43 = errors;
if(!(validate373(data11.identity, {instancePath:instancePath+"/prepare/attach/identity",parentData:data11,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate373.errors : vErrors.concat(validate373.errors);
errors = vErrors.length;
}
var valid11 = _errs43 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data11.expected !== undefined){
const _errs44 = errors;
if(!(validate56(data11.expected, {instancePath:instancePath+"/prepare/attach/expected",parentData:data11,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid11 = _errs44 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data11.nonce !== undefined){
const _errs45 = errors;
if(!(validate215(data11.nonce, {instancePath:instancePath+"/prepare/attach/nonce",parentData:data11,parentDataProperty:"nonce",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate215.errors : vErrors.concat(validate215.errors);
errors = vErrors.length;
}
var valid11 = _errs45 === errors;
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
const err31 = {instancePath:instancePath+"/prepare/attach",schemaPath:"#/oneOf/4/properties/prepare/oneOf/1/properties/attach/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err31];
}
else {
vErrors.push(err31);
}
errors++;
}
}
}
}
}
}
else {
const err32 = {instancePath:instancePath+"/prepare",schemaPath:"#/oneOf/4/properties/prepare/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err32];
}
else {
vErrors.push(err32);
}
errors++;
}
}
var _valid1 = _errs37 === errors;
if(_valid1 && valid7){
valid7 = false;
passing1 = [passing1, 1];
}
else {
if(_valid1){
valid7 = true;
passing1 = 1;
if(props1 !== true){
props1 = true;
}
}
const _errs46 = errors;
if(errors === _errs46){
if(data6 && typeof data6 == "object" && !Array.isArray(data6)){
let missing10;
if((data6.subscribe === undefined) && (missing10 = "subscribe")){
const err33 = {instancePath:instancePath+"/prepare",schemaPath:"#/oneOf/4/properties/prepare/oneOf/2/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
else {
const _errs48 = errors;
for(const key10 in data6){
if(!(key10 === "subscribe")){
const err34 = {instancePath:instancePath+"/prepare",schemaPath:"#/oneOf/4/properties/prepare/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"};
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
if(_errs48 === errors){
if(data6.subscribe !== undefined){
let data15 = data6.subscribe;
const _errs49 = errors;
if(errors === _errs49){
if(data15 && typeof data15 == "object" && !Array.isArray(data15)){
let missing11;
if((((data15.identity === undefined) && (missing11 = "identity")) || ((data15.expected === undefined) && (missing11 = "expected"))) || ((data15.subscription === undefined) && (missing11 = "subscription"))){
const err35 = {instancePath:instancePath+"/prepare/subscribe",schemaPath:"#/oneOf/4/properties/prepare/oneOf/2/properties/subscribe/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
if(vErrors === null){
vErrors = [err35];
}
else {
vErrors.push(err35);
}
errors++;
}
else {
const _errs51 = errors;
for(const key11 in data15){
if(!((((key11 === "identity") || (key11 === "expected")) || (key11 === "subscription")) || (key11 === "operation"))){
const err36 = {instancePath:instancePath+"/prepare/subscribe",schemaPath:"#/oneOf/4/properties/prepare/oneOf/2/properties/subscribe/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
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
if(_errs51 === errors){
if(data15.identity !== undefined){
const _errs52 = errors;
if(!(validate373(data15.identity, {instancePath:instancePath+"/prepare/subscribe/identity",parentData:data15,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate373.errors : vErrors.concat(validate373.errors);
errors = vErrors.length;
}
var valid13 = _errs52 === errors;
}
else {
var valid13 = true;
}
if(valid13){
if(data15.expected !== undefined){
const _errs53 = errors;
if(!(validate56(data15.expected, {instancePath:instancePath+"/prepare/subscribe/expected",parentData:data15,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid13 = _errs53 === errors;
}
else {
var valid13 = true;
}
if(valid13){
if(data15.subscription !== undefined){
const _errs54 = errors;
if(!(validate56(data15.subscription, {instancePath:instancePath+"/prepare/subscribe/subscription",parentData:data15,parentDataProperty:"subscription",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid13 = _errs54 === errors;
}
else {
var valid13 = true;
}
if(valid13){
if(data15.operation !== undefined){
const _errs55 = errors;
if(!(validate56(data15.operation, {instancePath:instancePath+"/prepare/subscribe/operation",parentData:data15,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid13 = _errs55 === errors;
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
const err37 = {instancePath:instancePath+"/prepare/subscribe",schemaPath:"#/oneOf/4/properties/prepare/oneOf/2/properties/subscribe/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err38 = {instancePath:instancePath+"/prepare",schemaPath:"#/oneOf/4/properties/prepare/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err38];
}
else {
vErrors.push(err38);
}
errors++;
}
}
var _valid1 = _errs46 === errors;
if(_valid1 && valid7){
valid7 = false;
passing1 = [passing1, 2];
}
else {
if(_valid1){
valid7 = true;
passing1 = 2;
if(props1 !== true){
props1 = true;
}
}
const _errs56 = errors;
if(errors === _errs56){
if(data6 && typeof data6 == "object" && !Array.isArray(data6)){
let missing12;
if((data6.renew === undefined) && (missing12 = "renew")){
const err39 = {instancePath:instancePath+"/prepare",schemaPath:"#/oneOf/4/properties/prepare/oneOf/3/required",keyword:"required",params:{missingProperty: missing12},message:"must have required property '"+missing12+"'"};
if(vErrors === null){
vErrors = [err39];
}
else {
vErrors.push(err39);
}
errors++;
}
else {
const _errs58 = errors;
for(const key12 in data6){
if(!(key12 === "renew")){
const err40 = {instancePath:instancePath+"/prepare",schemaPath:"#/oneOf/4/properties/prepare/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key12},message:"must NOT have additional properties"};
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
if(_errs58 === errors){
if(data6.renew !== undefined){
let data20 = data6.renew;
const _errs59 = errors;
if(errors === _errs59){
if(data20 && typeof data20 == "object" && !Array.isArray(data20)){
let missing13;
if((((data20.identity === undefined) && (missing13 = "identity")) || ((data20.expected === undefined) && (missing13 = "expected"))) || ((data20.lease_before_ms === undefined) && (missing13 = "lease_before_ms"))){
const err41 = {instancePath:instancePath+"/prepare/renew",schemaPath:"#/oneOf/4/properties/prepare/oneOf/3/properties/renew/required",keyword:"required",params:{missingProperty: missing13},message:"must have required property '"+missing13+"'"};
if(vErrors === null){
vErrors = [err41];
}
else {
vErrors.push(err41);
}
errors++;
}
else {
const _errs61 = errors;
for(const key13 in data20){
if(!(((key13 === "identity") || (key13 === "expected")) || (key13 === "lease_before_ms"))){
const err42 = {instancePath:instancePath+"/prepare/renew",schemaPath:"#/oneOf/4/properties/prepare/oneOf/3/properties/renew/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key13},message:"must NOT have additional properties"};
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
if(_errs61 === errors){
if(data20.identity !== undefined){
const _errs62 = errors;
if(!(validate373(data20.identity, {instancePath:instancePath+"/prepare/renew/identity",parentData:data20,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate373.errors : vErrors.concat(validate373.errors);
errors = vErrors.length;
}
var valid15 = _errs62 === errors;
}
else {
var valid15 = true;
}
if(valid15){
if(data20.expected !== undefined){
const _errs63 = errors;
if(!(validate56(data20.expected, {instancePath:instancePath+"/prepare/renew/expected",parentData:data20,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid15 = _errs63 === errors;
}
else {
var valid15 = true;
}
if(valid15){
if(data20.lease_before_ms !== undefined){
const _errs64 = errors;
if(!(validate56(data20.lease_before_ms, {instancePath:instancePath+"/prepare/renew/lease_before_ms",parentData:data20,parentDataProperty:"lease_before_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid15 = _errs64 === errors;
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
const err43 = {instancePath:instancePath+"/prepare/renew",schemaPath:"#/oneOf/4/properties/prepare/oneOf/3/properties/renew/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err44 = {instancePath:instancePath+"/prepare",schemaPath:"#/oneOf/4/properties/prepare/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err44];
}
else {
vErrors.push(err44);
}
errors++;
}
}
var _valid1 = _errs56 === errors;
if(_valid1 && valid7){
valid7 = false;
passing1 = [passing1, 3];
}
else {
if(_valid1){
valid7 = true;
passing1 = 3;
if(props1 !== true){
props1 = true;
}
}
const _errs65 = errors;
if(errors === _errs65){
if(data6 && typeof data6 == "object" && !Array.isArray(data6)){
let missing14;
if((data6.unsubscribe === undefined) && (missing14 = "unsubscribe")){
const err45 = {instancePath:instancePath+"/prepare",schemaPath:"#/oneOf/4/properties/prepare/oneOf/4/required",keyword:"required",params:{missingProperty: missing14},message:"must have required property '"+missing14+"'"};
if(vErrors === null){
vErrors = [err45];
}
else {
vErrors.push(err45);
}
errors++;
}
else {
const _errs67 = errors;
for(const key14 in data6){
if(!(key14 === "unsubscribe")){
const err46 = {instancePath:instancePath+"/prepare",schemaPath:"#/oneOf/4/properties/prepare/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key14},message:"must NOT have additional properties"};
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
if(_errs67 === errors){
if(data6.unsubscribe !== undefined){
let data24 = data6.unsubscribe;
const _errs68 = errors;
if(errors === _errs68){
if(data24 && typeof data24 == "object" && !Array.isArray(data24)){
let missing15;
if((((data24.identity === undefined) && (missing15 = "identity")) || ((data24.subscription === undefined) && (missing15 = "subscription"))) || ((data24.generation === undefined) && (missing15 = "generation"))){
const err47 = {instancePath:instancePath+"/prepare/unsubscribe",schemaPath:"#/oneOf/4/properties/prepare/oneOf/4/properties/unsubscribe/required",keyword:"required",params:{missingProperty: missing15},message:"must have required property '"+missing15+"'"};
if(vErrors === null){
vErrors = [err47];
}
else {
vErrors.push(err47);
}
errors++;
}
else {
const _errs70 = errors;
for(const key15 in data24){
if(!(((key15 === "identity") || (key15 === "subscription")) || (key15 === "generation"))){
const err48 = {instancePath:instancePath+"/prepare/unsubscribe",schemaPath:"#/oneOf/4/properties/prepare/oneOf/4/properties/unsubscribe/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key15},message:"must NOT have additional properties"};
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
if(_errs70 === errors){
if(data24.identity !== undefined){
const _errs71 = errors;
if(!(validate373(data24.identity, {instancePath:instancePath+"/prepare/unsubscribe/identity",parentData:data24,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate373.errors : vErrors.concat(validate373.errors);
errors = vErrors.length;
}
var valid17 = _errs71 === errors;
}
else {
var valid17 = true;
}
if(valid17){
if(data24.subscription !== undefined){
const _errs72 = errors;
if(!(validate56(data24.subscription, {instancePath:instancePath+"/prepare/unsubscribe/subscription",parentData:data24,parentDataProperty:"subscription",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid17 = _errs72 === errors;
}
else {
var valid17 = true;
}
if(valid17){
if(data24.generation !== undefined){
const _errs73 = errors;
if(!(validate56(data24.generation, {instancePath:instancePath+"/prepare/unsubscribe/generation",parentData:data24,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid17 = _errs73 === errors;
}
else {
var valid17 = true;
}
}
}
}
}
}
else {
const err49 = {instancePath:instancePath+"/prepare/unsubscribe",schemaPath:"#/oneOf/4/properties/prepare/oneOf/4/properties/unsubscribe/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err50 = {instancePath:instancePath+"/prepare",schemaPath:"#/oneOf/4/properties/prepare/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err50];
}
else {
vErrors.push(err50);
}
errors++;
}
}
var _valid1 = _errs65 === errors;
if(_valid1 && valid7){
valid7 = false;
passing1 = [passing1, 4];
}
else {
if(_valid1){
valid7 = true;
passing1 = 4;
if(props1 !== true){
props1 = true;
}
}
const _errs74 = errors;
if(errors === _errs74){
if(data6 && typeof data6 == "object" && !Array.isArray(data6)){
let missing16;
if((data6.close === undefined) && (missing16 = "close")){
const err51 = {instancePath:instancePath+"/prepare",schemaPath:"#/oneOf/4/properties/prepare/oneOf/5/required",keyword:"required",params:{missingProperty: missing16},message:"must have required property '"+missing16+"'"};
if(vErrors === null){
vErrors = [err51];
}
else {
vErrors.push(err51);
}
errors++;
}
else {
const _errs76 = errors;
for(const key16 in data6){
if(!(key16 === "close")){
const err52 = {instancePath:instancePath+"/prepare",schemaPath:"#/oneOf/4/properties/prepare/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key16},message:"must NOT have additional properties"};
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
if(_errs76 === errors){
if(data6.close !== undefined){
if(!(validate373(data6.close, {instancePath:instancePath+"/prepare/close",parentData:data6,parentDataProperty:"close",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate373.errors : vErrors.concat(validate373.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err53 = {instancePath:instancePath+"/prepare",schemaPath:"#/oneOf/4/properties/prepare/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err53];
}
else {
vErrors.push(err53);
}
errors++;
}
}
var _valid1 = _errs74 === errors;
if(_valid1 && valid7){
valid7 = false;
passing1 = [passing1, 5];
}
else {
if(_valid1){
valid7 = true;
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
if(!valid7){
const err54 = {instancePath:instancePath+"/prepare",schemaPath:"#/oneOf/4/properties/prepare/oneOf",keyword:"oneOf",params:{passingSchemas: passing1},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err54];
}
else {
vErrors.push(err54);
}
errors++;
}
else {
errors = _errs27;
if(vErrors !== null){
if(_errs27){
vErrors.length = _errs27;
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
const err55 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err55];
}
else {
vErrors.push(err55);
}
errors++;
}
}
var _valid0 = _errs23 === errors;
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
const _errs78 = errors;
if(errors === _errs78){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing17;
if((data.submit === undefined) && (missing17 = "submit")){
const err56 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing17},message:"must have required property '"+missing17+"'"};
if(vErrors === null){
vErrors = [err56];
}
else {
vErrors.push(err56);
}
errors++;
}
else {
const _errs80 = errors;
for(const key17 in data){
if(!(key17 === "submit")){
const err57 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key17},message:"must NOT have additional properties"};
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
if(_errs80 === errors){
if(data.submit !== undefined){
if(!(validate308(data.submit, {instancePath:instancePath+"/submit",parentData:data,parentDataProperty:"submit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate308.errors : vErrors.concat(validate308.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err58 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err58];
}
else {
vErrors.push(err58);
}
errors++;
}
}
var _valid0 = _errs78 === errors;
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
const _errs82 = errors;
if(errors === _errs82){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing18;
if((data.observe === undefined) && (missing18 = "observe")){
const err59 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing18},message:"must have required property '"+missing18+"'"};
if(vErrors === null){
vErrors = [err59];
}
else {
vErrors.push(err59);
}
errors++;
}
else {
const _errs84 = errors;
for(const key18 in data){
if(!(key18 === "observe")){
const err60 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key18},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err60];
}
else {
vErrors.push(err60);
}
errors++;
break;
}
}
if(_errs84 === errors){
if(data.observe !== undefined){
if(!(validate308(data.observe, {instancePath:instancePath+"/observe",parentData:data,parentDataProperty:"observe",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate308.errors : vErrors.concat(validate308.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err61 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err61];
}
else {
vErrors.push(err61);
}
errors++;
}
}
var _valid0 = _errs82 === errors;
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
const _errs86 = errors;
if(errors === _errs86){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing19;
if((data.sign_read === undefined) && (missing19 = "sign_read")){
const err62 = {instancePath,schemaPath:"#/oneOf/7/required",keyword:"required",params:{missingProperty: missing19},message:"must have required property '"+missing19+"'"};
if(vErrors === null){
vErrors = [err62];
}
else {
vErrors.push(err62);
}
errors++;
}
else {
const _errs88 = errors;
for(const key19 in data){
if(!(key19 === "sign_read")){
const err63 = {instancePath,schemaPath:"#/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key19},message:"must NOT have additional properties"};
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
if(_errs88 === errors){
if(data.sign_read !== undefined){
if(!(validate201(data.sign_read, {instancePath:instancePath+"/sign_read",parentData:data,parentDataProperty:"sign_read",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate201.errors : vErrors.concat(validate201.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err64 = {instancePath,schemaPath:"#/oneOf/7/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err64];
}
else {
vErrors.push(err64);
}
errors++;
}
}
var _valid0 = _errs86 === errors;
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
const _errs90 = errors;
if(errors === _errs90){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing20;
if((data.refresh_prepare === undefined) && (missing20 = "refresh_prepare")){
const err65 = {instancePath,schemaPath:"#/oneOf/8/required",keyword:"required",params:{missingProperty: missing20},message:"must have required property '"+missing20+"'"};
if(vErrors === null){
vErrors = [err65];
}
else {
vErrors.push(err65);
}
errors++;
}
else {
const _errs92 = errors;
for(const key20 in data){
if(!(key20 === "refresh_prepare")){
const err66 = {instancePath,schemaPath:"#/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key20},message:"must NOT have additional properties"};
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
if(_errs92 === errors){
if(data.refresh_prepare !== undefined){
let data32 = data.refresh_prepare;
const _errs94 = errors;
let valid23 = false;
let passing2 = null;
const _errs95 = errors;
if(errors === _errs95){
if(data32 && typeof data32 == "object" && !Array.isArray(data32)){
let missing21;
if((data32.follow === undefined) && (missing21 = "follow")){
const err67 = {instancePath:instancePath+"/refresh_prepare",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/0/required",keyword:"required",params:{missingProperty: missing21},message:"must have required property '"+missing21+"'"};
if(vErrors === null){
vErrors = [err67];
}
else {
vErrors.push(err67);
}
errors++;
}
else {
const _errs97 = errors;
for(const key21 in data32){
if(!(key21 === "follow")){
const err68 = {instancePath:instancePath+"/refresh_prepare",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key21},message:"must NOT have additional properties"};
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
if(_errs97 === errors){
if(data32.follow !== undefined){
let data33 = data32.follow;
const _errs98 = errors;
if(errors === _errs98){
if(data33 && typeof data33 == "object" && !Array.isArray(data33)){
let missing22;
if((((((data33.session === undefined) && (missing22 = "session")) || ((data33.expected === undefined) && (missing22 = "expected"))) || ((data33.template === undefined) && (missing22 = "template"))) || ((data33.captures === undefined) && (missing22 = "captures"))) || ((data33.limit === undefined) && (missing22 = "limit"))){
const err69 = {instancePath:instancePath+"/refresh_prepare/follow",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/0/properties/follow/required",keyword:"required",params:{missingProperty: missing22},message:"must have required property '"+missing22+"'"};
if(vErrors === null){
vErrors = [err69];
}
else {
vErrors.push(err69);
}
errors++;
}
else {
const _errs100 = errors;
for(const key22 in data33){
if(!(((((key22 === "session") || (key22 === "expected")) || (key22 === "template")) || (key22 === "captures")) || (key22 === "limit"))){
const err70 = {instancePath:instancePath+"/refresh_prepare/follow",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/0/properties/follow/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key22},message:"must NOT have additional properties"};
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
if(_errs100 === errors){
if(data33.session !== undefined){
const _errs101 = errors;
if(!(validate373(data33.session, {instancePath:instancePath+"/refresh_prepare/follow/session",parentData:data33,parentDataProperty:"session",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate373.errors : vErrors.concat(validate373.errors);
errors = vErrors.length;
}
var valid25 = _errs101 === errors;
}
else {
var valid25 = true;
}
if(valid25){
if(data33.expected !== undefined){
const _errs102 = errors;
if(!(validate56(data33.expected, {instancePath:instancePath+"/refresh_prepare/follow/expected",parentData:data33,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid25 = _errs102 === errors;
}
else {
var valid25 = true;
}
if(valid25){
if(data33.template !== undefined){
const _errs103 = errors;
if(!(validate225(data33.template, {instancePath:instancePath+"/refresh_prepare/follow/template",parentData:data33,parentDataProperty:"template",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
errors = vErrors.length;
}
var valid25 = _errs103 === errors;
}
else {
var valid25 = true;
}
if(valid25){
if(data33.captures !== undefined){
let data37 = data33.captures;
const _errs104 = errors;
if(errors === _errs104){
if(Array.isArray(data37)){
if(data37.length > 8){
const err71 = {instancePath:instancePath+"/refresh_prepare/follow/captures",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/0/properties/follow/properties/captures/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err71];
}
else {
vErrors.push(err71);
}
errors++;
}
else {
if(data37.length < 8){
const err72 = {instancePath:instancePath+"/refresh_prepare/follow/captures",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/0/properties/follow/properties/captures/minItems",keyword:"minItems",params:{limit: 8},message:"must NOT have fewer than 8 items"};
if(vErrors === null){
vErrors = [err72];
}
else {
vErrors.push(err72);
}
errors++;
}
else {
var valid26 = true;
const len0 = data37.length;
for(let i0=0; i0<len0; i0++){
const _errs106 = errors;
if(!(validate225(data37[i0], {instancePath:instancePath+"/refresh_prepare/follow/captures/" + i0,parentData:data37,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
errors = vErrors.length;
}
var valid26 = _errs106 === errors;
if(!valid26){
break;
}
}
}
}
}
else {
const err73 = {instancePath:instancePath+"/refresh_prepare/follow/captures",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/0/properties/follow/properties/captures/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err73];
}
else {
vErrors.push(err73);
}
errors++;
}
}
var valid25 = _errs104 === errors;
}
else {
var valid25 = true;
}
if(valid25){
if(data33.limit !== undefined){
const _errs107 = errors;
if(!(validate65(data33.limit, {instancePath:instancePath+"/refresh_prepare/follow/limit",parentData:data33,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
errors = vErrors.length;
}
var valid25 = _errs107 === errors;
}
else {
var valid25 = true;
}
}
}
}
}
}
}
}
else {
const err74 = {instancePath:instancePath+"/refresh_prepare/follow",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/0/properties/follow/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err75 = {instancePath:instancePath+"/refresh_prepare",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err75];
}
else {
vErrors.push(err75);
}
errors++;
}
}
var _valid2 = _errs95 === errors;
if(_valid2){
valid23 = true;
passing2 = 0;
var props2 = true;
}
const _errs108 = errors;
if(errors === _errs108){
if(data32 && typeof data32 == "object" && !Array.isArray(data32)){
let missing23;
if((data32.invalidate === undefined) && (missing23 = "invalidate")){
const err76 = {instancePath:instancePath+"/refresh_prepare",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/1/required",keyword:"required",params:{missingProperty: missing23},message:"must have required property '"+missing23+"'"};
if(vErrors === null){
vErrors = [err76];
}
else {
vErrors.push(err76);
}
errors++;
}
else {
const _errs110 = errors;
for(const key23 in data32){
if(!(key23 === "invalidate")){
const err77 = {instancePath:instancePath+"/refresh_prepare",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key23},message:"must NOT have additional properties"};
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
if(_errs110 === errors){
if(data32.invalidate !== undefined){
if(!(validate398(data32.invalidate, {instancePath:instancePath+"/refresh_prepare/invalidate",parentData:data32,parentDataProperty:"invalidate",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate398.errors : vErrors.concat(validate398.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err78 = {instancePath:instancePath+"/refresh_prepare",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err78];
}
else {
vErrors.push(err78);
}
errors++;
}
}
var _valid2 = _errs108 === errors;
if(_valid2 && valid23){
valid23 = false;
passing2 = [passing2, 1];
}
else {
if(_valid2){
valid23 = true;
passing2 = 1;
if(props2 !== true){
props2 = true;
}
}
const _errs112 = errors;
if(errors === _errs112){
if(data32 && typeof data32 == "object" && !Array.isArray(data32)){
let missing24;
if((data32.acknowledged === undefined) && (missing24 = "acknowledged")){
const err79 = {instancePath:instancePath+"/refresh_prepare",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/2/required",keyword:"required",params:{missingProperty: missing24},message:"must have required property '"+missing24+"'"};
if(vErrors === null){
vErrors = [err79];
}
else {
vErrors.push(err79);
}
errors++;
}
else {
const _errs114 = errors;
for(const key24 in data32){
if(!(key24 === "acknowledged")){
const err80 = {instancePath:instancePath+"/refresh_prepare",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key24},message:"must NOT have additional properties"};
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
if(_errs114 === errors){
if(data32.acknowledged !== undefined){
let data41 = data32.acknowledged;
const _errs115 = errors;
if(errors === _errs115){
if(data41 && typeof data41 == "object" && !Array.isArray(data41)){
let missing25;
if(((data41.selection === undefined) && (missing25 = "selection")) || ((data41.namespace === undefined) && (missing25 = "namespace"))){
const err81 = {instancePath:instancePath+"/refresh_prepare/acknowledged",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/2/properties/acknowledged/required",keyword:"required",params:{missingProperty: missing25},message:"must have required property '"+missing25+"'"};
if(vErrors === null){
vErrors = [err81];
}
else {
vErrors.push(err81);
}
errors++;
}
else {
const _errs117 = errors;
for(const key25 in data41){
if(!((key25 === "selection") || (key25 === "namespace"))){
const err82 = {instancePath:instancePath+"/refresh_prepare/acknowledged",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/2/properties/acknowledged/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key25},message:"must NOT have additional properties"};
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
if(_errs117 === errors){
if(data41.selection !== undefined){
const _errs118 = errors;
if(!(validate398(data41.selection, {instancePath:instancePath+"/refresh_prepare/acknowledged/selection",parentData:data41,parentDataProperty:"selection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate398.errors : vErrors.concat(validate398.errors);
errors = vErrors.length;
}
var valid29 = _errs118 === errors;
}
else {
var valid29 = true;
}
if(valid29){
if(data41.namespace !== undefined){
const _errs119 = errors;
if(!(validate225(data41.namespace, {instancePath:instancePath+"/refresh_prepare/acknowledged/namespace",parentData:data41,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
errors = vErrors.length;
}
var valid29 = _errs119 === errors;
}
else {
var valid29 = true;
}
}
}
}
}
else {
const err83 = {instancePath:instancePath+"/refresh_prepare/acknowledged",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/2/properties/acknowledged/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err84 = {instancePath:instancePath+"/refresh_prepare",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err84];
}
else {
vErrors.push(err84);
}
errors++;
}
}
var _valid2 = _errs112 === errors;
if(_valid2 && valid23){
valid23 = false;
passing2 = [passing2, 2];
}
else {
if(_valid2){
valid23 = true;
passing2 = 2;
if(props2 !== true){
props2 = true;
}
}
const _errs120 = errors;
if(errors === _errs120){
if(data32 && typeof data32 == "object" && !Array.isArray(data32)){
let missing26;
if((data32.pause === undefined) && (missing26 = "pause")){
const err85 = {instancePath:instancePath+"/refresh_prepare",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/3/required",keyword:"required",params:{missingProperty: missing26},message:"must have required property '"+missing26+"'"};
if(vErrors === null){
vErrors = [err85];
}
else {
vErrors.push(err85);
}
errors++;
}
else {
const _errs122 = errors;
for(const key26 in data32){
if(!(key26 === "pause")){
const err86 = {instancePath:instancePath+"/refresh_prepare",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key26},message:"must NOT have additional properties"};
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
if(_errs122 === errors){
if(data32.pause !== undefined){
if(!(validate398(data32.pause, {instancePath:instancePath+"/refresh_prepare/pause",parentData:data32,parentDataProperty:"pause",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate398.errors : vErrors.concat(validate398.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err87 = {instancePath:instancePath+"/refresh_prepare",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err87];
}
else {
vErrors.push(err87);
}
errors++;
}
}
var _valid2 = _errs120 === errors;
if(_valid2 && valid23){
valid23 = false;
passing2 = [passing2, 3];
}
else {
if(_valid2){
valid23 = true;
passing2 = 3;
if(props2 !== true){
props2 = true;
}
}
}
}
}
if(!valid23){
const err88 = {instancePath:instancePath+"/refresh_prepare",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf",keyword:"oneOf",params:{passingSchemas: passing2},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err88];
}
else {
vErrors.push(err88);
}
errors++;
}
else {
errors = _errs94;
if(vErrors !== null){
if(_errs94){
vErrors.length = _errs94;
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
var _valid0 = _errs90 === errors;
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
const _errs124 = errors;
if(errors === _errs124){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing27;
if((data.refresh_status === undefined) && (missing27 = "refresh_status")){
const err90 = {instancePath,schemaPath:"#/oneOf/9/required",keyword:"required",params:{missingProperty: missing27},message:"must have required property '"+missing27+"'"};
if(vErrors === null){
vErrors = [err90];
}
else {
vErrors.push(err90);
}
errors++;
}
else {
const _errs126 = errors;
for(const key27 in data){
if(!(key27 === "refresh_status")){
const err91 = {instancePath,schemaPath:"#/oneOf/9/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key27},message:"must NOT have additional properties"};
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
if(_errs126 === errors){
if(data.refresh_status !== undefined){
if(!(validate398(data.refresh_status, {instancePath:instancePath+"/refresh_status",parentData:data,parentDataProperty:"refresh_status",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate398.errors : vErrors.concat(validate398.errors);
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
var _valid0 = _errs124 === errors;
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
validate366.errors = vErrors;
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
validate366.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate366.evaluated = {"dynamicProps":true,"dynamicItems":false};

export const HostResponse = validate406;
const schema106 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["description"],"properties":{"description":{"type":"object","additionalProperties":false,"properties":{"connection":{"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"principal":{"$ref":"https://transit.invalid/generated-validator/1"},"service":{"$ref":"https://transit.invalid/generated-validator/1"},"ingress":{"$ref":"https://transit.invalid/generated-validator/1"},"role":{"$ref":"https://transit.invalid/generated-validator/2"}},"required":["realm","principal","service","ingress"]},"discovery":{"$ref":"https://transit.invalid/generated-validator/72"},"observed_ms":{"$ref":"https://transit.invalid/generated-validator/1"},"max_lease_ms":{"$ref":"https://transit.invalid/generated-validator/67"}},"required":["connection","discovery","observed_ms"]}}},{"type":"object","additionalProperties":false,"required":["clock"],"properties":{"clock":{"type":"object","additionalProperties":false,"properties":{"observed_ms":{"$ref":"https://transit.invalid/generated-validator/1"},"max_lease_ms":{"$ref":"https://transit.invalid/generated-validator/67"}},"required":["observed_ms"]}}},{"type":"object","additionalProperties":false,"required":["inspection"],"properties":{"inspection":{"type":"object","additionalProperties":false,"properties":{"response":{"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"session":{"$ref":"https://transit.invalid/generated-validator/50"},"source":{"$ref":"https://transit.invalid/generated-validator/52"},"snapshot":{"$ref":"https://transit.invalid/generated-validator/65"},"event":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"source_changed":{"type":"boolean"},"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"data_revision":{"$ref":"https://transit.invalid/generated-validator/44"},"outcome":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"operation":{"$ref":"https://transit.invalid/generated-validator/1"},"phase":{"$ref":"https://transit.invalid/generated-validator/36"},"resolution_input":{"$ref":"https://transit.invalid/generated-validator/1"},"diagnostic":{"$ref":"https://transit.invalid/generated-validator/87"}},"required":["resource","operation","phase","resolution_input"]},{"type":"null"}]}},"required":["source_changed","resource","data_revision"]},{"type":"null"}]},"cursor":{"$ref":"https://transit.invalid/generated-validator/47"}},"required":["session"]},"observation":{"$ref":"https://transit.invalid/generated-validator/58"}},"required":["response","observation"]}}},{"type":"object","additionalProperties":false,"required":["covered"],"properties":{"covered":{"type":"boolean"}}},{"type":"object","additionalProperties":false,"required":["prepared"],"properties":{"prepared":{"$ref":"https://transit.invalid/generated-validator/66"}}},{"$ref":"https://transit.invalid/generated-validator/69"},{"type":"object","additionalProperties":false,"required":["observation"],"properties":{"observation":{"oneOf":[{"type":"object","additionalProperties":false,"required":["pending"],"properties":{"pending":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["committed"],"properties":{"committed":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["rejected"],"properties":{"rejected":{"type":"object","additionalProperties":false,"properties":{"record":{"$ref":"https://transit.invalid/generated-validator/39"},"diagnostic":{"$ref":"https://transit.invalid/generated-validator/87"}},"required":["record","diagnostic"]}}}]}}},{"type":"object","additionalProperties":false,"required":["signed_read"],"properties":{"signed_read":{"type":"object","additionalProperties":false,"properties":{"read":{"$ref":"https://transit.invalid/generated-validator/48"},"proof":{"$ref":"https://transit.invalid/generated-validator/88"}},"required":["read","proof"]}}},{"type":"object","additionalProperties":false,"required":["refresh_status"],"properties":{"refresh_status":{"type":"object","additionalProperties":false,"properties":{"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"revision":{"$ref":"https://transit.invalid/generated-validator/1"},"policy_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"view":{"type":"object","additionalProperties":false,"properties":{"principal":{"$ref":"https://transit.invalid/generated-validator/1"},"session":{"$ref":"https://transit.invalid/generated-validator/70"},"generation":{"$ref":"https://transit.invalid/generated-validator/1"},"source":{"$ref":"https://transit.invalid/generated-validator/51"},"template":{"$ref":"https://transit.invalid/generated-validator/44"},"namespace":{"$ref":"https://transit.invalid/generated-validator/44"},"dirty":{"$ref":"https://transit.invalid/generated-validator/44"},"covered":{"$ref":"https://transit.invalid/generated-validator/44"},"starts":{"$ref":"https://transit.invalid/generated-validator/3"},"limit":{"$ref":"https://transit.invalid/generated-validator/3"},"next_start_ms":{"$ref":"https://transit.invalid/generated-validator/1"},"enabled":{"type":"boolean"},"phase":{"$ref":"https://transit.invalid/generated-validator/89"},"failure":{"oneOf":[{"$ref":"https://transit.invalid/generated-validator/90"},{"type":"object","additionalProperties":false,"required":["stopped"],"properties":{"stopped":{"type":"object","additionalProperties":false,"properties":{"reason":{"type":"string","enum":["paused","budget_exhausted","session_closed","session_expired","source_changed","binding_unpublished","service_denied","native_denied","query_denied","catalog_denied","resource_unavailable","query_source_unavailable","result_unavailable","result_unpublished","template_invalid","upload_closed","namespace_occupied","query_rejected","query_cancelled","query_retired"]},"input":{"$ref":"https://transit.invalid/generated-validator/1"},"witness":{"oneOf":[{"$ref":"https://transit.invalid/generated-validator/90"},{"type":"object","additionalProperties":false,"required":["revision"],"properties":{"revision":{"type":"object","additionalProperties":false,"properties":{"kind":{"type":"string","enum":["binding","policy","watch","refresh"]},"expected":{"$ref":"https://transit.invalid/generated-validator/1"},"actual":{"$ref":"https://transit.invalid/generated-validator/1"},"proposed":{"$ref":"https://transit.invalid/generated-validator/1"},"present":{"type":"boolean"}},"required":["kind","expected","actual","proposed","present"]}}},{"type":"object","additionalProperties":false,"required":["policy"],"properties":{"policy":{"type":"object","additionalProperties":false,"properties":{"principal":{"$ref":"https://transit.invalid/generated-validator/1"},"revision":{"$ref":"https://transit.invalid/generated-validator/1"},"present":{"type":"boolean"},"commands":{"type":"boolean"},"reads":{"type":"boolean"}},"required":["principal","revision","present","commands","reads"]}}},{"type":"object","additionalProperties":false,"required":["identity"],"properties":{"identity":{"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/4"},"actual":{"$ref":"https://transit.invalid/generated-validator/4"}},"required":["expected","actual"]}}},{"type":"object","additionalProperties":false,"required":["capacity"],"properties":{"capacity":{"type":"object","additionalProperties":false,"properties":{"kind":{"type":"string","enum":["service","caller","service_slots","sessions","caller_sessions"]},"actual":{"$ref":"https://transit.invalid/generated-validator/3"},"limit":{"$ref":"https://transit.invalid/generated-validator/3"}},"required":["kind","actual","limit"]}}},{"type":"object","additionalProperties":false,"required":["generation"],"properties":{"generation":{"$ref":"https://transit.invalid/generated-validator/91"}}},{"type":"object","additionalProperties":false,"required":["session"],"properties":{"session":{"type":"object","additionalProperties":false,"properties":{"phase":{"$ref":"https://transit.invalid/generated-validator/49"},"deadline":{"$ref":"https://transit.invalid/generated-validator/1"},"observed":{"$ref":"https://transit.invalid/generated-validator/1"},"clock_known":{"type":"boolean"}},"required":["phase","deadline","observed","clock_known"]}}},{"type":"object","additionalProperties":false,"required":["source"],"properties":{"source":{"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/1"},"actual":{"$ref":"https://transit.invalid/generated-validator/1"},"present":{"type":"boolean"},"published":{"type":"boolean"},"target":{"$ref":"https://transit.invalid/generated-validator/1"},"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"metadata":{"$ref":"https://transit.invalid/generated-validator/4"}},"required":["expected","actual","present","published","target","resource","metadata"]}}},{"type":"object","additionalProperties":false,"required":["lease"],"properties":{"lease":{"type":"object","additionalProperties":false,"properties":{"kind":{"type":"string","enum":["clock","interval","binding","process","resource","observer"]},"requested":{"$ref":"https://transit.invalid/generated-validator/1"},"observed":{"$ref":"https://transit.invalid/generated-validator/1"},"limit":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["kind","requested","observed","limit"]}}},{"type":"object","additionalProperties":false,"required":["attachment"],"properties":{"attachment":{"$ref":"https://transit.invalid/generated-validator/91"}}},{"type":"object","additionalProperties":false,"required":["subscription"],"properties":{"subscription":{"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/1"},"actual":{"$ref":"https://transit.invalid/generated-validator/1"},"requested":{"$ref":"https://transit.invalid/generated-validator/1"},"active":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["expected","actual","requested","active"]}}},{"type":"object","additionalProperties":false,"required":["renewal"],"properties":{"renewal":{"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/1"},"actual":{"$ref":"https://transit.invalid/generated-validator/1"},"proposed":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["expected","actual","proposed"]}}},{"type":"object","additionalProperties":false,"required":["binding"],"properties":{"binding":{"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/1"},"actual":{"$ref":"https://transit.invalid/generated-validator/1"},"expected_codec":{"$ref":"https://transit.invalid/generated-validator/35"},"actual_codec":{"$ref":"https://transit.invalid/generated-validator/35"},"target":{"$ref":"https://transit.invalid/generated-validator/1"},"present":{"type":"boolean"},"published":{"type":"boolean"}},"required":["expected","actual","expected_codec","actual_codec","target","present","published"]}}},{"type":"object","additionalProperties":false,"required":["refresh"],"properties":{"refresh":{"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/44"},"actual":{"$ref":"https://transit.invalid/generated-validator/44"},"phase":{"$ref":"https://transit.invalid/generated-validator/89"}},"required":["expected","actual","phase"]}}},{"type":"object","additionalProperties":false,"required":["frame"],"properties":{"frame":{"type":"object","additionalProperties":false,"properties":{"correlation":{"$ref":"https://transit.invalid/generated-validator/1"},"expected":{"$ref":"https://transit.invalid/generated-validator/1"},"actual":{"$ref":"https://transit.invalid/generated-validator/1"},"kind":{"type":"string","enum":["reply_source","observer","timer","administrator"]},"actual_known":{"type":"boolean"}},"required":["correlation","expected","actual","kind"]}}},{"type":"object","additionalProperties":false,"required":["target"],"properties":{"target":{"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/1"},"actual":{"$ref":"https://transit.invalid/generated-validator/1"},"kind":{"type":"string","enum":["source","resource","partition"]}},"required":["expected","actual","kind"]}}},{"type":"object","additionalProperties":false,"required":["basis"],"properties":{"basis":{"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/4"},"actual":{"$ref":"https://transit.invalid/generated-validator/4"},"kind":{"type":"string","enum":["schema","contract","metadata"]}},"required":["expected","actual","kind"]}}},{"type":"object","additionalProperties":false,"required":["source_kind"],"properties":{"source_kind":{"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/92"},"actual":{"$ref":"https://transit.invalid/generated-validator/92"}},"required":["expected","actual"]}}},{"type":"object","additionalProperties":false,"required":["table"],"properties":{"table":{"$ref":"https://transit.invalid/generated-validator/44"}}},{"type":"object","additionalProperties":false,"required":["watch_type"],"properties":{"watch_type":{"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/93"},"actual":{"$ref":"https://transit.invalid/generated-validator/93"},"column":{"$ref":"https://transit.invalid/generated-validator/3"}},"required":["expected","actual"]}}},{"type":"object","additionalProperties":false,"required":["progress"],"properties":{"progress":{"type":"object","additionalProperties":false,"properties":{"present":{"type":"boolean"},"actual":{"$ref":"https://transit.invalid/generated-validator/1"},"limit":{"$ref":"https://transit.invalid/generated-validator/1"},"key":{"$ref":"https://transit.invalid/generated-validator/4"},"length":{"$ref":"https://transit.invalid/generated-validator/3"}},"required":["present","actual","limit","key","length"]}}},{"type":"object","additionalProperties":false,"required":["reader_identity"],"properties":{"reader_identity":{"type":"object","additionalProperties":false,"properties":{"field":{"type":"string","enum":["principal","pid","permissions","turn_pid"]},"expected":{"$ref":"https://transit.invalid/generated-validator/1"},"actual":{"$ref":"https://transit.invalid/generated-validator/1"},"present":{"type":"boolean"},"policy_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"policy_known":{"type":"boolean"}},"required":["field","expected","actual"]}}},{"type":"object","additionalProperties":false,"required":["reader_failure"],"properties":{"reader_failure":{"type":"object","additionalProperties":false,"properties":{"operation":{"type":"string","enum":["identity","source","requester","result"]},"principal":{"$ref":"https://transit.invalid/generated-validator/1"},"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"namespace":{"$ref":"https://transit.invalid/generated-validator/1"},"cause":{"type":"string","enum":["AccessDenied","Forbidden","StateResourceExpired","UnknownStateResource","DeadlineExpired","RetiredProcess","CatalogDenied","QueryDenied","QuerySourceUnavailable","ResultUnavailable","PublicationNotPublished"]}},"required":["operation","principal","resource","cause"]}}},{"type":"object","additionalProperties":false,"required":["reader_resource"],"properties":{"reader_resource":{"type":"object","additionalProperties":false,"properties":{"role":{"type":"string","enum":["source","requester"]},"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"expected_writer":{"$ref":"https://transit.invalid/generated-validator/1"},"actual_writer":{"$ref":"https://transit.invalid/generated-validator/1"},"phase":{"type":"string","enum":["active","retired","reclaimed"]},"writer_check":{"type":"boolean"},"revision":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["role","resource","expected_writer","actual_writer","phase","writer_check","revision"]}}},{"type":"object","additionalProperties":false,"required":["watch_shape"],"properties":{"watch_shape":{"type":"object","additionalProperties":false,"properties":{"columns":{"$ref":"https://transit.invalid/generated-validator/3"},"first_nullable":{"type":"boolean"},"primary_columns":{"$ref":"https://transit.invalid/generated-validator/3"},"primary_first":{"type":"boolean"}},"required":["columns","first_nullable","primary_columns","primary_first"]}}},{"type":"object","additionalProperties":false,"required":["reader_template"],"properties":{"reader_template":{"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"https://transit.invalid/generated-validator/1"},"present":{"type":"boolean"},"phase":{"type":"string","enum":["uploading","sealed","admitted","complete","cancelled","denied","rejected","retired","prepared"]},"manifest":{"type":"boolean"}},"required":["namespace","present"]}}}]}},"required":["reason","input"]}}}]}},"required":["principal","session","generation","source","template","namespace","dirty","covered","limit"]},"diagnostic":{"$ref":"https://transit.invalid/generated-validator/87"},"query_diagnostic":{"$ref":"https://transit.invalid/generated-validator/87"}},"required":["resource","revision","policy_revision","view"]}}}]};
const schema107 = {"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"service":{"$ref":"https://transit.invalid/generated-validator/1"},"ingress":{"$ref":"https://transit.invalid/generated-validator/1"},"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"binding_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"watch_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"sse":{"type":"boolean"},"websocket":{"type":"boolean"},"subprotocol":{"type":"string","maxLength":256},"openapi_sha256":{"$ref":"https://transit.invalid/generated-validator/4"},"asyncapi_sha256":{"$ref":"https://transit.invalid/generated-validator/4"}},"required":["service","ingress","resource","binding_revision","watch_revision","openapi_sha256","asyncapi_sha256"]};

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
if((((((((data.service === undefined) && (missing0 = "service")) || ((data.ingress === undefined) && (missing0 = "ingress"))) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.binding_revision === undefined) && (missing0 = "binding_revision"))) || ((data.watch_revision === undefined) && (missing0 = "watch_revision"))) || ((data.openapi_sha256 === undefined) && (missing0 = "openapi_sha256"))) || ((data.asyncapi_sha256 === undefined) && (missing0 = "asyncapi_sha256"))){
validate412.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema107.properties, key0))){
validate412.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate412.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"}];
return false;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.service !== undefined){
const _errs3 = errors;
if(!(validate56(data.service, {instancePath:instancePath+"/service",parentData:data,parentDataProperty:"service",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.ingress !== undefined){
const _errs4 = errors;
if(!(validate56(data.ingress, {instancePath:instancePath+"/ingress",parentData:data,parentDataProperty:"ingress",rootData,dynamicAnchors}))){
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
if(data.binding_revision !== undefined){
const _errs6 = errors;
if(!(validate56(data.binding_revision, {instancePath:instancePath+"/binding_revision",parentData:data,parentDataProperty:"binding_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.watch_revision !== undefined){
const _errs7 = errors;
if(!(validate56(data.watch_revision, {instancePath:instancePath+"/watch_revision",parentData:data,parentDataProperty:"watch_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.sse !== undefined){
const _errs8 = errors;
if(typeof data.sse !== "boolean"){
validate412.errors = [{instancePath:instancePath+"/sse",schemaPath:"#/properties/sse/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.websocket !== undefined){
const _errs10 = errors;
if(typeof data.websocket !== "boolean"){
validate412.errors = [{instancePath:instancePath+"/websocket",schemaPath:"#/properties/websocket/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs10 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.subprotocol !== undefined){
let data8 = data.subprotocol;
const _errs12 = errors;
if(errors === _errs12){
if(typeof data8 === "string"){
if(func2(data8) > 256){
validate412.errors = [{instancePath:instancePath+"/subprotocol",schemaPath:"#/properties/subprotocol/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"}];
return false;
}
}
else {
validate412.errors = [{instancePath:instancePath+"/subprotocol",schemaPath:"#/properties/subprotocol/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs12 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.openapi_sha256 !== undefined){
const _errs14 = errors;
if(!(validate64(data.openapi_sha256, {instancePath:instancePath+"/openapi_sha256",parentData:data,parentDataProperty:"openapi_sha256",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
errors = vErrors.length;
}
var valid0 = _errs14 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.asyncapi_sha256 !== undefined){
const _errs15 = errors;
if(!(validate64(data.asyncapi_sha256, {instancePath:instancePath+"/asyncapi_sha256",parentData:data,parentDataProperty:"asyncapi_sha256",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
errors = vErrors.length;
}
var valid0 = _errs15 === errors;
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
validate412.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate412.errors = vErrors;
return errors === 0;
}
validate412.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema108 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/86"},{"type":"null"}]};
const schema109 = {"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"definition":{"$ref":"https://transit.invalid/generated-validator/0"},"code":{"type":"string","maxLength":96},"category":{"$ref":"https://transit.invalid/generated-validator/7"},"stage":{"$ref":"https://transit.invalid/generated-validator/8"},"outcome":{"$ref":"https://transit.invalid/generated-validator/9"},"evidence":{"$ref":"https://transit.invalid/generated-validator/10"},"message":{"type":"string","maxLength":384},"cause":{"$ref":"https://transit.invalid/generated-validator/11"},"identity":{"$ref":"https://transit.invalid/generated-validator/74"},"location":{"$ref":"https://transit.invalid/generated-validator/76"},"facts":{"$ref":"https://transit.invalid/generated-validator/82"},"actions":{"$ref":"https://transit.invalid/generated-validator/85"}},"required":["version","definition","code","category","stage","outcome","evidence","message"]};
const schema110 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/73"},{"type":"null"}]};
const schema111 = {"type":"object","additionalProperties":false,"properties":{"domain":{"$ref":"https://transit.invalid/generated-validator/12"},"id":{"$ref":"https://transit.invalid/generated-validator/13"},"realm":{"$ref":"https://transit.invalid/generated-validator/14"},"resource":{"$ref":"https://transit.invalid/generated-validator/14"},"sequence":{"$ref":"https://transit.invalid/generated-validator/14"}},"required":["domain","id"]};

function validate443(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate443.evaluated;
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
validate443.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "domain") || (key0 === "id")) || (key0 === "realm")) || (key0 === "resource")) || (key0 === "sequence"))){
validate443.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.domain !== undefined){
const _errs2 = errors;
if(!(validate86(data.domain, {instancePath:instancePath+"/domain",parentData:data,parentDataProperty:"domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate86.errors : vErrors.concat(validate86.errors);
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
if(!(validate88(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate88.errors : vErrors.concat(validate88.errors);
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
if(!(validate90(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate90.errors : vErrors.concat(validate90.errors);
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
if(!(validate90(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate90.errors : vErrors.concat(validate90.errors);
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
if(!(validate90(data.sequence, {instancePath:instancePath+"/sequence",parentData:data,parentDataProperty:"sequence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate90.errors : vErrors.concat(validate90.errors);
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
validate443.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate443.errors = vErrors;
return errors === 0;
}
validate443.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate443(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate443.errors : vErrors.concat(validate443.errors);
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
validate442.errors = vErrors;
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
validate442.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate442.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema112 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/75"},{"type":"null"}]};
const schema113 = {"type":"object","additionalProperties":false,"properties":{"source":{"$ref":"https://transit.invalid/generated-validator/17"},"source_encoding":{"$ref":"https://transit.invalid/generated-validator/18"},"source_truncated":{"type":"boolean"},"statement":{"$ref":"https://transit.invalid/generated-validator/14"},"offset":{"$ref":"https://transit.invalid/generated-validator/13"},"length":{"$ref":"https://transit.invalid/generated-validator/13"},"line":{"$ref":"https://transit.invalid/generated-validator/13"},"byte_column":{"$ref":"https://transit.invalid/generated-validator/13"}},"required":["offset","length","line","byte_column"]};

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
if(((((data.offset === undefined) && (missing0 = "offset")) || ((data.length === undefined) && (missing0 = "length"))) || ((data.line === undefined) && (missing0 = "line"))) || ((data.byte_column === undefined) && (missing0 = "byte_column"))){
validate452.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "source") || (key0 === "source_encoding")) || (key0 === "source_truncated")) || (key0 === "statement")) || (key0 === "offset")) || (key0 === "length")) || (key0 === "line")) || (key0 === "byte_column"))){
validate452.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.source !== undefined){
const _errs2 = errors;
if(!(validate98(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate98.errors : vErrors.concat(validate98.errors);
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
if(!(validate100(data.source_encoding, {instancePath:instancePath+"/source_encoding",parentData:data,parentDataProperty:"source_encoding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate100.errors : vErrors.concat(validate100.errors);
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
validate452.errors = [{instancePath:instancePath+"/source_truncated",schemaPath:"#/properties/source_truncated/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
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
if(!(validate90(data.statement, {instancePath:instancePath+"/statement",parentData:data,parentDataProperty:"statement",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate90.errors : vErrors.concat(validate90.errors);
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
if(!(validate88(data.offset, {instancePath:instancePath+"/offset",parentData:data,parentDataProperty:"offset",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate88.errors : vErrors.concat(validate88.errors);
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
if(!(validate88(data.length, {instancePath:instancePath+"/length",parentData:data,parentDataProperty:"length",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate88.errors : vErrors.concat(validate88.errors);
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
if(!(validate88(data.line, {instancePath:instancePath+"/line",parentData:data,parentDataProperty:"line",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate88.errors : vErrors.concat(validate88.errors);
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
if(!(validate88(data.byte_column, {instancePath:instancePath+"/byte_column",parentData:data,parentDataProperty:"byte_column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate88.errors : vErrors.concat(validate88.errors);
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
validate452.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate452.errors = vErrors;
return errors === 0;
}
validate452.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate451(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate451.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate452(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate452.errors : vErrors.concat(validate452.errors);
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
validate451.errors = vErrors;
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
validate451.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate451.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema114 = {"type":"array","minItems":16,"maxItems":16,"items":{"$ref":"https://transit.invalid/generated-validator/81"}};
const schema115 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/80"},{"type":"null"}]};
const schema116 = {"type":"object","additionalProperties":false,"properties":{"field":{"$ref":"https://transit.invalid/generated-validator/20"},"origin":{"$ref":"https://transit.invalid/generated-validator/21"},"availability":{"$ref":"https://transit.invalid/generated-validator/22"},"value":{"$ref":"https://transit.invalid/generated-validator/79"}},"required":["field","origin","availability","value"]};
const schema117 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/78"},{"type":"null"}]};
const schema118 = {"oneOf":[{"$ref":"https://transit.invalid/generated-validator/23"},{"$ref":"https://transit.invalid/generated-validator/25"},{"$ref":"https://transit.invalid/generated-validator/26"},{"$ref":"https://transit.invalid/generated-validator/27"},{"$ref":"https://transit.invalid/generated-validator/28"},{"$ref":"https://transit.invalid/generated-validator/77"}]};
const schema119 = {"type":"object","additionalProperties":false,"required":["location"],"properties":{"location":{"$ref":"https://transit.invalid/generated-validator/75"}}};

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
if((data.location === undefined) && (missing0 = "location")){
validate475.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "location")){
validate475.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.location !== undefined){
if(!(validate452(data.location, {instancePath:instancePath+"/location",parentData:data,parentDataProperty:"location",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate452.errors : vErrors.concat(validate452.errors);
errors = vErrors.length;
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
const _errs0 = errors;
let valid0 = false;
let passing0 = null;
const _errs1 = errors;
if(!(validate114(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate114.errors : vErrors.concat(validate114.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs2 = errors;
if(!(validate116(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate116.errors : vErrors.concat(validate116.errors);
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
const _errs4 = errors;
if(!(validate123(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate123.errors : vErrors.concat(validate123.errors);
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
if(!(validate125(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate125.errors : vErrors.concat(validate125.errors);
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
if(!(validate475(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate475.errors : vErrors.concat(validate475.errors);
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
validate469.errors = vErrors;
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
validate469.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate469.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate468(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate468.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate469(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate469.errors : vErrors.concat(validate469.errors);
errors = vErrors.length;
}
else {
var props0 = validate469.evaluated.props;
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
validate468.errors = vErrors;
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
validate468.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate468.evaluated = {"dynamicProps":true,"dynamicItems":false};


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
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.field === undefined) && (missing0 = "field")) || ((data.origin === undefined) && (missing0 = "origin"))) || ((data.availability === undefined) && (missing0 = "availability"))) || ((data.value === undefined) && (missing0 = "value"))){
validate464.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "field") || (key0 === "origin")) || (key0 === "availability")) || (key0 === "value"))){
validate464.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.field !== undefined){
const _errs2 = errors;
if(!(validate108(data.field, {instancePath:instancePath+"/field",parentData:data,parentDataProperty:"field",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate108.errors : vErrors.concat(validate108.errors);
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
if(!(validate110(data.origin, {instancePath:instancePath+"/origin",parentData:data,parentDataProperty:"origin",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate110.errors : vErrors.concat(validate110.errors);
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
if(!(validate112(data.availability, {instancePath:instancePath+"/availability",parentData:data,parentDataProperty:"availability",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate112.errors : vErrors.concat(validate112.errors);
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
if(!(validate468(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate468.errors : vErrors.concat(validate468.errors);
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
validate464.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate464.errors = vErrors;
return errors === 0;
}
validate464.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate463(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate463.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate464(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate464.errors : vErrors.concat(validate464.errors);
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
validate463.errors = vErrors;
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
validate463.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate463.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate462(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate462.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 16){
validate462.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
if(data.length < 16){
validate462.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate463(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate463.errors : vErrors.concat(validate463.errors);
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
validate462.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate462.errors = vErrors;
return errors === 0;
}
validate462.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema120 = {"type":"array","minItems":4,"maxItems":4,"items":{"$ref":"https://transit.invalid/generated-validator/84"}};
const schema121 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/83"},{"type":"null"}]};
const schema122 = {"type":"object","additionalProperties":false,"properties":{"kind":{"$ref":"https://transit.invalid/generated-validator/29"},"target":{"$ref":"https://transit.invalid/generated-validator/74"}},"required":["kind"]};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.kind === undefined) && (missing0 = "kind")){
validate485.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "kind") || (key0 === "target"))){
validate485.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.kind !== undefined){
const _errs2 = errors;
if(!(validate129(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate129.errors : vErrors.concat(validate129.errors);
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
if(!(validate442(data.target, {instancePath:instancePath+"/target",parentData:data,parentDataProperty:"target",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate442.errors : vErrors.concat(validate442.errors);
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
validate485.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate485.errors = vErrors;
return errors === 0;
}
validate485.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate484(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate484.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate485(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate485.errors : vErrors.concat(validate485.errors);
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
validate484.errors = vErrors;
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
validate484.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate484.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate483(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate483.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 4){
validate483.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 4},message:"must NOT have more than 4 items"}];
return false;
}
else {
if(data.length < 4){
validate483.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 4},message:"must NOT have fewer than 4 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate484(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate484.errors : vErrors.concat(validate484.errors);
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
validate483.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate483.errors = vErrors;
return errors === 0;
}
validate483.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((((data.version === undefined) && (missing0 = "version")) || ((data.definition === undefined) && (missing0 = "definition"))) || ((data.code === undefined) && (missing0 = "code"))) || ((data.category === undefined) && (missing0 = "category"))) || ((data.stage === undefined) && (missing0 = "stage"))) || ((data.outcome === undefined) && (missing0 = "outcome"))) || ((data.evidence === undefined) && (missing0 = "evidence"))) || ((data.message === undefined) && (missing0 = "message"))){
validate435.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema109.properties, key0))){
validate435.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate435.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"}];
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
if(!(validate54(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
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
validate435.errors = [{instancePath:instancePath+"/code",schemaPath:"#/properties/code/maxLength",keyword:"maxLength",params:{limit: 96},message:"must NOT have more than 96 characters"}];
return false;
}
}
else {
validate435.errors = [{instancePath:instancePath+"/code",schemaPath:"#/properties/code/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
if(!(validate74(data.category, {instancePath:instancePath+"/category",parentData:data,parentDataProperty:"category",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate74.errors : vErrors.concat(validate74.errors);
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
if(!(validate76(data.stage, {instancePath:instancePath+"/stage",parentData:data,parentDataProperty:"stage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate76.errors : vErrors.concat(validate76.errors);
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
if(!(validate78(data.outcome, {instancePath:instancePath+"/outcome",parentData:data,parentDataProperty:"outcome",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate78.errors : vErrors.concat(validate78.errors);
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
if(!(validate80(data.evidence, {instancePath:instancePath+"/evidence",parentData:data,parentDataProperty:"evidence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate80.errors : vErrors.concat(validate80.errors);
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
validate435.errors = [{instancePath:instancePath+"/message",schemaPath:"#/properties/message/maxLength",keyword:"maxLength",params:{limit: 384},message:"must NOT have more than 384 characters"}];
return false;
}
}
else {
validate435.errors = [{instancePath:instancePath+"/message",schemaPath:"#/properties/message/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
if(!(validate82(data.cause, {instancePath:instancePath+"/cause",parentData:data,parentDataProperty:"cause",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate82.errors : vErrors.concat(validate82.errors);
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
if(!(validate442(data.identity, {instancePath:instancePath+"/identity",parentData:data,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate442.errors : vErrors.concat(validate442.errors);
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
if(!(validate451(data.location, {instancePath:instancePath+"/location",parentData:data,parentDataProperty:"location",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate451.errors : vErrors.concat(validate451.errors);
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
if(!(validate462(data.facts, {instancePath:instancePath+"/facts",parentData:data,parentDataProperty:"facts",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate462.errors : vErrors.concat(validate462.errors);
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
if(!(validate483(data.actions, {instancePath:instancePath+"/actions",parentData:data,parentDataProperty:"actions",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate483.errors : vErrors.concat(validate483.errors);
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
validate435.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate435.errors = vErrors;
return errors === 0;
}
validate435.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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

const schema123 = {"type":"object","additionalProperties":false,"properties":{"claim":{"$ref":"https://transit.invalid/generated-validator/5"},"signature":{"$ref":"https://transit.invalid/generated-validator/6"}},"required":["claim","signature"]};

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
if(((data.claim === undefined) && (missing0 = "claim")) || ((data.signature === undefined) && (missing0 = "signature"))){
validate500.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "claim") || (key0 === "signature"))){
validate500.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.claim !== undefined){
const _errs2 = errors;
if(!(validate53(data.claim, {instancePath:instancePath+"/claim",parentData:data,parentDataProperty:"claim",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
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
if(!(validate69(data.signature, {instancePath:instancePath+"/signature",parentData:data,parentDataProperty:"signature",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate69.errors : vErrors.concat(validate69.errors);
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

const schema124 = {"type":"string","enum":["idle","preparing","admitted","ready","paused","denied","exhausted","failed"]};

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
if(!((((((((data === "idle") || (data === "preparing")) || (data === "admitted")) || (data === "ready")) || (data === "paused")) || (data === "denied")) || (data === "exhausted")) || (data === "failed"))){
validate518.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema124.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate518.errors = vErrors;
return errors === 0;
}
validate518.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema125 = {"type":"object","additionalProperties":false,"required":["none"],"properties":{"none":{"type":"object","maxProperties":0}}};

function validate520(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate520.evaluated;
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
validate520.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "none")){
validate520.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
validate520.errors = [{instancePath:instancePath+"/none",schemaPath:"#/properties/none/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"}];
return false;
}
}
else {
validate520.errors = [{instancePath:instancePath+"/none",schemaPath:"#/properties/none/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
}
}
}
}
else {
validate520.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate520.errors = vErrors;
return errors === 0;
}
validate520.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema126 = {"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/1"},"actual":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["expected","actual"]};

function validate533(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate533.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.expected === undefined) && (missing0 = "expected")) || ((data.actual === undefined) && (missing0 = "actual"))){
validate533.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "expected") || (key0 === "actual"))){
validate533.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.expected !== undefined){
const _errs2 = errors;
if(!(validate56(data.expected, {instancePath:instancePath+"/expected",parentData:data,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.actual !== undefined){
const _errs3 = errors;
if(!(validate56(data.actual, {instancePath:instancePath+"/actual",parentData:data,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
validate533.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate533.errors = vErrors;
return errors === 0;
}
validate533.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema127 = {"type":"string","enum":["kv","table","document"]};

function validate571(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate571.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate571.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((data === "kv") || (data === "table")) || (data === "document"))){
validate571.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema127.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate571.errors = vErrors;
return errors === 0;
}
validate571.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema128 = {"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary","int8","int16","int32","int128","uint8","uint16","uint32","uint128","float32","decimal","date","time","timestamp","interval","uuid","structure","list","array","map","tagged_union","json"]};

function validate575(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate575.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate575.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((((((((((((((((((data === "int64") || (data === "uint64")) || (data === "float64")) || (data === "boolean")) || (data === "utf8")) || (data === "binary")) || (data === "int8")) || (data === "int16")) || (data === "int32")) || (data === "int128")) || (data === "uint8")) || (data === "uint16")) || (data === "uint32")) || (data === "uint128")) || (data === "float32")) || (data === "decimal")) || (data === "date")) || (data === "time")) || (data === "timestamp")) || (data === "interval")) || (data === "uuid")) || (data === "structure")) || (data === "list")) || (data === "array")) || (data === "map")) || (data === "tagged_union")) || (data === "json"))){
validate575.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema128.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate575.errors = vErrors;
return errors === 0;
}
validate575.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if((((data0.connection === undefined) && (missing1 = "connection")) || ((data0.discovery === undefined) && (missing1 = "discovery"))) || ((data0.observed_ms === undefined) && (missing1 = "observed_ms"))){
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
if(!((((key1 === "connection") || (key1 === "discovery")) || (key1 === "observed_ms")) || (key1 === "max_lease_ms"))){
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
if(((((data1.realm === undefined) && (missing2 = "realm")) || ((data1.principal === undefined) && (missing2 = "principal"))) || ((data1.service === undefined) && (missing2 = "service"))) || ((data1.ingress === undefined) && (missing2 = "ingress"))){
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
if(!(((((key2 === "realm") || (key2 === "principal")) || (key2 === "service")) || (key2 === "ingress")) || (key2 === "role"))){
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
if(!(validate56(data1.realm, {instancePath:instancePath+"/description/connection/realm",parentData:data1,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate56(data1.principal, {instancePath:instancePath+"/description/connection/principal",parentData:data1,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid3 = _errs11 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data1.service !== undefined){
const _errs12 = errors;
if(!(validate56(data1.service, {instancePath:instancePath+"/description/connection/service",parentData:data1,parentDataProperty:"service",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid3 = _errs12 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data1.ingress !== undefined){
const _errs13 = errors;
if(!(validate56(data1.ingress, {instancePath:instancePath+"/description/connection/ingress",parentData:data1,parentDataProperty:"ingress",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid3 = _errs13 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data1.role !== undefined){
const _errs14 = errors;
if(!(validate60(data1.role, {instancePath:instancePath+"/description/connection/role",parentData:data1,parentDataProperty:"role",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate60.errors : vErrors.concat(validate60.errors);
errors = vErrors.length;
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
if(data0.discovery !== undefined){
const _errs15 = errors;
if(!(validate412(data0.discovery, {instancePath:instancePath+"/description/discovery",parentData:data0,parentDataProperty:"discovery",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate412.errors : vErrors.concat(validate412.errors);
errors = vErrors.length;
}
var valid2 = _errs15 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data0.observed_ms !== undefined){
const _errs16 = errors;
if(!(validate56(data0.observed_ms, {instancePath:instancePath+"/description/observed_ms",parentData:data0,parentDataProperty:"observed_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid2 = _errs16 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data0.max_lease_ms !== undefined){
const _errs17 = errors;
if(!(validate324(data0.max_lease_ms, {instancePath:instancePath+"/description/max_lease_ms",parentData:data0,parentDataProperty:"max_lease_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate324.errors : vErrors.concat(validate324.errors);
errors = vErrors.length;
}
var valid2 = _errs17 === errors;
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
else {
const err7 = {instancePath:instancePath+"/description",schemaPath:"#/oneOf/0/properties/description/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err7];
}
else {
vErrors.push(err7);
}
errors++;
}
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err8];
}
else {
vErrors.push(err8);
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
const _errs18 = errors;
if(errors === _errs18){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing3;
if((data.clock === undefined) && (missing3 = "clock")){
const err9 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
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
for(const key3 in data){
if(!(key3 === "clock")){
const err10 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(data.clock !== undefined){
let data10 = data.clock;
const _errs21 = errors;
if(errors === _errs21){
if(data10 && typeof data10 == "object" && !Array.isArray(data10)){
let missing4;
if((data10.observed_ms === undefined) && (missing4 = "observed_ms")){
const err11 = {instancePath:instancePath+"/clock",schemaPath:"#/oneOf/1/properties/clock/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
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
if(!((key4 === "observed_ms") || (key4 === "max_lease_ms"))){
const err12 = {instancePath:instancePath+"/clock",schemaPath:"#/oneOf/1/properties/clock/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(data10.observed_ms !== undefined){
const _errs24 = errors;
if(!(validate56(data10.observed_ms, {instancePath:instancePath+"/clock/observed_ms",parentData:data10,parentDataProperty:"observed_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid5 = _errs24 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data10.max_lease_ms !== undefined){
const _errs25 = errors;
if(!(validate324(data10.max_lease_ms, {instancePath:instancePath+"/clock/max_lease_ms",parentData:data10,parentDataProperty:"max_lease_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate324.errors : vErrors.concat(validate324.errors);
errors = vErrors.length;
}
var valid5 = _errs25 === errors;
}
else {
var valid5 = true;
}
}
}
}
}
else {
const err13 = {instancePath:instancePath+"/clock",schemaPath:"#/oneOf/1/properties/clock/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err14 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const _errs26 = errors;
if(errors === _errs26){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing5;
if((data.inspection === undefined) && (missing5 = "inspection")){
const err15 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
}
else {
const _errs28 = errors;
for(const key5 in data){
if(!(key5 === "inspection")){
const err16 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(_errs28 === errors){
if(data.inspection !== undefined){
let data13 = data.inspection;
const _errs29 = errors;
if(errors === _errs29){
if(data13 && typeof data13 == "object" && !Array.isArray(data13)){
let missing6;
if(((data13.response === undefined) && (missing6 = "response")) || ((data13.observation === undefined) && (missing6 = "observation"))){
const err17 = {instancePath:instancePath+"/inspection",schemaPath:"#/oneOf/2/properties/inspection/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
if(vErrors === null){
vErrors = [err17];
}
else {
vErrors.push(err17);
}
errors++;
}
else {
const _errs31 = errors;
for(const key6 in data13){
if(!((key6 === "response") || (key6 === "observation"))){
const err18 = {instancePath:instancePath+"/inspection",schemaPath:"#/oneOf/2/properties/inspection/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
break;
}
}
if(_errs31 === errors){
if(data13.response !== undefined){
let data14 = data13.response;
const _errs32 = errors;
if(errors === _errs32){
if(data14 && typeof data14 == "object" && !Array.isArray(data14)){
let missing7;
if((data14.session === undefined) && (missing7 = "session")){
const err19 = {instancePath:instancePath+"/inspection/response",schemaPath:"#/oneOf/2/properties/inspection/properties/response/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
}
else {
const _errs34 = errors;
for(const key7 in data14){
if(!((((((key7 === "version") || (key7 === "session")) || (key7 === "source")) || (key7 === "snapshot")) || (key7 === "event")) || (key7 === "cursor"))){
const err20 = {instancePath:instancePath+"/inspection/response",schemaPath:"#/oneOf/2/properties/inspection/properties/response/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err20];
}
else {
vErrors.push(err20);
}
errors++;
break;
}
}
if(_errs34 === errors){
if(data14.version !== undefined){
const _errs35 = errors;
if(1 !== data14.version){
const err21 = {instancePath:instancePath+"/inspection/response/version",schemaPath:"#/oneOf/2/properties/inspection/properties/response/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
}
errors++;
}
var valid8 = _errs35 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data14.session !== undefined){
const _errs36 = errors;
if(!(validate235(data14.session, {instancePath:instancePath+"/inspection/response/session",parentData:data14,parentDataProperty:"session",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate235.errors : vErrors.concat(validate235.errors);
errors = vErrors.length;
}
var valid8 = _errs36 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data14.source !== undefined){
const _errs37 = errors;
if(!(validate250(data14.source, {instancePath:instancePath+"/inspection/response/source",parentData:data14,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate250.errors : vErrors.concat(validate250.errors);
errors = vErrors.length;
}
var valid8 = _errs37 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data14.snapshot !== undefined){
const _errs38 = errors;
if(!(validate264(data14.snapshot, {instancePath:instancePath+"/inspection/response/snapshot",parentData:data14,parentDataProperty:"snapshot",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate264.errors : vErrors.concat(validate264.errors);
errors = vErrors.length;
}
var valid8 = _errs38 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data14.event !== undefined){
let data19 = data14.event;
const _errs39 = errors;
const _errs40 = errors;
let valid9 = false;
const _errs41 = errors;
if(errors === _errs41){
if(data19 && typeof data19 == "object" && !Array.isArray(data19)){
let missing8;
if((((data19.source_changed === undefined) && (missing8 = "source_changed")) || ((data19.resource === undefined) && (missing8 = "resource"))) || ((data19.data_revision === undefined) && (missing8 = "data_revision"))){
const err22 = {instancePath:instancePath+"/inspection/response/event",schemaPath:"#/oneOf/2/properties/inspection/properties/response/properties/event/anyOf/0/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
if(vErrors === null){
vErrors = [err22];
}
else {
vErrors.push(err22);
}
errors++;
}
else {
const _errs43 = errors;
for(const key8 in data19){
if(!((((key8 === "source_changed") || (key8 === "resource")) || (key8 === "data_revision")) || (key8 === "outcome"))){
const err23 = {instancePath:instancePath+"/inspection/response/event",schemaPath:"#/oneOf/2/properties/inspection/properties/response/properties/event/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err23];
}
else {
vErrors.push(err23);
}
errors++;
break;
}
}
if(_errs43 === errors){
if(data19.source_changed !== undefined){
const _errs44 = errors;
if(typeof data19.source_changed !== "boolean"){
const err24 = {instancePath:instancePath+"/inspection/response/event/source_changed",schemaPath:"#/oneOf/2/properties/inspection/properties/response/properties/event/anyOf/0/properties/source_changed/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
}
errors++;
}
var valid10 = _errs44 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data19.resource !== undefined){
const _errs46 = errors;
if(!(validate56(data19.resource, {instancePath:instancePath+"/inspection/response/event/resource",parentData:data19,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid10 = _errs46 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data19.data_revision !== undefined){
const _errs47 = errors;
if(!(validate225(data19.data_revision, {instancePath:instancePath+"/inspection/response/event/data_revision",parentData:data19,parentDataProperty:"data_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
errors = vErrors.length;
}
var valid10 = _errs47 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data19.outcome !== undefined){
let data23 = data19.outcome;
const _errs48 = errors;
const _errs49 = errors;
let valid11 = false;
const _errs50 = errors;
if(errors === _errs50){
if(data23 && typeof data23 == "object" && !Array.isArray(data23)){
let missing9;
if(((((data23.resource === undefined) && (missing9 = "resource")) || ((data23.operation === undefined) && (missing9 = "operation"))) || ((data23.phase === undefined) && (missing9 = "phase"))) || ((data23.resolution_input === undefined) && (missing9 = "resolution_input"))){
const err25 = {instancePath:instancePath+"/inspection/response/event/outcome",schemaPath:"#/oneOf/2/properties/inspection/properties/response/properties/event/anyOf/0/properties/outcome/anyOf/0/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
if(vErrors === null){
vErrors = [err25];
}
else {
vErrors.push(err25);
}
errors++;
}
else {
const _errs52 = errors;
for(const key9 in data23){
if(!(((((key9 === "resource") || (key9 === "operation")) || (key9 === "phase")) || (key9 === "resolution_input")) || (key9 === "diagnostic"))){
const err26 = {instancePath:instancePath+"/inspection/response/event/outcome",schemaPath:"#/oneOf/2/properties/inspection/properties/response/properties/event/anyOf/0/properties/outcome/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
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
if(_errs52 === errors){
if(data23.resource !== undefined){
const _errs53 = errors;
if(!(validate56(data23.resource, {instancePath:instancePath+"/inspection/response/event/outcome/resource",parentData:data23,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid12 = _errs53 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data23.operation !== undefined){
const _errs54 = errors;
if(!(validate56(data23.operation, {instancePath:instancePath+"/inspection/response/event/outcome/operation",parentData:data23,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid12 = _errs54 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data23.phase !== undefined){
const _errs55 = errors;
if(!(validate177(data23.phase, {instancePath:instancePath+"/inspection/response/event/outcome/phase",parentData:data23,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate177.errors : vErrors.concat(validate177.errors);
errors = vErrors.length;
}
var valid12 = _errs55 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data23.resolution_input !== undefined){
const _errs56 = errors;
if(!(validate56(data23.resolution_input, {instancePath:instancePath+"/inspection/response/event/outcome/resolution_input",parentData:data23,parentDataProperty:"resolution_input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid12 = _errs56 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data23.diagnostic !== undefined){
const _errs57 = errors;
if(!(validate434(data23.diagnostic, {instancePath:instancePath+"/inspection/response/event/outcome/diagnostic",parentData:data23,parentDataProperty:"diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate434.errors : vErrors.concat(validate434.errors);
errors = vErrors.length;
}
var valid12 = _errs57 === errors;
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
else {
const err27 = {instancePath:instancePath+"/inspection/response/event/outcome",schemaPath:"#/oneOf/2/properties/inspection/properties/response/properties/event/anyOf/0/properties/outcome/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err27];
}
else {
vErrors.push(err27);
}
errors++;
}
}
var _valid2 = _errs50 === errors;
valid11 = valid11 || _valid2;
const _errs58 = errors;
if(data23 !== null){
const err28 = {instancePath:instancePath+"/inspection/response/event/outcome",schemaPath:"#/oneOf/2/properties/inspection/properties/response/properties/event/anyOf/0/properties/outcome/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err28];
}
else {
vErrors.push(err28);
}
errors++;
}
var _valid2 = _errs58 === errors;
valid11 = valid11 || _valid2;
if(!valid11){
const err29 = {instancePath:instancePath+"/inspection/response/event/outcome",schemaPath:"#/oneOf/2/properties/inspection/properties/response/properties/event/anyOf/0/properties/outcome/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err29];
}
else {
vErrors.push(err29);
}
errors++;
}
else {
errors = _errs49;
if(vErrors !== null){
if(_errs49){
vErrors.length = _errs49;
}
else {
vErrors = null;
}
}
}
var valid10 = _errs48 === errors;
}
else {
var valid10 = true;
}
}
}
}
}
}
}
else {
const err30 = {instancePath:instancePath+"/inspection/response/event",schemaPath:"#/oneOf/2/properties/inspection/properties/response/properties/event/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
}
errors++;
}
}
var _valid1 = _errs41 === errors;
valid9 = valid9 || _valid1;
const _errs60 = errors;
if(data19 !== null){
const err31 = {instancePath:instancePath+"/inspection/response/event",schemaPath:"#/oneOf/2/properties/inspection/properties/response/properties/event/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err31];
}
else {
vErrors.push(err31);
}
errors++;
}
var _valid1 = _errs60 === errors;
valid9 = valid9 || _valid1;
if(!valid9){
const err32 = {instancePath:instancePath+"/inspection/response/event",schemaPath:"#/oneOf/2/properties/inspection/properties/response/properties/event/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err32];
}
else {
vErrors.push(err32);
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
if(valid8){
if(data14.cursor !== undefined){
const _errs62 = errors;
if(!(validate218(data14.cursor, {instancePath:instancePath+"/inspection/response/cursor",parentData:data14,parentDataProperty:"cursor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate218.errors : vErrors.concat(validate218.errors);
errors = vErrors.length;
}
var valid8 = _errs62 === errors;
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
const err33 = {instancePath:instancePath+"/inspection/response",schemaPath:"#/oneOf/2/properties/inspection/properties/response/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
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
if(data13.observation !== undefined){
const _errs63 = errors;
if(!(validate266(data13.observation, {instancePath:instancePath+"/inspection/observation",parentData:data13,parentDataProperty:"observation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate266.errors : vErrors.concat(validate266.errors);
errors = vErrors.length;
}
var valid7 = _errs63 === errors;
}
else {
var valid7 = true;
}
}
}
}
}
else {
const err34 = {instancePath:instancePath+"/inspection",schemaPath:"#/oneOf/2/properties/inspection/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err35 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err35];
}
else {
vErrors.push(err35);
}
errors++;
}
}
var _valid0 = _errs26 === errors;
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
const _errs64 = errors;
if(errors === _errs64){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing10;
if((data.covered === undefined) && (missing10 = "covered")){
const err36 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
}
else {
const _errs66 = errors;
for(const key10 in data){
if(!(key10 === "covered")){
const err37 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"};
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
if(_errs66 === errors){
if(data.covered !== undefined){
if(typeof data.covered !== "boolean"){
const err38 = {instancePath:instancePath+"/covered",schemaPath:"#/oneOf/3/properties/covered/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
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
else {
const err39 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err39];
}
else {
vErrors.push(err39);
}
errors++;
}
}
var _valid0 = _errs64 === errors;
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
const _errs69 = errors;
if(errors === _errs69){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing11;
if((data.prepared === undefined) && (missing11 = "prepared")){
const err40 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
if(vErrors === null){
vErrors = [err40];
}
else {
vErrors.push(err40);
}
errors++;
}
else {
const _errs71 = errors;
for(const key11 in data){
if(!(key11 === "prepared")){
const err41 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
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
if(_errs71 === errors){
if(data.prepared !== undefined){
if(!(validate308(data.prepared, {instancePath:instancePath+"/prepared",parentData:data,parentDataProperty:"prepared",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate308.errors : vErrors.concat(validate308.errors);
errors = vErrors.length;
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
var _valid0 = _errs69 === errors;
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
const _errs73 = errors;
if(!(validate329(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate329.errors : vErrors.concat(validate329.errors);
errors = vErrors.length;
}
var _valid0 = _errs73 === errors;
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
const _errs74 = errors;
if(errors === _errs74){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing12;
if((data.observation === undefined) && (missing12 = "observation")){
const err43 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing12},message:"must have required property '"+missing12+"'"};
if(vErrors === null){
vErrors = [err43];
}
else {
vErrors.push(err43);
}
errors++;
}
else {
const _errs76 = errors;
for(const key12 in data){
if(!(key12 === "observation")){
const err44 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key12},message:"must NOT have additional properties"};
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
if(_errs76 === errors){
if(data.observation !== undefined){
let data33 = data.observation;
const _errs78 = errors;
let valid16 = false;
let passing1 = null;
const _errs79 = errors;
if(errors === _errs79){
if(data33 && typeof data33 == "object" && !Array.isArray(data33)){
let missing13;
if((data33.pending === undefined) && (missing13 = "pending")){
const err45 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/6/properties/observation/oneOf/0/required",keyword:"required",params:{missingProperty: missing13},message:"must have required property '"+missing13+"'"};
if(vErrors === null){
vErrors = [err45];
}
else {
vErrors.push(err45);
}
errors++;
}
else {
const _errs81 = errors;
for(const key13 in data33){
if(!(key13 === "pending")){
const err46 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/6/properties/observation/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key13},message:"must NOT have additional properties"};
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
if(_errs81 === errors){
if(data33.pending !== undefined){
let data34 = data33.pending;
const _errs82 = errors;
if(errors === _errs82){
if(data34 && typeof data34 == "object" && !Array.isArray(data34)){
if(Object.keys(data34).length > 0){
const err47 = {instancePath:instancePath+"/observation/pending",schemaPath:"#/oneOf/6/properties/observation/oneOf/0/properties/pending/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err47];
}
else {
vErrors.push(err47);
}
errors++;
}
}
else {
const err48 = {instancePath:instancePath+"/observation/pending",schemaPath:"#/oneOf/6/properties/observation/oneOf/0/properties/pending/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err49 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/6/properties/observation/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err49];
}
else {
vErrors.push(err49);
}
errors++;
}
}
var _valid3 = _errs79 === errors;
if(_valid3){
valid16 = true;
passing1 = 0;
var props7 = true;
}
const _errs84 = errors;
if(errors === _errs84){
if(data33 && typeof data33 == "object" && !Array.isArray(data33)){
let missing14;
if((data33.committed === undefined) && (missing14 = "committed")){
const err50 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/6/properties/observation/oneOf/1/required",keyword:"required",params:{missingProperty: missing14},message:"must have required property '"+missing14+"'"};
if(vErrors === null){
vErrors = [err50];
}
else {
vErrors.push(err50);
}
errors++;
}
else {
const _errs86 = errors;
for(const key14 in data33){
if(!(key14 === "committed")){
const err51 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/6/properties/observation/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key14},message:"must NOT have additional properties"};
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
if(_errs86 === errors){
if(data33.committed !== undefined){
let data35 = data33.committed;
const _errs87 = errors;
if(errors === _errs87){
if(data35 && typeof data35 == "object" && !Array.isArray(data35)){
if(Object.keys(data35).length > 0){
const err52 = {instancePath:instancePath+"/observation/committed",schemaPath:"#/oneOf/6/properties/observation/oneOf/1/properties/committed/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
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
const err53 = {instancePath:instancePath+"/observation/committed",schemaPath:"#/oneOf/6/properties/observation/oneOf/1/properties/committed/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err54 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/6/properties/observation/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err54];
}
else {
vErrors.push(err54);
}
errors++;
}
}
var _valid3 = _errs84 === errors;
if(_valid3 && valid16){
valid16 = false;
passing1 = [passing1, 1];
}
else {
if(_valid3){
valid16 = true;
passing1 = 1;
if(props7 !== true){
props7 = true;
}
}
const _errs89 = errors;
if(errors === _errs89){
if(data33 && typeof data33 == "object" && !Array.isArray(data33)){
let missing15;
if((data33.rejected === undefined) && (missing15 = "rejected")){
const err55 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/6/properties/observation/oneOf/2/required",keyword:"required",params:{missingProperty: missing15},message:"must have required property '"+missing15+"'"};
if(vErrors === null){
vErrors = [err55];
}
else {
vErrors.push(err55);
}
errors++;
}
else {
const _errs91 = errors;
for(const key15 in data33){
if(!(key15 === "rejected")){
const err56 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/6/properties/observation/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key15},message:"must NOT have additional properties"};
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
if(_errs91 === errors){
if(data33.rejected !== undefined){
let data36 = data33.rejected;
const _errs92 = errors;
if(errors === _errs92){
if(data36 && typeof data36 == "object" && !Array.isArray(data36)){
let missing16;
if(((data36.record === undefined) && (missing16 = "record")) || ((data36.diagnostic === undefined) && (missing16 = "diagnostic"))){
const err57 = {instancePath:instancePath+"/observation/rejected",schemaPath:"#/oneOf/6/properties/observation/oneOf/2/properties/rejected/required",keyword:"required",params:{missingProperty: missing16},message:"must have required property '"+missing16+"'"};
if(vErrors === null){
vErrors = [err57];
}
else {
vErrors.push(err57);
}
errors++;
}
else {
const _errs94 = errors;
for(const key16 in data36){
if(!((key16 === "record") || (key16 === "diagnostic"))){
const err58 = {instancePath:instancePath+"/observation/rejected",schemaPath:"#/oneOf/6/properties/observation/oneOf/2/properties/rejected/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key16},message:"must NOT have additional properties"};
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
if(_errs94 === errors){
if(data36.record !== undefined){
const _errs95 = errors;
if(!(validate183(data36.record, {instancePath:instancePath+"/observation/rejected/record",parentData:data36,parentDataProperty:"record",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate183.errors : vErrors.concat(validate183.errors);
errors = vErrors.length;
}
var valid20 = _errs95 === errors;
}
else {
var valid20 = true;
}
if(valid20){
if(data36.diagnostic !== undefined){
const _errs96 = errors;
if(!(validate434(data36.diagnostic, {instancePath:instancePath+"/observation/rejected/diagnostic",parentData:data36,parentDataProperty:"diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate434.errors : vErrors.concat(validate434.errors);
errors = vErrors.length;
}
var valid20 = _errs96 === errors;
}
else {
var valid20 = true;
}
}
}
}
}
else {
const err59 = {instancePath:instancePath+"/observation/rejected",schemaPath:"#/oneOf/6/properties/observation/oneOf/2/properties/rejected/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err59];
}
else {
vErrors.push(err59);
}
errors++;
}
}
}
}
}
}
else {
const err60 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/6/properties/observation/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err60];
}
else {
vErrors.push(err60);
}
errors++;
}
}
var _valid3 = _errs89 === errors;
if(_valid3 && valid16){
valid16 = false;
passing1 = [passing1, 2];
}
else {
if(_valid3){
valid16 = true;
passing1 = 2;
if(props7 !== true){
props7 = true;
}
}
}
}
if(!valid16){
const err61 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/6/properties/observation/oneOf",keyword:"oneOf",params:{passingSchemas: passing1},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err61];
}
else {
vErrors.push(err61);
}
errors++;
}
else {
errors = _errs78;
if(vErrors !== null){
if(_errs78){
vErrors.length = _errs78;
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
const err62 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err62];
}
else {
vErrors.push(err62);
}
errors++;
}
}
var _valid0 = _errs74 === errors;
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
let missing17;
if((data.signed_read === undefined) && (missing17 = "signed_read")){
const err63 = {instancePath,schemaPath:"#/oneOf/7/required",keyword:"required",params:{missingProperty: missing17},message:"must have required property '"+missing17+"'"};
if(vErrors === null){
vErrors = [err63];
}
else {
vErrors.push(err63);
}
errors++;
}
else {
const _errs99 = errors;
for(const key17 in data){
if(!(key17 === "signed_read")){
const err64 = {instancePath,schemaPath:"#/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key17},message:"must NOT have additional properties"};
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
if(_errs99 === errors){
if(data.signed_read !== undefined){
let data39 = data.signed_read;
const _errs100 = errors;
if(errors === _errs100){
if(data39 && typeof data39 == "object" && !Array.isArray(data39)){
let missing18;
if(((data39.read === undefined) && (missing18 = "read")) || ((data39.proof === undefined) && (missing18 = "proof"))){
const err65 = {instancePath:instancePath+"/signed_read",schemaPath:"#/oneOf/7/properties/signed_read/required",keyword:"required",params:{missingProperty: missing18},message:"must have required property '"+missing18+"'"};
if(vErrors === null){
vErrors = [err65];
}
else {
vErrors.push(err65);
}
errors++;
}
else {
const _errs102 = errors;
for(const key18 in data39){
if(!((key18 === "read") || (key18 === "proof"))){
const err66 = {instancePath:instancePath+"/signed_read",schemaPath:"#/oneOf/7/properties/signed_read/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key18},message:"must NOT have additional properties"};
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
if(_errs102 === errors){
if(data39.read !== undefined){
const _errs103 = errors;
if(!(validate201(data39.read, {instancePath:instancePath+"/signed_read/read",parentData:data39,parentDataProperty:"read",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate201.errors : vErrors.concat(validate201.errors);
errors = vErrors.length;
}
var valid22 = _errs103 === errors;
}
else {
var valid22 = true;
}
if(valid22){
if(data39.proof !== undefined){
const _errs104 = errors;
if(!(validate500(data39.proof, {instancePath:instancePath+"/signed_read/proof",parentData:data39,parentDataProperty:"proof",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate500.errors : vErrors.concat(validate500.errors);
errors = vErrors.length;
}
var valid22 = _errs104 === errors;
}
else {
var valid22 = true;
}
}
}
}
}
else {
const err67 = {instancePath:instancePath+"/signed_read",schemaPath:"#/oneOf/7/properties/signed_read/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err67];
}
else {
vErrors.push(err67);
}
errors++;
}
}
}
}
}
}
else {
const err68 = {instancePath,schemaPath:"#/oneOf/7/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err68];
}
else {
vErrors.push(err68);
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
const _errs105 = errors;
if(errors === _errs105){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing19;
if((data.refresh_status === undefined) && (missing19 = "refresh_status")){
const err69 = {instancePath,schemaPath:"#/oneOf/8/required",keyword:"required",params:{missingProperty: missing19},message:"must have required property '"+missing19+"'"};
if(vErrors === null){
vErrors = [err69];
}
else {
vErrors.push(err69);
}
errors++;
}
else {
const _errs107 = errors;
for(const key19 in data){
if(!(key19 === "refresh_status")){
const err70 = {instancePath,schemaPath:"#/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key19},message:"must NOT have additional properties"};
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
if(_errs107 === errors){
if(data.refresh_status !== undefined){
let data42 = data.refresh_status;
const _errs108 = errors;
if(errors === _errs108){
if(data42 && typeof data42 == "object" && !Array.isArray(data42)){
let missing20;
if(((((data42.resource === undefined) && (missing20 = "resource")) || ((data42.revision === undefined) && (missing20 = "revision"))) || ((data42.policy_revision === undefined) && (missing20 = "policy_revision"))) || ((data42.view === undefined) && (missing20 = "view"))){
const err71 = {instancePath:instancePath+"/refresh_status",schemaPath:"#/oneOf/8/properties/refresh_status/required",keyword:"required",params:{missingProperty: missing20},message:"must have required property '"+missing20+"'"};
if(vErrors === null){
vErrors = [err71];
}
else {
vErrors.push(err71);
}
errors++;
}
else {
const _errs110 = errors;
for(const key20 in data42){
if(!((((((key20 === "resource") || (key20 === "revision")) || (key20 === "policy_revision")) || (key20 === "view")) || (key20 === "diagnostic")) || (key20 === "query_diagnostic"))){
const err72 = {instancePath:instancePath+"/refresh_status",schemaPath:"#/oneOf/8/properties/refresh_status/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key20},message:"must NOT have additional properties"};
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
if(_errs110 === errors){
if(data42.resource !== undefined){
const _errs111 = errors;
if(!(validate56(data42.resource, {instancePath:instancePath+"/refresh_status/resource",parentData:data42,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid24 = _errs111 === errors;
}
else {
var valid24 = true;
}
if(valid24){
if(data42.revision !== undefined){
const _errs112 = errors;
if(!(validate56(data42.revision, {instancePath:instancePath+"/refresh_status/revision",parentData:data42,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid24 = _errs112 === errors;
}
else {
var valid24 = true;
}
if(valid24){
if(data42.policy_revision !== undefined){
const _errs113 = errors;
if(!(validate56(data42.policy_revision, {instancePath:instancePath+"/refresh_status/policy_revision",parentData:data42,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid24 = _errs113 === errors;
}
else {
var valid24 = true;
}
if(valid24){
if(data42.view !== undefined){
let data46 = data42.view;
const _errs114 = errors;
if(errors === _errs114){
if(data46 && typeof data46 == "object" && !Array.isArray(data46)){
let missing21;
if((((((((((data46.principal === undefined) && (missing21 = "principal")) || ((data46.session === undefined) && (missing21 = "session"))) || ((data46.generation === undefined) && (missing21 = "generation"))) || ((data46.source === undefined) && (missing21 = "source"))) || ((data46.template === undefined) && (missing21 = "template"))) || ((data46.namespace === undefined) && (missing21 = "namespace"))) || ((data46.dirty === undefined) && (missing21 = "dirty"))) || ((data46.covered === undefined) && (missing21 = "covered"))) || ((data46.limit === undefined) && (missing21 = "limit"))){
const err73 = {instancePath:instancePath+"/refresh_status/view",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/required",keyword:"required",params:{missingProperty: missing21},message:"must have required property '"+missing21+"'"};
if(vErrors === null){
vErrors = [err73];
}
else {
vErrors.push(err73);
}
errors++;
}
else {
const _errs116 = errors;
for(const key21 in data46){
if(!(func1.call(schema106.oneOf[8].properties.refresh_status.properties.view.properties, key21))){
const err74 = {instancePath:instancePath+"/refresh_status/view",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key21},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err74];
}
else {
vErrors.push(err74);
}
errors++;
break;
}
}
if(_errs116 === errors){
if(data46.principal !== undefined){
const _errs117 = errors;
if(!(validate56(data46.principal, {instancePath:instancePath+"/refresh_status/view/principal",parentData:data46,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid25 = _errs117 === errors;
}
else {
var valid25 = true;
}
if(valid25){
if(data46.session !== undefined){
const _errs118 = errors;
if(!(validate373(data46.session, {instancePath:instancePath+"/refresh_status/view/session",parentData:data46,parentDataProperty:"session",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate373.errors : vErrors.concat(validate373.errors);
errors = vErrors.length;
}
var valid25 = _errs118 === errors;
}
else {
var valid25 = true;
}
if(valid25){
if(data46.generation !== undefined){
const _errs119 = errors;
if(!(validate56(data46.generation, {instancePath:instancePath+"/refresh_status/view/generation",parentData:data46,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid25 = _errs119 === errors;
}
else {
var valid25 = true;
}
if(valid25){
if(data46.source !== undefined){
const _errs120 = errors;
if(!(validate251(data46.source, {instancePath:instancePath+"/refresh_status/view/source",parentData:data46,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate251.errors : vErrors.concat(validate251.errors);
errors = vErrors.length;
}
var valid25 = _errs120 === errors;
}
else {
var valid25 = true;
}
if(valid25){
if(data46.template !== undefined){
const _errs121 = errors;
if(!(validate225(data46.template, {instancePath:instancePath+"/refresh_status/view/template",parentData:data46,parentDataProperty:"template",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
errors = vErrors.length;
}
var valid25 = _errs121 === errors;
}
else {
var valid25 = true;
}
if(valid25){
if(data46.namespace !== undefined){
const _errs122 = errors;
if(!(validate225(data46.namespace, {instancePath:instancePath+"/refresh_status/view/namespace",parentData:data46,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
errors = vErrors.length;
}
var valid25 = _errs122 === errors;
}
else {
var valid25 = true;
}
if(valid25){
if(data46.dirty !== undefined){
const _errs123 = errors;
if(!(validate225(data46.dirty, {instancePath:instancePath+"/refresh_status/view/dirty",parentData:data46,parentDataProperty:"dirty",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
errors = vErrors.length;
}
var valid25 = _errs123 === errors;
}
else {
var valid25 = true;
}
if(valid25){
if(data46.covered !== undefined){
const _errs124 = errors;
if(!(validate225(data46.covered, {instancePath:instancePath+"/refresh_status/view/covered",parentData:data46,parentDataProperty:"covered",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
errors = vErrors.length;
}
var valid25 = _errs124 === errors;
}
else {
var valid25 = true;
}
if(valid25){
if(data46.starts !== undefined){
const _errs125 = errors;
if(!(validate65(data46.starts, {instancePath:instancePath+"/refresh_status/view/starts",parentData:data46,parentDataProperty:"starts",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
errors = vErrors.length;
}
var valid25 = _errs125 === errors;
}
else {
var valid25 = true;
}
if(valid25){
if(data46.limit !== undefined){
const _errs126 = errors;
if(!(validate65(data46.limit, {instancePath:instancePath+"/refresh_status/view/limit",parentData:data46,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
errors = vErrors.length;
}
var valid25 = _errs126 === errors;
}
else {
var valid25 = true;
}
if(valid25){
if(data46.next_start_ms !== undefined){
const _errs127 = errors;
if(!(validate56(data46.next_start_ms, {instancePath:instancePath+"/refresh_status/view/next_start_ms",parentData:data46,parentDataProperty:"next_start_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid25 = _errs127 === errors;
}
else {
var valid25 = true;
}
if(valid25){
if(data46.enabled !== undefined){
const _errs128 = errors;
if(typeof data46.enabled !== "boolean"){
const err75 = {instancePath:instancePath+"/refresh_status/view/enabled",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/enabled/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err75];
}
else {
vErrors.push(err75);
}
errors++;
}
var valid25 = _errs128 === errors;
}
else {
var valid25 = true;
}
if(valid25){
if(data46.phase !== undefined){
const _errs130 = errors;
if(!(validate518(data46.phase, {instancePath:instancePath+"/refresh_status/view/phase",parentData:data46,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate518.errors : vErrors.concat(validate518.errors);
errors = vErrors.length;
}
var valid25 = _errs130 === errors;
}
else {
var valid25 = true;
}
if(valid25){
if(data46.failure !== undefined){
let data60 = data46.failure;
const _errs131 = errors;
const _errs132 = errors;
let valid26 = false;
let passing2 = null;
const _errs133 = errors;
if(!(validate520(data60, {instancePath:instancePath+"/refresh_status/view/failure",parentData:data46,parentDataProperty:"failure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate520.errors : vErrors.concat(validate520.errors);
errors = vErrors.length;
}
var _valid4 = _errs133 === errors;
if(_valid4){
valid26 = true;
passing2 = 0;
var props9 = true;
}
const _errs134 = errors;
if(errors === _errs134){
if(data60 && typeof data60 == "object" && !Array.isArray(data60)){
let missing22;
if((data60.stopped === undefined) && (missing22 = "stopped")){
const err76 = {instancePath:instancePath+"/refresh_status/view/failure",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/required",keyword:"required",params:{missingProperty: missing22},message:"must have required property '"+missing22+"'"};
if(vErrors === null){
vErrors = [err76];
}
else {
vErrors.push(err76);
}
errors++;
}
else {
const _errs136 = errors;
for(const key22 in data60){
if(!(key22 === "stopped")){
const err77 = {instancePath:instancePath+"/refresh_status/view/failure",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key22},message:"must NOT have additional properties"};
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
if(_errs136 === errors){
if(data60.stopped !== undefined){
let data61 = data60.stopped;
const _errs137 = errors;
if(errors === _errs137){
if(data61 && typeof data61 == "object" && !Array.isArray(data61)){
let missing23;
if(((data61.reason === undefined) && (missing23 = "reason")) || ((data61.input === undefined) && (missing23 = "input"))){
const err78 = {instancePath:instancePath+"/refresh_status/view/failure/stopped",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/required",keyword:"required",params:{missingProperty: missing23},message:"must have required property '"+missing23+"'"};
if(vErrors === null){
vErrors = [err78];
}
else {
vErrors.push(err78);
}
errors++;
}
else {
const _errs139 = errors;
for(const key23 in data61){
if(!(((key23 === "reason") || (key23 === "input")) || (key23 === "witness"))){
const err79 = {instancePath:instancePath+"/refresh_status/view/failure/stopped",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key23},message:"must NOT have additional properties"};
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
if(_errs139 === errors){
if(data61.reason !== undefined){
let data62 = data61.reason;
const _errs140 = errors;
if(typeof data62 !== "string"){
const err80 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/reason",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/reason/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err80];
}
else {
vErrors.push(err80);
}
errors++;
}
if(!((((((((((((((((((((data62 === "paused") || (data62 === "budget_exhausted")) || (data62 === "session_closed")) || (data62 === "session_expired")) || (data62 === "source_changed")) || (data62 === "binding_unpublished")) || (data62 === "service_denied")) || (data62 === "native_denied")) || (data62 === "query_denied")) || (data62 === "catalog_denied")) || (data62 === "resource_unavailable")) || (data62 === "query_source_unavailable")) || (data62 === "result_unavailable")) || (data62 === "result_unpublished")) || (data62 === "template_invalid")) || (data62 === "upload_closed")) || (data62 === "namespace_occupied")) || (data62 === "query_rejected")) || (data62 === "query_cancelled")) || (data62 === "query_retired"))){
const err81 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/reason",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/reason/enum",keyword:"enum",params:{allowedValues: schema106.oneOf[8].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.reason.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err81];
}
else {
vErrors.push(err81);
}
errors++;
}
var valid28 = _errs140 === errors;
}
else {
var valid28 = true;
}
if(valid28){
if(data61.input !== undefined){
const _errs142 = errors;
if(!(validate56(data61.input, {instancePath:instancePath+"/refresh_status/view/failure/stopped/input",parentData:data61,parentDataProperty:"input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid28 = _errs142 === errors;
}
else {
var valid28 = true;
}
if(valid28){
if(data61.witness !== undefined){
let data64 = data61.witness;
const _errs143 = errors;
const _errs144 = errors;
let valid29 = false;
let passing3 = null;
const _errs145 = errors;
if(!(validate520(data64, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",parentData:data61,parentDataProperty:"witness",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate520.errors : vErrors.concat(validate520.errors);
errors = vErrors.length;
}
var _valid5 = _errs145 === errors;
if(_valid5){
valid29 = true;
passing3 = 0;
var props10 = true;
}
const _errs146 = errors;
if(errors === _errs146){
if(data64 && typeof data64 == "object" && !Array.isArray(data64)){
let missing24;
if((data64.revision === undefined) && (missing24 = "revision")){
const err82 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/1/required",keyword:"required",params:{missingProperty: missing24},message:"must have required property '"+missing24+"'"};
if(vErrors === null){
vErrors = [err82];
}
else {
vErrors.push(err82);
}
errors++;
}
else {
const _errs148 = errors;
for(const key24 in data64){
if(!(key24 === "revision")){
const err83 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key24},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err83];
}
else {
vErrors.push(err83);
}
errors++;
break;
}
}
if(_errs148 === errors){
if(data64.revision !== undefined){
let data65 = data64.revision;
const _errs149 = errors;
if(errors === _errs149){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing25;
if((((((data65.kind === undefined) && (missing25 = "kind")) || ((data65.expected === undefined) && (missing25 = "expected"))) || ((data65.actual === undefined) && (missing25 = "actual"))) || ((data65.proposed === undefined) && (missing25 = "proposed"))) || ((data65.present === undefined) && (missing25 = "present"))){
const err84 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/revision",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/1/properties/revision/required",keyword:"required",params:{missingProperty: missing25},message:"must have required property '"+missing25+"'"};
if(vErrors === null){
vErrors = [err84];
}
else {
vErrors.push(err84);
}
errors++;
}
else {
const _errs151 = errors;
for(const key25 in data65){
if(!(((((key25 === "kind") || (key25 === "expected")) || (key25 === "actual")) || (key25 === "proposed")) || (key25 === "present"))){
const err85 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/revision",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/1/properties/revision/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key25},message:"must NOT have additional properties"};
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
if(_errs151 === errors){
if(data65.kind !== undefined){
let data66 = data65.kind;
const _errs152 = errors;
if(typeof data66 !== "string"){
const err86 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/revision/kind",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/1/properties/revision/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err86];
}
else {
vErrors.push(err86);
}
errors++;
}
if(!((((data66 === "binding") || (data66 === "policy")) || (data66 === "watch")) || (data66 === "refresh"))){
const err87 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/revision/kind",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/1/properties/revision/properties/kind/enum",keyword:"enum",params:{allowedValues: schema106.oneOf[8].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[1].properties.revision.properties.kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err87];
}
else {
vErrors.push(err87);
}
errors++;
}
var valid31 = _errs152 === errors;
}
else {
var valid31 = true;
}
if(valid31){
if(data65.expected !== undefined){
const _errs154 = errors;
if(!(validate56(data65.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/revision/expected",parentData:data65,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid31 = _errs154 === errors;
}
else {
var valid31 = true;
}
if(valid31){
if(data65.actual !== undefined){
const _errs155 = errors;
if(!(validate56(data65.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/revision/actual",parentData:data65,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid31 = _errs155 === errors;
}
else {
var valid31 = true;
}
if(valid31){
if(data65.proposed !== undefined){
const _errs156 = errors;
if(!(validate56(data65.proposed, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/revision/proposed",parentData:data65,parentDataProperty:"proposed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid31 = _errs156 === errors;
}
else {
var valid31 = true;
}
if(valid31){
if(data65.present !== undefined){
const _errs157 = errors;
if(typeof data65.present !== "boolean"){
const err88 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/revision/present",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/1/properties/revision/properties/present/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err88];
}
else {
vErrors.push(err88);
}
errors++;
}
var valid31 = _errs157 === errors;
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
else {
const err89 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/revision",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/1/properties/revision/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err90 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err90];
}
else {
vErrors.push(err90);
}
errors++;
}
}
var _valid5 = _errs146 === errors;
if(_valid5 && valid29){
valid29 = false;
passing3 = [passing3, 1];
}
else {
if(_valid5){
valid29 = true;
passing3 = 1;
if(props10 !== true){
props10 = true;
}
}
const _errs159 = errors;
if(errors === _errs159){
if(data64 && typeof data64 == "object" && !Array.isArray(data64)){
let missing26;
if((data64.policy === undefined) && (missing26 = "policy")){
const err91 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/2/required",keyword:"required",params:{missingProperty: missing26},message:"must have required property '"+missing26+"'"};
if(vErrors === null){
vErrors = [err91];
}
else {
vErrors.push(err91);
}
errors++;
}
else {
const _errs161 = errors;
for(const key26 in data64){
if(!(key26 === "policy")){
const err92 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key26},message:"must NOT have additional properties"};
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
if(_errs161 === errors){
if(data64.policy !== undefined){
let data71 = data64.policy;
const _errs162 = errors;
if(errors === _errs162){
if(data71 && typeof data71 == "object" && !Array.isArray(data71)){
let missing27;
if((((((data71.principal === undefined) && (missing27 = "principal")) || ((data71.revision === undefined) && (missing27 = "revision"))) || ((data71.present === undefined) && (missing27 = "present"))) || ((data71.commands === undefined) && (missing27 = "commands"))) || ((data71.reads === undefined) && (missing27 = "reads"))){
const err93 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/policy",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/2/properties/policy/required",keyword:"required",params:{missingProperty: missing27},message:"must have required property '"+missing27+"'"};
if(vErrors === null){
vErrors = [err93];
}
else {
vErrors.push(err93);
}
errors++;
}
else {
const _errs164 = errors;
for(const key27 in data71){
if(!(((((key27 === "principal") || (key27 === "revision")) || (key27 === "present")) || (key27 === "commands")) || (key27 === "reads"))){
const err94 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/policy",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/2/properties/policy/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key27},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err94];
}
else {
vErrors.push(err94);
}
errors++;
break;
}
}
if(_errs164 === errors){
if(data71.principal !== undefined){
const _errs165 = errors;
if(!(validate56(data71.principal, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/policy/principal",parentData:data71,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid33 = _errs165 === errors;
}
else {
var valid33 = true;
}
if(valid33){
if(data71.revision !== undefined){
const _errs166 = errors;
if(!(validate56(data71.revision, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/policy/revision",parentData:data71,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid33 = _errs166 === errors;
}
else {
var valid33 = true;
}
if(valid33){
if(data71.present !== undefined){
const _errs167 = errors;
if(typeof data71.present !== "boolean"){
const err95 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/policy/present",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/2/properties/policy/properties/present/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err95];
}
else {
vErrors.push(err95);
}
errors++;
}
var valid33 = _errs167 === errors;
}
else {
var valid33 = true;
}
if(valid33){
if(data71.commands !== undefined){
const _errs169 = errors;
if(typeof data71.commands !== "boolean"){
const err96 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/policy/commands",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/2/properties/policy/properties/commands/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err96];
}
else {
vErrors.push(err96);
}
errors++;
}
var valid33 = _errs169 === errors;
}
else {
var valid33 = true;
}
if(valid33){
if(data71.reads !== undefined){
const _errs171 = errors;
if(typeof data71.reads !== "boolean"){
const err97 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/policy/reads",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/2/properties/policy/properties/reads/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err97];
}
else {
vErrors.push(err97);
}
errors++;
}
var valid33 = _errs171 === errors;
}
else {
var valid33 = true;
}
}
}
}
}
}
}
}
else {
const err98 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/policy",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/2/properties/policy/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err98];
}
else {
vErrors.push(err98);
}
errors++;
}
}
}
}
}
}
else {
const err99 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err99];
}
else {
vErrors.push(err99);
}
errors++;
}
}
var _valid5 = _errs159 === errors;
if(_valid5 && valid29){
valid29 = false;
passing3 = [passing3, 2];
}
else {
if(_valid5){
valid29 = true;
passing3 = 2;
if(props10 !== true){
props10 = true;
}
}
const _errs173 = errors;
if(errors === _errs173){
if(data64 && typeof data64 == "object" && !Array.isArray(data64)){
let missing28;
if((data64.identity === undefined) && (missing28 = "identity")){
const err100 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/3/required",keyword:"required",params:{missingProperty: missing28},message:"must have required property '"+missing28+"'"};
if(vErrors === null){
vErrors = [err100];
}
else {
vErrors.push(err100);
}
errors++;
}
else {
const _errs175 = errors;
for(const key28 in data64){
if(!(key28 === "identity")){
const err101 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key28},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err101];
}
else {
vErrors.push(err101);
}
errors++;
break;
}
}
if(_errs175 === errors){
if(data64.identity !== undefined){
let data77 = data64.identity;
const _errs176 = errors;
if(errors === _errs176){
if(data77 && typeof data77 == "object" && !Array.isArray(data77)){
let missing29;
if(((data77.expected === undefined) && (missing29 = "expected")) || ((data77.actual === undefined) && (missing29 = "actual"))){
const err102 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/identity",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/3/properties/identity/required",keyword:"required",params:{missingProperty: missing29},message:"must have required property '"+missing29+"'"};
if(vErrors === null){
vErrors = [err102];
}
else {
vErrors.push(err102);
}
errors++;
}
else {
const _errs178 = errors;
for(const key29 in data77){
if(!((key29 === "expected") || (key29 === "actual"))){
const err103 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/identity",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/3/properties/identity/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key29},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err103];
}
else {
vErrors.push(err103);
}
errors++;
break;
}
}
if(_errs178 === errors){
if(data77.expected !== undefined){
const _errs179 = errors;
if(!(validate64(data77.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/identity/expected",parentData:data77,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
errors = vErrors.length;
}
var valid35 = _errs179 === errors;
}
else {
var valid35 = true;
}
if(valid35){
if(data77.actual !== undefined){
const _errs180 = errors;
if(!(validate64(data77.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/identity/actual",parentData:data77,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
errors = vErrors.length;
}
var valid35 = _errs180 === errors;
}
else {
var valid35 = true;
}
}
}
}
}
else {
const err104 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/identity",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/3/properties/identity/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err105 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err105];
}
else {
vErrors.push(err105);
}
errors++;
}
}
var _valid5 = _errs173 === errors;
if(_valid5 && valid29){
valid29 = false;
passing3 = [passing3, 3];
}
else {
if(_valid5){
valid29 = true;
passing3 = 3;
if(props10 !== true){
props10 = true;
}
}
const _errs181 = errors;
if(errors === _errs181){
if(data64 && typeof data64 == "object" && !Array.isArray(data64)){
let missing30;
if((data64.capacity === undefined) && (missing30 = "capacity")){
const err106 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/4/required",keyword:"required",params:{missingProperty: missing30},message:"must have required property '"+missing30+"'"};
if(vErrors === null){
vErrors = [err106];
}
else {
vErrors.push(err106);
}
errors++;
}
else {
const _errs183 = errors;
for(const key30 in data64){
if(!(key30 === "capacity")){
const err107 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key30},message:"must NOT have additional properties"};
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
if(_errs183 === errors){
if(data64.capacity !== undefined){
let data80 = data64.capacity;
const _errs184 = errors;
if(errors === _errs184){
if(data80 && typeof data80 == "object" && !Array.isArray(data80)){
let missing31;
if((((data80.kind === undefined) && (missing31 = "kind")) || ((data80.actual === undefined) && (missing31 = "actual"))) || ((data80.limit === undefined) && (missing31 = "limit"))){
const err108 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/capacity",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/4/properties/capacity/required",keyword:"required",params:{missingProperty: missing31},message:"must have required property '"+missing31+"'"};
if(vErrors === null){
vErrors = [err108];
}
else {
vErrors.push(err108);
}
errors++;
}
else {
const _errs186 = errors;
for(const key31 in data80){
if(!(((key31 === "kind") || (key31 === "actual")) || (key31 === "limit"))){
const err109 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/capacity",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/4/properties/capacity/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key31},message:"must NOT have additional properties"};
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
if(_errs186 === errors){
if(data80.kind !== undefined){
let data81 = data80.kind;
const _errs187 = errors;
if(typeof data81 !== "string"){
const err110 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/capacity/kind",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/4/properties/capacity/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err110];
}
else {
vErrors.push(err110);
}
errors++;
}
if(!(((((data81 === "service") || (data81 === "caller")) || (data81 === "service_slots")) || (data81 === "sessions")) || (data81 === "caller_sessions"))){
const err111 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/capacity/kind",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/4/properties/capacity/properties/kind/enum",keyword:"enum",params:{allowedValues: schema106.oneOf[8].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[4].properties.capacity.properties.kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err111];
}
else {
vErrors.push(err111);
}
errors++;
}
var valid37 = _errs187 === errors;
}
else {
var valid37 = true;
}
if(valid37){
if(data80.actual !== undefined){
const _errs189 = errors;
if(!(validate65(data80.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/capacity/actual",parentData:data80,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
errors = vErrors.length;
}
var valid37 = _errs189 === errors;
}
else {
var valid37 = true;
}
if(valid37){
if(data80.limit !== undefined){
const _errs190 = errors;
if(!(validate65(data80.limit, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/capacity/limit",parentData:data80,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
errors = vErrors.length;
}
var valid37 = _errs190 === errors;
}
else {
var valid37 = true;
}
}
}
}
}
}
else {
const err112 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/capacity",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/4/properties/capacity/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err113 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err113];
}
else {
vErrors.push(err113);
}
errors++;
}
}
var _valid5 = _errs181 === errors;
if(_valid5 && valid29){
valid29 = false;
passing3 = [passing3, 4];
}
else {
if(_valid5){
valid29 = true;
passing3 = 4;
if(props10 !== true){
props10 = true;
}
}
const _errs191 = errors;
if(errors === _errs191){
if(data64 && typeof data64 == "object" && !Array.isArray(data64)){
let missing32;
if((data64.generation === undefined) && (missing32 = "generation")){
const err114 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/5/required",keyword:"required",params:{missingProperty: missing32},message:"must have required property '"+missing32+"'"};
if(vErrors === null){
vErrors = [err114];
}
else {
vErrors.push(err114);
}
errors++;
}
else {
const _errs193 = errors;
for(const key32 in data64){
if(!(key32 === "generation")){
const err115 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key32},message:"must NOT have additional properties"};
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
if(_errs193 === errors){
if(data64.generation !== undefined){
if(!(validate533(data64.generation, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/generation",parentData:data64,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate533.errors : vErrors.concat(validate533.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err116 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err116];
}
else {
vErrors.push(err116);
}
errors++;
}
}
var _valid5 = _errs191 === errors;
if(_valid5 && valid29){
valid29 = false;
passing3 = [passing3, 5];
}
else {
if(_valid5){
valid29 = true;
passing3 = 5;
if(props10 !== true){
props10 = true;
}
}
const _errs195 = errors;
if(errors === _errs195){
if(data64 && typeof data64 == "object" && !Array.isArray(data64)){
let missing33;
if((data64.session === undefined) && (missing33 = "session")){
const err117 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/6/required",keyword:"required",params:{missingProperty: missing33},message:"must have required property '"+missing33+"'"};
if(vErrors === null){
vErrors = [err117];
}
else {
vErrors.push(err117);
}
errors++;
}
else {
const _errs197 = errors;
for(const key33 in data64){
if(!(key33 === "session")){
const err118 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key33},message:"must NOT have additional properties"};
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
if(_errs197 === errors){
if(data64.session !== undefined){
let data85 = data64.session;
const _errs198 = errors;
if(errors === _errs198){
if(data85 && typeof data85 == "object" && !Array.isArray(data85)){
let missing34;
if(((((data85.phase === undefined) && (missing34 = "phase")) || ((data85.deadline === undefined) && (missing34 = "deadline"))) || ((data85.observed === undefined) && (missing34 = "observed"))) || ((data85.clock_known === undefined) && (missing34 = "clock_known"))){
const err119 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/session",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/6/properties/session/required",keyword:"required",params:{missingProperty: missing34},message:"must have required property '"+missing34+"'"};
if(vErrors === null){
vErrors = [err119];
}
else {
vErrors.push(err119);
}
errors++;
}
else {
const _errs200 = errors;
for(const key34 in data85){
if(!((((key34 === "phase") || (key34 === "deadline")) || (key34 === "observed")) || (key34 === "clock_known"))){
const err120 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/session",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/6/properties/session/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key34},message:"must NOT have additional properties"};
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
if(_errs200 === errors){
if(data85.phase !== undefined){
const _errs201 = errors;
if(!(validate242(data85.phase, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/session/phase",parentData:data85,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate242.errors : vErrors.concat(validate242.errors);
errors = vErrors.length;
}
var valid40 = _errs201 === errors;
}
else {
var valid40 = true;
}
if(valid40){
if(data85.deadline !== undefined){
const _errs202 = errors;
if(!(validate56(data85.deadline, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/session/deadline",parentData:data85,parentDataProperty:"deadline",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid40 = _errs202 === errors;
}
else {
var valid40 = true;
}
if(valid40){
if(data85.observed !== undefined){
const _errs203 = errors;
if(!(validate56(data85.observed, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/session/observed",parentData:data85,parentDataProperty:"observed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid40 = _errs203 === errors;
}
else {
var valid40 = true;
}
if(valid40){
if(data85.clock_known !== undefined){
const _errs204 = errors;
if(typeof data85.clock_known !== "boolean"){
const err121 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/session/clock_known",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/6/properties/session/properties/clock_known/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err121];
}
else {
vErrors.push(err121);
}
errors++;
}
var valid40 = _errs204 === errors;
}
else {
var valid40 = true;
}
}
}
}
}
}
}
else {
const err122 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/session",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/6/properties/session/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
}
else {
const err123 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/6/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err123];
}
else {
vErrors.push(err123);
}
errors++;
}
}
var _valid5 = _errs195 === errors;
if(_valid5 && valid29){
valid29 = false;
passing3 = [passing3, 6];
}
else {
if(_valid5){
valid29 = true;
passing3 = 6;
if(props10 !== true){
props10 = true;
}
}
const _errs206 = errors;
if(errors === _errs206){
if(data64 && typeof data64 == "object" && !Array.isArray(data64)){
let missing35;
if((data64.source === undefined) && (missing35 = "source")){
const err124 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/7/required",keyword:"required",params:{missingProperty: missing35},message:"must have required property '"+missing35+"'"};
if(vErrors === null){
vErrors = [err124];
}
else {
vErrors.push(err124);
}
errors++;
}
else {
const _errs208 = errors;
for(const key35 in data64){
if(!(key35 === "source")){
const err125 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key35},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err125];
}
else {
vErrors.push(err125);
}
errors++;
break;
}
}
if(_errs208 === errors){
if(data64.source !== undefined){
let data90 = data64.source;
const _errs209 = errors;
if(errors === _errs209){
if(data90 && typeof data90 == "object" && !Array.isArray(data90)){
let missing36;
if((((((((data90.expected === undefined) && (missing36 = "expected")) || ((data90.actual === undefined) && (missing36 = "actual"))) || ((data90.present === undefined) && (missing36 = "present"))) || ((data90.published === undefined) && (missing36 = "published"))) || ((data90.target === undefined) && (missing36 = "target"))) || ((data90.resource === undefined) && (missing36 = "resource"))) || ((data90.metadata === undefined) && (missing36 = "metadata"))){
const err126 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/7/properties/source/required",keyword:"required",params:{missingProperty: missing36},message:"must have required property '"+missing36+"'"};
if(vErrors === null){
vErrors = [err126];
}
else {
vErrors.push(err126);
}
errors++;
}
else {
const _errs211 = errors;
for(const key36 in data90){
if(!(((((((key36 === "expected") || (key36 === "actual")) || (key36 === "present")) || (key36 === "published")) || (key36 === "target")) || (key36 === "resource")) || (key36 === "metadata"))){
const err127 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/7/properties/source/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key36},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err127];
}
else {
vErrors.push(err127);
}
errors++;
break;
}
}
if(_errs211 === errors){
if(data90.expected !== undefined){
const _errs212 = errors;
if(!(validate56(data90.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source/expected",parentData:data90,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid42 = _errs212 === errors;
}
else {
var valid42 = true;
}
if(valid42){
if(data90.actual !== undefined){
const _errs213 = errors;
if(!(validate56(data90.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source/actual",parentData:data90,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid42 = _errs213 === errors;
}
else {
var valid42 = true;
}
if(valid42){
if(data90.present !== undefined){
const _errs214 = errors;
if(typeof data90.present !== "boolean"){
const err128 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source/present",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/7/properties/source/properties/present/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err128];
}
else {
vErrors.push(err128);
}
errors++;
}
var valid42 = _errs214 === errors;
}
else {
var valid42 = true;
}
if(valid42){
if(data90.published !== undefined){
const _errs216 = errors;
if(typeof data90.published !== "boolean"){
const err129 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source/published",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/7/properties/source/properties/published/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err129];
}
else {
vErrors.push(err129);
}
errors++;
}
var valid42 = _errs216 === errors;
}
else {
var valid42 = true;
}
if(valid42){
if(data90.target !== undefined){
const _errs218 = errors;
if(!(validate56(data90.target, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source/target",parentData:data90,parentDataProperty:"target",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid42 = _errs218 === errors;
}
else {
var valid42 = true;
}
if(valid42){
if(data90.resource !== undefined){
const _errs219 = errors;
if(!(validate56(data90.resource, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source/resource",parentData:data90,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid42 = _errs219 === errors;
}
else {
var valid42 = true;
}
if(valid42){
if(data90.metadata !== undefined){
const _errs220 = errors;
if(!(validate64(data90.metadata, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source/metadata",parentData:data90,parentDataProperty:"metadata",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
errors = vErrors.length;
}
var valid42 = _errs220 === errors;
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
}
}
}
else {
const err130 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/7/properties/source/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err130];
}
else {
vErrors.push(err130);
}
errors++;
}
}
}
}
}
}
else {
const err131 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/7/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err131];
}
else {
vErrors.push(err131);
}
errors++;
}
}
var _valid5 = _errs206 === errors;
if(_valid5 && valid29){
valid29 = false;
passing3 = [passing3, 7];
}
else {
if(_valid5){
valid29 = true;
passing3 = 7;
if(props10 !== true){
props10 = true;
}
}
const _errs221 = errors;
if(errors === _errs221){
if(data64 && typeof data64 == "object" && !Array.isArray(data64)){
let missing37;
if((data64.lease === undefined) && (missing37 = "lease")){
const err132 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/8/required",keyword:"required",params:{missingProperty: missing37},message:"must have required property '"+missing37+"'"};
if(vErrors === null){
vErrors = [err132];
}
else {
vErrors.push(err132);
}
errors++;
}
else {
const _errs223 = errors;
for(const key37 in data64){
if(!(key37 === "lease")){
const err133 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key37},message:"must NOT have additional properties"};
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
if(_errs223 === errors){
if(data64.lease !== undefined){
let data98 = data64.lease;
const _errs224 = errors;
if(errors === _errs224){
if(data98 && typeof data98 == "object" && !Array.isArray(data98)){
let missing38;
if(((((data98.kind === undefined) && (missing38 = "kind")) || ((data98.requested === undefined) && (missing38 = "requested"))) || ((data98.observed === undefined) && (missing38 = "observed"))) || ((data98.limit === undefined) && (missing38 = "limit"))){
const err134 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/lease",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/8/properties/lease/required",keyword:"required",params:{missingProperty: missing38},message:"must have required property '"+missing38+"'"};
if(vErrors === null){
vErrors = [err134];
}
else {
vErrors.push(err134);
}
errors++;
}
else {
const _errs226 = errors;
for(const key38 in data98){
if(!((((key38 === "kind") || (key38 === "requested")) || (key38 === "observed")) || (key38 === "limit"))){
const err135 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/lease",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/8/properties/lease/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key38},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err135];
}
else {
vErrors.push(err135);
}
errors++;
break;
}
}
if(_errs226 === errors){
if(data98.kind !== undefined){
let data99 = data98.kind;
const _errs227 = errors;
if(typeof data99 !== "string"){
const err136 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/lease/kind",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/8/properties/lease/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err136];
}
else {
vErrors.push(err136);
}
errors++;
}
if(!((((((data99 === "clock") || (data99 === "interval")) || (data99 === "binding")) || (data99 === "process")) || (data99 === "resource")) || (data99 === "observer"))){
const err137 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/lease/kind",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/8/properties/lease/properties/kind/enum",keyword:"enum",params:{allowedValues: schema106.oneOf[8].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[8].properties.lease.properties.kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err137];
}
else {
vErrors.push(err137);
}
errors++;
}
var valid44 = _errs227 === errors;
}
else {
var valid44 = true;
}
if(valid44){
if(data98.requested !== undefined){
const _errs229 = errors;
if(!(validate56(data98.requested, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/lease/requested",parentData:data98,parentDataProperty:"requested",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid44 = _errs229 === errors;
}
else {
var valid44 = true;
}
if(valid44){
if(data98.observed !== undefined){
const _errs230 = errors;
if(!(validate56(data98.observed, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/lease/observed",parentData:data98,parentDataProperty:"observed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid44 = _errs230 === errors;
}
else {
var valid44 = true;
}
if(valid44){
if(data98.limit !== undefined){
const _errs231 = errors;
if(!(validate56(data98.limit, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/lease/limit",parentData:data98,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid44 = _errs231 === errors;
}
else {
var valid44 = true;
}
}
}
}
}
}
}
else {
const err138 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/lease",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/8/properties/lease/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err138];
}
else {
vErrors.push(err138);
}
errors++;
}
}
}
}
}
}
else {
const err139 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/8/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err139];
}
else {
vErrors.push(err139);
}
errors++;
}
}
var _valid5 = _errs221 === errors;
if(_valid5 && valid29){
valid29 = false;
passing3 = [passing3, 8];
}
else {
if(_valid5){
valid29 = true;
passing3 = 8;
if(props10 !== true){
props10 = true;
}
}
const _errs232 = errors;
if(errors === _errs232){
if(data64 && typeof data64 == "object" && !Array.isArray(data64)){
let missing39;
if((data64.attachment === undefined) && (missing39 = "attachment")){
const err140 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/9/required",keyword:"required",params:{missingProperty: missing39},message:"must have required property '"+missing39+"'"};
if(vErrors === null){
vErrors = [err140];
}
else {
vErrors.push(err140);
}
errors++;
}
else {
const _errs234 = errors;
for(const key39 in data64){
if(!(key39 === "attachment")){
const err141 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/9/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key39},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err141];
}
else {
vErrors.push(err141);
}
errors++;
break;
}
}
if(_errs234 === errors){
if(data64.attachment !== undefined){
if(!(validate533(data64.attachment, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/attachment",parentData:data64,parentDataProperty:"attachment",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate533.errors : vErrors.concat(validate533.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err142 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/9/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err142];
}
else {
vErrors.push(err142);
}
errors++;
}
}
var _valid5 = _errs232 === errors;
if(_valid5 && valid29){
valid29 = false;
passing3 = [passing3, 9];
}
else {
if(_valid5){
valid29 = true;
passing3 = 9;
if(props10 !== true){
props10 = true;
}
}
const _errs236 = errors;
if(errors === _errs236){
if(data64 && typeof data64 == "object" && !Array.isArray(data64)){
let missing40;
if((data64.subscription === undefined) && (missing40 = "subscription")){
const err143 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/10/required",keyword:"required",params:{missingProperty: missing40},message:"must have required property '"+missing40+"'"};
if(vErrors === null){
vErrors = [err143];
}
else {
vErrors.push(err143);
}
errors++;
}
else {
const _errs238 = errors;
for(const key40 in data64){
if(!(key40 === "subscription")){
const err144 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/10/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key40},message:"must NOT have additional properties"};
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
if(_errs238 === errors){
if(data64.subscription !== undefined){
let data104 = data64.subscription;
const _errs239 = errors;
if(errors === _errs239){
if(data104 && typeof data104 == "object" && !Array.isArray(data104)){
let missing41;
if(((((data104.expected === undefined) && (missing41 = "expected")) || ((data104.actual === undefined) && (missing41 = "actual"))) || ((data104.requested === undefined) && (missing41 = "requested"))) || ((data104.active === undefined) && (missing41 = "active"))){
const err145 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/subscription",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/10/properties/subscription/required",keyword:"required",params:{missingProperty: missing41},message:"must have required property '"+missing41+"'"};
if(vErrors === null){
vErrors = [err145];
}
else {
vErrors.push(err145);
}
errors++;
}
else {
const _errs241 = errors;
for(const key41 in data104){
if(!((((key41 === "expected") || (key41 === "actual")) || (key41 === "requested")) || (key41 === "active"))){
const err146 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/subscription",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/10/properties/subscription/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key41},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err146];
}
else {
vErrors.push(err146);
}
errors++;
break;
}
}
if(_errs241 === errors){
if(data104.expected !== undefined){
const _errs242 = errors;
if(!(validate56(data104.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/subscription/expected",parentData:data104,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid47 = _errs242 === errors;
}
else {
var valid47 = true;
}
if(valid47){
if(data104.actual !== undefined){
const _errs243 = errors;
if(!(validate56(data104.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/subscription/actual",parentData:data104,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid47 = _errs243 === errors;
}
else {
var valid47 = true;
}
if(valid47){
if(data104.requested !== undefined){
const _errs244 = errors;
if(!(validate56(data104.requested, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/subscription/requested",parentData:data104,parentDataProperty:"requested",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid47 = _errs244 === errors;
}
else {
var valid47 = true;
}
if(valid47){
if(data104.active !== undefined){
const _errs245 = errors;
if(!(validate56(data104.active, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/subscription/active",parentData:data104,parentDataProperty:"active",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid47 = _errs245 === errors;
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
else {
const err147 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/subscription",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/10/properties/subscription/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err148 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/10/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err148];
}
else {
vErrors.push(err148);
}
errors++;
}
}
var _valid5 = _errs236 === errors;
if(_valid5 && valid29){
valid29 = false;
passing3 = [passing3, 10];
}
else {
if(_valid5){
valid29 = true;
passing3 = 10;
if(props10 !== true){
props10 = true;
}
}
const _errs246 = errors;
if(errors === _errs246){
if(data64 && typeof data64 == "object" && !Array.isArray(data64)){
let missing42;
if((data64.renewal === undefined) && (missing42 = "renewal")){
const err149 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/11/required",keyword:"required",params:{missingProperty: missing42},message:"must have required property '"+missing42+"'"};
if(vErrors === null){
vErrors = [err149];
}
else {
vErrors.push(err149);
}
errors++;
}
else {
const _errs248 = errors;
for(const key42 in data64){
if(!(key42 === "renewal")){
const err150 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/11/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key42},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err150];
}
else {
vErrors.push(err150);
}
errors++;
break;
}
}
if(_errs248 === errors){
if(data64.renewal !== undefined){
let data109 = data64.renewal;
const _errs249 = errors;
if(errors === _errs249){
if(data109 && typeof data109 == "object" && !Array.isArray(data109)){
let missing43;
if((((data109.expected === undefined) && (missing43 = "expected")) || ((data109.actual === undefined) && (missing43 = "actual"))) || ((data109.proposed === undefined) && (missing43 = "proposed"))){
const err151 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/renewal",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/11/properties/renewal/required",keyword:"required",params:{missingProperty: missing43},message:"must have required property '"+missing43+"'"};
if(vErrors === null){
vErrors = [err151];
}
else {
vErrors.push(err151);
}
errors++;
}
else {
const _errs251 = errors;
for(const key43 in data109){
if(!(((key43 === "expected") || (key43 === "actual")) || (key43 === "proposed"))){
const err152 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/renewal",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/11/properties/renewal/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key43},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err152];
}
else {
vErrors.push(err152);
}
errors++;
break;
}
}
if(_errs251 === errors){
if(data109.expected !== undefined){
const _errs252 = errors;
if(!(validate56(data109.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/renewal/expected",parentData:data109,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid49 = _errs252 === errors;
}
else {
var valid49 = true;
}
if(valid49){
if(data109.actual !== undefined){
const _errs253 = errors;
if(!(validate56(data109.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/renewal/actual",parentData:data109,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid49 = _errs253 === errors;
}
else {
var valid49 = true;
}
if(valid49){
if(data109.proposed !== undefined){
const _errs254 = errors;
if(!(validate56(data109.proposed, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/renewal/proposed",parentData:data109,parentDataProperty:"proposed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid49 = _errs254 === errors;
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
const err153 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/renewal",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/11/properties/renewal/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err153];
}
else {
vErrors.push(err153);
}
errors++;
}
}
}
}
}
}
else {
const err154 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/11/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err154];
}
else {
vErrors.push(err154);
}
errors++;
}
}
var _valid5 = _errs246 === errors;
if(_valid5 && valid29){
valid29 = false;
passing3 = [passing3, 11];
}
else {
if(_valid5){
valid29 = true;
passing3 = 11;
if(props10 !== true){
props10 = true;
}
}
const _errs255 = errors;
if(errors === _errs255){
if(data64 && typeof data64 == "object" && !Array.isArray(data64)){
let missing44;
if((data64.binding === undefined) && (missing44 = "binding")){
const err155 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/12/required",keyword:"required",params:{missingProperty: missing44},message:"must have required property '"+missing44+"'"};
if(vErrors === null){
vErrors = [err155];
}
else {
vErrors.push(err155);
}
errors++;
}
else {
const _errs257 = errors;
for(const key44 in data64){
if(!(key44 === "binding")){
const err156 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/12/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key44},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err156];
}
else {
vErrors.push(err156);
}
errors++;
break;
}
}
if(_errs257 === errors){
if(data64.binding !== undefined){
let data113 = data64.binding;
const _errs258 = errors;
if(errors === _errs258){
if(data113 && typeof data113 == "object" && !Array.isArray(data113)){
let missing45;
if((((((((data113.expected === undefined) && (missing45 = "expected")) || ((data113.actual === undefined) && (missing45 = "actual"))) || ((data113.expected_codec === undefined) && (missing45 = "expected_codec"))) || ((data113.actual_codec === undefined) && (missing45 = "actual_codec"))) || ((data113.target === undefined) && (missing45 = "target"))) || ((data113.present === undefined) && (missing45 = "present"))) || ((data113.published === undefined) && (missing45 = "published"))){
const err157 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/binding",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/12/properties/binding/required",keyword:"required",params:{missingProperty: missing45},message:"must have required property '"+missing45+"'"};
if(vErrors === null){
vErrors = [err157];
}
else {
vErrors.push(err157);
}
errors++;
}
else {
const _errs260 = errors;
for(const key45 in data113){
if(!(((((((key45 === "expected") || (key45 === "actual")) || (key45 === "expected_codec")) || (key45 === "actual_codec")) || (key45 === "target")) || (key45 === "present")) || (key45 === "published"))){
const err158 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/binding",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/12/properties/binding/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key45},message:"must NOT have additional properties"};
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
if(_errs260 === errors){
if(data113.expected !== undefined){
const _errs261 = errors;
if(!(validate56(data113.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/binding/expected",parentData:data113,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid51 = _errs261 === errors;
}
else {
var valid51 = true;
}
if(valid51){
if(data113.actual !== undefined){
const _errs262 = errors;
if(!(validate56(data113.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/binding/actual",parentData:data113,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid51 = _errs262 === errors;
}
else {
var valid51 = true;
}
if(valid51){
if(data113.expected_codec !== undefined){
const _errs263 = errors;
if(!(validate164(data113.expected_codec, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/binding/expected_codec",parentData:data113,parentDataProperty:"expected_codec",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate164.errors : vErrors.concat(validate164.errors);
errors = vErrors.length;
}
var valid51 = _errs263 === errors;
}
else {
var valid51 = true;
}
if(valid51){
if(data113.actual_codec !== undefined){
const _errs264 = errors;
if(!(validate164(data113.actual_codec, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/binding/actual_codec",parentData:data113,parentDataProperty:"actual_codec",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate164.errors : vErrors.concat(validate164.errors);
errors = vErrors.length;
}
var valid51 = _errs264 === errors;
}
else {
var valid51 = true;
}
if(valid51){
if(data113.target !== undefined){
const _errs265 = errors;
if(!(validate56(data113.target, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/binding/target",parentData:data113,parentDataProperty:"target",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid51 = _errs265 === errors;
}
else {
var valid51 = true;
}
if(valid51){
if(data113.present !== undefined){
const _errs266 = errors;
if(typeof data113.present !== "boolean"){
const err159 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/binding/present",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/12/properties/binding/properties/present/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err159];
}
else {
vErrors.push(err159);
}
errors++;
}
var valid51 = _errs266 === errors;
}
else {
var valid51 = true;
}
if(valid51){
if(data113.published !== undefined){
const _errs268 = errors;
if(typeof data113.published !== "boolean"){
const err160 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/binding/published",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/12/properties/binding/properties/published/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err160];
}
else {
vErrors.push(err160);
}
errors++;
}
var valid51 = _errs268 === errors;
}
else {
var valid51 = true;
}
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
const err161 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/binding",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/12/properties/binding/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err162 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/12/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err162];
}
else {
vErrors.push(err162);
}
errors++;
}
}
var _valid5 = _errs255 === errors;
if(_valid5 && valid29){
valid29 = false;
passing3 = [passing3, 12];
}
else {
if(_valid5){
valid29 = true;
passing3 = 12;
if(props10 !== true){
props10 = true;
}
}
const _errs270 = errors;
if(errors === _errs270){
if(data64 && typeof data64 == "object" && !Array.isArray(data64)){
let missing46;
if((data64.refresh === undefined) && (missing46 = "refresh")){
const err163 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/13/required",keyword:"required",params:{missingProperty: missing46},message:"must have required property '"+missing46+"'"};
if(vErrors === null){
vErrors = [err163];
}
else {
vErrors.push(err163);
}
errors++;
}
else {
const _errs272 = errors;
for(const key46 in data64){
if(!(key46 === "refresh")){
const err164 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/13/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key46},message:"must NOT have additional properties"};
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
if(_errs272 === errors){
if(data64.refresh !== undefined){
let data121 = data64.refresh;
const _errs273 = errors;
if(errors === _errs273){
if(data121 && typeof data121 == "object" && !Array.isArray(data121)){
let missing47;
if((((data121.expected === undefined) && (missing47 = "expected")) || ((data121.actual === undefined) && (missing47 = "actual"))) || ((data121.phase === undefined) && (missing47 = "phase"))){
const err165 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/refresh",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/13/properties/refresh/required",keyword:"required",params:{missingProperty: missing47},message:"must have required property '"+missing47+"'"};
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
for(const key47 in data121){
if(!(((key47 === "expected") || (key47 === "actual")) || (key47 === "phase"))){
const err166 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/refresh",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/13/properties/refresh/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key47},message:"must NOT have additional properties"};
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
if(data121.expected !== undefined){
const _errs276 = errors;
if(!(validate225(data121.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/refresh/expected",parentData:data121,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
errors = vErrors.length;
}
var valid53 = _errs276 === errors;
}
else {
var valid53 = true;
}
if(valid53){
if(data121.actual !== undefined){
const _errs277 = errors;
if(!(validate225(data121.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/refresh/actual",parentData:data121,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
errors = vErrors.length;
}
var valid53 = _errs277 === errors;
}
else {
var valid53 = true;
}
if(valid53){
if(data121.phase !== undefined){
const _errs278 = errors;
if(!(validate518(data121.phase, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/refresh/phase",parentData:data121,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate518.errors : vErrors.concat(validate518.errors);
errors = vErrors.length;
}
var valid53 = _errs278 === errors;
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
const err167 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/refresh",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/13/properties/refresh/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err167];
}
else {
vErrors.push(err167);
}
errors++;
}
}
}
}
}
}
else {
const err168 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/13/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err168];
}
else {
vErrors.push(err168);
}
errors++;
}
}
var _valid5 = _errs270 === errors;
if(_valid5 && valid29){
valid29 = false;
passing3 = [passing3, 13];
}
else {
if(_valid5){
valid29 = true;
passing3 = 13;
if(props10 !== true){
props10 = true;
}
}
const _errs279 = errors;
if(errors === _errs279){
if(data64 && typeof data64 == "object" && !Array.isArray(data64)){
let missing48;
if((data64.frame === undefined) && (missing48 = "frame")){
const err169 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/14/required",keyword:"required",params:{missingProperty: missing48},message:"must have required property '"+missing48+"'"};
if(vErrors === null){
vErrors = [err169];
}
else {
vErrors.push(err169);
}
errors++;
}
else {
const _errs281 = errors;
for(const key48 in data64){
if(!(key48 === "frame")){
const err170 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/14/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key48},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err170];
}
else {
vErrors.push(err170);
}
errors++;
break;
}
}
if(_errs281 === errors){
if(data64.frame !== undefined){
let data125 = data64.frame;
const _errs282 = errors;
if(errors === _errs282){
if(data125 && typeof data125 == "object" && !Array.isArray(data125)){
let missing49;
if(((((data125.correlation === undefined) && (missing49 = "correlation")) || ((data125.expected === undefined) && (missing49 = "expected"))) || ((data125.actual === undefined) && (missing49 = "actual"))) || ((data125.kind === undefined) && (missing49 = "kind"))){
const err171 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/frame",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/14/properties/frame/required",keyword:"required",params:{missingProperty: missing49},message:"must have required property '"+missing49+"'"};
if(vErrors === null){
vErrors = [err171];
}
else {
vErrors.push(err171);
}
errors++;
}
else {
const _errs284 = errors;
for(const key49 in data125){
if(!(((((key49 === "correlation") || (key49 === "expected")) || (key49 === "actual")) || (key49 === "kind")) || (key49 === "actual_known"))){
const err172 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/frame",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/14/properties/frame/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key49},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err172];
}
else {
vErrors.push(err172);
}
errors++;
break;
}
}
if(_errs284 === errors){
if(data125.correlation !== undefined){
const _errs285 = errors;
if(!(validate56(data125.correlation, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/frame/correlation",parentData:data125,parentDataProperty:"correlation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid55 = _errs285 === errors;
}
else {
var valid55 = true;
}
if(valid55){
if(data125.expected !== undefined){
const _errs286 = errors;
if(!(validate56(data125.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/frame/expected",parentData:data125,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid55 = _errs286 === errors;
}
else {
var valid55 = true;
}
if(valid55){
if(data125.actual !== undefined){
const _errs287 = errors;
if(!(validate56(data125.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/frame/actual",parentData:data125,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid55 = _errs287 === errors;
}
else {
var valid55 = true;
}
if(valid55){
if(data125.kind !== undefined){
let data129 = data125.kind;
const _errs288 = errors;
if(typeof data129 !== "string"){
const err173 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/frame/kind",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/14/properties/frame/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err173];
}
else {
vErrors.push(err173);
}
errors++;
}
if(!((((data129 === "reply_source") || (data129 === "observer")) || (data129 === "timer")) || (data129 === "administrator"))){
const err174 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/frame/kind",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/14/properties/frame/properties/kind/enum",keyword:"enum",params:{allowedValues: schema106.oneOf[8].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[14].properties.frame.properties.kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err174];
}
else {
vErrors.push(err174);
}
errors++;
}
var valid55 = _errs288 === errors;
}
else {
var valid55 = true;
}
if(valid55){
if(data125.actual_known !== undefined){
const _errs290 = errors;
if(typeof data125.actual_known !== "boolean"){
const err175 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/frame/actual_known",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/14/properties/frame/properties/actual_known/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err175];
}
else {
vErrors.push(err175);
}
errors++;
}
var valid55 = _errs290 === errors;
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
const err176 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/frame",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/14/properties/frame/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err176];
}
else {
vErrors.push(err176);
}
errors++;
}
}
}
}
}
}
else {
const err177 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/14/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err177];
}
else {
vErrors.push(err177);
}
errors++;
}
}
var _valid5 = _errs279 === errors;
if(_valid5 && valid29){
valid29 = false;
passing3 = [passing3, 14];
}
else {
if(_valid5){
valid29 = true;
passing3 = 14;
if(props10 !== true){
props10 = true;
}
}
const _errs292 = errors;
if(errors === _errs292){
if(data64 && typeof data64 == "object" && !Array.isArray(data64)){
let missing50;
if((data64.target === undefined) && (missing50 = "target")){
const err178 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/15/required",keyword:"required",params:{missingProperty: missing50},message:"must have required property '"+missing50+"'"};
if(vErrors === null){
vErrors = [err178];
}
else {
vErrors.push(err178);
}
errors++;
}
else {
const _errs294 = errors;
for(const key50 in data64){
if(!(key50 === "target")){
const err179 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/15/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key50},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err179];
}
else {
vErrors.push(err179);
}
errors++;
break;
}
}
if(_errs294 === errors){
if(data64.target !== undefined){
let data131 = data64.target;
const _errs295 = errors;
if(errors === _errs295){
if(data131 && typeof data131 == "object" && !Array.isArray(data131)){
let missing51;
if((((data131.expected === undefined) && (missing51 = "expected")) || ((data131.actual === undefined) && (missing51 = "actual"))) || ((data131.kind === undefined) && (missing51 = "kind"))){
const err180 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/target",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/15/properties/target/required",keyword:"required",params:{missingProperty: missing51},message:"must have required property '"+missing51+"'"};
if(vErrors === null){
vErrors = [err180];
}
else {
vErrors.push(err180);
}
errors++;
}
else {
const _errs297 = errors;
for(const key51 in data131){
if(!(((key51 === "expected") || (key51 === "actual")) || (key51 === "kind"))){
const err181 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/target",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/15/properties/target/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key51},message:"must NOT have additional properties"};
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
if(_errs297 === errors){
if(data131.expected !== undefined){
const _errs298 = errors;
if(!(validate56(data131.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/target/expected",parentData:data131,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid57 = _errs298 === errors;
}
else {
var valid57 = true;
}
if(valid57){
if(data131.actual !== undefined){
const _errs299 = errors;
if(!(validate56(data131.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/target/actual",parentData:data131,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid57 = _errs299 === errors;
}
else {
var valid57 = true;
}
if(valid57){
if(data131.kind !== undefined){
let data134 = data131.kind;
const _errs300 = errors;
if(typeof data134 !== "string"){
const err182 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/target/kind",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/15/properties/target/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err182];
}
else {
vErrors.push(err182);
}
errors++;
}
if(!(((data134 === "source") || (data134 === "resource")) || (data134 === "partition"))){
const err183 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/target/kind",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/15/properties/target/properties/kind/enum",keyword:"enum",params:{allowedValues: schema106.oneOf[8].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[15].properties.target.properties.kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err183];
}
else {
vErrors.push(err183);
}
errors++;
}
var valid57 = _errs300 === errors;
}
else {
var valid57 = true;
}
}
}
}
}
}
else {
const err184 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/target",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/15/properties/target/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err184];
}
else {
vErrors.push(err184);
}
errors++;
}
}
}
}
}
}
else {
const err185 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/15/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err185];
}
else {
vErrors.push(err185);
}
errors++;
}
}
var _valid5 = _errs292 === errors;
if(_valid5 && valid29){
valid29 = false;
passing3 = [passing3, 15];
}
else {
if(_valid5){
valid29 = true;
passing3 = 15;
if(props10 !== true){
props10 = true;
}
}
const _errs302 = errors;
if(errors === _errs302){
if(data64 && typeof data64 == "object" && !Array.isArray(data64)){
let missing52;
if((data64.basis === undefined) && (missing52 = "basis")){
const err186 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/16/required",keyword:"required",params:{missingProperty: missing52},message:"must have required property '"+missing52+"'"};
if(vErrors === null){
vErrors = [err186];
}
else {
vErrors.push(err186);
}
errors++;
}
else {
const _errs304 = errors;
for(const key52 in data64){
if(!(key52 === "basis")){
const err187 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/16/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key52},message:"must NOT have additional properties"};
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
if(_errs304 === errors){
if(data64.basis !== undefined){
let data135 = data64.basis;
const _errs305 = errors;
if(errors === _errs305){
if(data135 && typeof data135 == "object" && !Array.isArray(data135)){
let missing53;
if((((data135.expected === undefined) && (missing53 = "expected")) || ((data135.actual === undefined) && (missing53 = "actual"))) || ((data135.kind === undefined) && (missing53 = "kind"))){
const err188 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/basis",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/16/properties/basis/required",keyword:"required",params:{missingProperty: missing53},message:"must have required property '"+missing53+"'"};
if(vErrors === null){
vErrors = [err188];
}
else {
vErrors.push(err188);
}
errors++;
}
else {
const _errs307 = errors;
for(const key53 in data135){
if(!(((key53 === "expected") || (key53 === "actual")) || (key53 === "kind"))){
const err189 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/basis",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/16/properties/basis/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key53},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err189];
}
else {
vErrors.push(err189);
}
errors++;
break;
}
}
if(_errs307 === errors){
if(data135.expected !== undefined){
const _errs308 = errors;
if(!(validate64(data135.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/basis/expected",parentData:data135,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
errors = vErrors.length;
}
var valid59 = _errs308 === errors;
}
else {
var valid59 = true;
}
if(valid59){
if(data135.actual !== undefined){
const _errs309 = errors;
if(!(validate64(data135.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/basis/actual",parentData:data135,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
errors = vErrors.length;
}
var valid59 = _errs309 === errors;
}
else {
var valid59 = true;
}
if(valid59){
if(data135.kind !== undefined){
let data138 = data135.kind;
const _errs310 = errors;
if(typeof data138 !== "string"){
const err190 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/basis/kind",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/16/properties/basis/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err190];
}
else {
vErrors.push(err190);
}
errors++;
}
if(!(((data138 === "schema") || (data138 === "contract")) || (data138 === "metadata"))){
const err191 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/basis/kind",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/16/properties/basis/properties/kind/enum",keyword:"enum",params:{allowedValues: schema106.oneOf[8].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[16].properties.basis.properties.kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err191];
}
else {
vErrors.push(err191);
}
errors++;
}
var valid59 = _errs310 === errors;
}
else {
var valid59 = true;
}
}
}
}
}
}
else {
const err192 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/basis",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/16/properties/basis/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err192];
}
else {
vErrors.push(err192);
}
errors++;
}
}
}
}
}
}
else {
const err193 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/16/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err193];
}
else {
vErrors.push(err193);
}
errors++;
}
}
var _valid5 = _errs302 === errors;
if(_valid5 && valid29){
valid29 = false;
passing3 = [passing3, 16];
}
else {
if(_valid5){
valid29 = true;
passing3 = 16;
if(props10 !== true){
props10 = true;
}
}
const _errs312 = errors;
if(errors === _errs312){
if(data64 && typeof data64 == "object" && !Array.isArray(data64)){
let missing54;
if((data64.source_kind === undefined) && (missing54 = "source_kind")){
const err194 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/17/required",keyword:"required",params:{missingProperty: missing54},message:"must have required property '"+missing54+"'"};
if(vErrors === null){
vErrors = [err194];
}
else {
vErrors.push(err194);
}
errors++;
}
else {
const _errs314 = errors;
for(const key54 in data64){
if(!(key54 === "source_kind")){
const err195 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/17/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key54},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err195];
}
else {
vErrors.push(err195);
}
errors++;
break;
}
}
if(_errs314 === errors){
if(data64.source_kind !== undefined){
let data139 = data64.source_kind;
const _errs315 = errors;
if(errors === _errs315){
if(data139 && typeof data139 == "object" && !Array.isArray(data139)){
let missing55;
if(((data139.expected === undefined) && (missing55 = "expected")) || ((data139.actual === undefined) && (missing55 = "actual"))){
const err196 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source_kind",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/17/properties/source_kind/required",keyword:"required",params:{missingProperty: missing55},message:"must have required property '"+missing55+"'"};
if(vErrors === null){
vErrors = [err196];
}
else {
vErrors.push(err196);
}
errors++;
}
else {
const _errs317 = errors;
for(const key55 in data139){
if(!((key55 === "expected") || (key55 === "actual"))){
const err197 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source_kind",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/17/properties/source_kind/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key55},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err197];
}
else {
vErrors.push(err197);
}
errors++;
break;
}
}
if(_errs317 === errors){
if(data139.expected !== undefined){
const _errs318 = errors;
if(!(validate571(data139.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source_kind/expected",parentData:data139,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate571.errors : vErrors.concat(validate571.errors);
errors = vErrors.length;
}
var valid61 = _errs318 === errors;
}
else {
var valid61 = true;
}
if(valid61){
if(data139.actual !== undefined){
const _errs319 = errors;
if(!(validate571(data139.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source_kind/actual",parentData:data139,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate571.errors : vErrors.concat(validate571.errors);
errors = vErrors.length;
}
var valid61 = _errs319 === errors;
}
else {
var valid61 = true;
}
}
}
}
}
else {
const err198 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source_kind",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/17/properties/source_kind/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err198];
}
else {
vErrors.push(err198);
}
errors++;
}
}
}
}
}
}
else {
const err199 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/17/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err199];
}
else {
vErrors.push(err199);
}
errors++;
}
}
var _valid5 = _errs312 === errors;
if(_valid5 && valid29){
valid29 = false;
passing3 = [passing3, 17];
}
else {
if(_valid5){
valid29 = true;
passing3 = 17;
if(props10 !== true){
props10 = true;
}
}
const _errs320 = errors;
if(errors === _errs320){
if(data64 && typeof data64 == "object" && !Array.isArray(data64)){
let missing56;
if((data64.table === undefined) && (missing56 = "table")){
const err200 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/18/required",keyword:"required",params:{missingProperty: missing56},message:"must have required property '"+missing56+"'"};
if(vErrors === null){
vErrors = [err200];
}
else {
vErrors.push(err200);
}
errors++;
}
else {
const _errs322 = errors;
for(const key56 in data64){
if(!(key56 === "table")){
const err201 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/18/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key56},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err201];
}
else {
vErrors.push(err201);
}
errors++;
break;
}
}
if(_errs322 === errors){
if(data64.table !== undefined){
if(!(validate225(data64.table, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/table",parentData:data64,parentDataProperty:"table",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err202 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/18/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err202];
}
else {
vErrors.push(err202);
}
errors++;
}
}
var _valid5 = _errs320 === errors;
if(_valid5 && valid29){
valid29 = false;
passing3 = [passing3, 18];
}
else {
if(_valid5){
valid29 = true;
passing3 = 18;
if(props10 !== true){
props10 = true;
}
}
const _errs324 = errors;
if(errors === _errs324){
if(data64 && typeof data64 == "object" && !Array.isArray(data64)){
let missing57;
if((data64.watch_type === undefined) && (missing57 = "watch_type")){
const err203 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/19/required",keyword:"required",params:{missingProperty: missing57},message:"must have required property '"+missing57+"'"};
if(vErrors === null){
vErrors = [err203];
}
else {
vErrors.push(err203);
}
errors++;
}
else {
const _errs326 = errors;
for(const key57 in data64){
if(!(key57 === "watch_type")){
const err204 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/19/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key57},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err204];
}
else {
vErrors.push(err204);
}
errors++;
break;
}
}
if(_errs326 === errors){
if(data64.watch_type !== undefined){
let data143 = data64.watch_type;
const _errs327 = errors;
if(errors === _errs327){
if(data143 && typeof data143 == "object" && !Array.isArray(data143)){
let missing58;
if(((data143.expected === undefined) && (missing58 = "expected")) || ((data143.actual === undefined) && (missing58 = "actual"))){
const err205 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_type",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/19/properties/watch_type/required",keyword:"required",params:{missingProperty: missing58},message:"must have required property '"+missing58+"'"};
if(vErrors === null){
vErrors = [err205];
}
else {
vErrors.push(err205);
}
errors++;
}
else {
const _errs329 = errors;
for(const key58 in data143){
if(!(((key58 === "expected") || (key58 === "actual")) || (key58 === "column"))){
const err206 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_type",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/19/properties/watch_type/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key58},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err206];
}
else {
vErrors.push(err206);
}
errors++;
break;
}
}
if(_errs329 === errors){
if(data143.expected !== undefined){
const _errs330 = errors;
if(!(validate575(data143.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_type/expected",parentData:data143,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate575.errors : vErrors.concat(validate575.errors);
errors = vErrors.length;
}
var valid64 = _errs330 === errors;
}
else {
var valid64 = true;
}
if(valid64){
if(data143.actual !== undefined){
const _errs331 = errors;
if(!(validate575(data143.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_type/actual",parentData:data143,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate575.errors : vErrors.concat(validate575.errors);
errors = vErrors.length;
}
var valid64 = _errs331 === errors;
}
else {
var valid64 = true;
}
if(valid64){
if(data143.column !== undefined){
const _errs332 = errors;
if(!(validate65(data143.column, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_type/column",parentData:data143,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
errors = vErrors.length;
}
var valid64 = _errs332 === errors;
}
else {
var valid64 = true;
}
}
}
}
}
}
else {
const err207 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_type",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/19/properties/watch_type/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err207];
}
else {
vErrors.push(err207);
}
errors++;
}
}
}
}
}
}
else {
const err208 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/19/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err208];
}
else {
vErrors.push(err208);
}
errors++;
}
}
var _valid5 = _errs324 === errors;
if(_valid5 && valid29){
valid29 = false;
passing3 = [passing3, 19];
}
else {
if(_valid5){
valid29 = true;
passing3 = 19;
if(props10 !== true){
props10 = true;
}
}
const _errs333 = errors;
if(errors === _errs333){
if(data64 && typeof data64 == "object" && !Array.isArray(data64)){
let missing59;
if((data64.progress === undefined) && (missing59 = "progress")){
const err209 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/20/required",keyword:"required",params:{missingProperty: missing59},message:"must have required property '"+missing59+"'"};
if(vErrors === null){
vErrors = [err209];
}
else {
vErrors.push(err209);
}
errors++;
}
else {
const _errs335 = errors;
for(const key59 in data64){
if(!(key59 === "progress")){
const err210 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/20/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key59},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err210];
}
else {
vErrors.push(err210);
}
errors++;
break;
}
}
if(_errs335 === errors){
if(data64.progress !== undefined){
let data147 = data64.progress;
const _errs336 = errors;
if(errors === _errs336){
if(data147 && typeof data147 == "object" && !Array.isArray(data147)){
let missing60;
if((((((data147.present === undefined) && (missing60 = "present")) || ((data147.actual === undefined) && (missing60 = "actual"))) || ((data147.limit === undefined) && (missing60 = "limit"))) || ((data147.key === undefined) && (missing60 = "key"))) || ((data147.length === undefined) && (missing60 = "length"))){
const err211 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/progress",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/20/properties/progress/required",keyword:"required",params:{missingProperty: missing60},message:"must have required property '"+missing60+"'"};
if(vErrors === null){
vErrors = [err211];
}
else {
vErrors.push(err211);
}
errors++;
}
else {
const _errs338 = errors;
for(const key60 in data147){
if(!(((((key60 === "present") || (key60 === "actual")) || (key60 === "limit")) || (key60 === "key")) || (key60 === "length"))){
const err212 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/progress",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/20/properties/progress/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key60},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err212];
}
else {
vErrors.push(err212);
}
errors++;
break;
}
}
if(_errs338 === errors){
if(data147.present !== undefined){
const _errs339 = errors;
if(typeof data147.present !== "boolean"){
const err213 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/progress/present",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/20/properties/progress/properties/present/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err213];
}
else {
vErrors.push(err213);
}
errors++;
}
var valid66 = _errs339 === errors;
}
else {
var valid66 = true;
}
if(valid66){
if(data147.actual !== undefined){
const _errs341 = errors;
if(!(validate56(data147.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/progress/actual",parentData:data147,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid66 = _errs341 === errors;
}
else {
var valid66 = true;
}
if(valid66){
if(data147.limit !== undefined){
const _errs342 = errors;
if(!(validate56(data147.limit, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/progress/limit",parentData:data147,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid66 = _errs342 === errors;
}
else {
var valid66 = true;
}
if(valid66){
if(data147.key !== undefined){
const _errs343 = errors;
if(!(validate64(data147.key, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/progress/key",parentData:data147,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
errors = vErrors.length;
}
var valid66 = _errs343 === errors;
}
else {
var valid66 = true;
}
if(valid66){
if(data147.length !== undefined){
const _errs344 = errors;
if(!(validate65(data147.length, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/progress/length",parentData:data147,parentDataProperty:"length",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
errors = vErrors.length;
}
var valid66 = _errs344 === errors;
}
else {
var valid66 = true;
}
}
}
}
}
}
}
}
else {
const err214 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/progress",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/20/properties/progress/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err214];
}
else {
vErrors.push(err214);
}
errors++;
}
}
}
}
}
}
else {
const err215 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/20/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err215];
}
else {
vErrors.push(err215);
}
errors++;
}
}
var _valid5 = _errs333 === errors;
if(_valid5 && valid29){
valid29 = false;
passing3 = [passing3, 20];
}
else {
if(_valid5){
valid29 = true;
passing3 = 20;
if(props10 !== true){
props10 = true;
}
}
const _errs345 = errors;
if(errors === _errs345){
if(data64 && typeof data64 == "object" && !Array.isArray(data64)){
let missing61;
if((data64.reader_identity === undefined) && (missing61 = "reader_identity")){
const err216 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/21/required",keyword:"required",params:{missingProperty: missing61},message:"must have required property '"+missing61+"'"};
if(vErrors === null){
vErrors = [err216];
}
else {
vErrors.push(err216);
}
errors++;
}
else {
const _errs347 = errors;
for(const key61 in data64){
if(!(key61 === "reader_identity")){
const err217 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/21/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key61},message:"must NOT have additional properties"};
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
if(_errs347 === errors){
if(data64.reader_identity !== undefined){
let data153 = data64.reader_identity;
const _errs348 = errors;
if(errors === _errs348){
if(data153 && typeof data153 == "object" && !Array.isArray(data153)){
let missing62;
if((((data153.field === undefined) && (missing62 = "field")) || ((data153.expected === undefined) && (missing62 = "expected"))) || ((data153.actual === undefined) && (missing62 = "actual"))){
const err218 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_identity",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/21/properties/reader_identity/required",keyword:"required",params:{missingProperty: missing62},message:"must have required property '"+missing62+"'"};
if(vErrors === null){
vErrors = [err218];
}
else {
vErrors.push(err218);
}
errors++;
}
else {
const _errs350 = errors;
for(const key62 in data153){
if(!((((((key62 === "field") || (key62 === "expected")) || (key62 === "actual")) || (key62 === "present")) || (key62 === "policy_revision")) || (key62 === "policy_known"))){
const err219 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_identity",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/21/properties/reader_identity/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key62},message:"must NOT have additional properties"};
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
if(_errs350 === errors){
if(data153.field !== undefined){
let data154 = data153.field;
const _errs351 = errors;
if(typeof data154 !== "string"){
const err220 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_identity/field",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/21/properties/reader_identity/properties/field/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err220];
}
else {
vErrors.push(err220);
}
errors++;
}
if(!((((data154 === "principal") || (data154 === "pid")) || (data154 === "permissions")) || (data154 === "turn_pid"))){
const err221 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_identity/field",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/21/properties/reader_identity/properties/field/enum",keyword:"enum",params:{allowedValues: schema106.oneOf[8].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[21].properties.reader_identity.properties.field.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err221];
}
else {
vErrors.push(err221);
}
errors++;
}
var valid68 = _errs351 === errors;
}
else {
var valid68 = true;
}
if(valid68){
if(data153.expected !== undefined){
const _errs353 = errors;
if(!(validate56(data153.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_identity/expected",parentData:data153,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid68 = _errs353 === errors;
}
else {
var valid68 = true;
}
if(valid68){
if(data153.actual !== undefined){
const _errs354 = errors;
if(!(validate56(data153.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_identity/actual",parentData:data153,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid68 = _errs354 === errors;
}
else {
var valid68 = true;
}
if(valid68){
if(data153.present !== undefined){
const _errs355 = errors;
if(typeof data153.present !== "boolean"){
const err222 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_identity/present",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/21/properties/reader_identity/properties/present/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err222];
}
else {
vErrors.push(err222);
}
errors++;
}
var valid68 = _errs355 === errors;
}
else {
var valid68 = true;
}
if(valid68){
if(data153.policy_revision !== undefined){
const _errs357 = errors;
if(!(validate56(data153.policy_revision, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_identity/policy_revision",parentData:data153,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid68 = _errs357 === errors;
}
else {
var valid68 = true;
}
if(valid68){
if(data153.policy_known !== undefined){
const _errs358 = errors;
if(typeof data153.policy_known !== "boolean"){
const err223 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_identity/policy_known",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/21/properties/reader_identity/properties/policy_known/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err223];
}
else {
vErrors.push(err223);
}
errors++;
}
var valid68 = _errs358 === errors;
}
else {
var valid68 = true;
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
const err224 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_identity",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/21/properties/reader_identity/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err224];
}
else {
vErrors.push(err224);
}
errors++;
}
}
}
}
}
}
else {
const err225 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/21/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err225];
}
else {
vErrors.push(err225);
}
errors++;
}
}
var _valid5 = _errs345 === errors;
if(_valid5 && valid29){
valid29 = false;
passing3 = [passing3, 21];
}
else {
if(_valid5){
valid29 = true;
passing3 = 21;
if(props10 !== true){
props10 = true;
}
}
const _errs360 = errors;
if(errors === _errs360){
if(data64 && typeof data64 == "object" && !Array.isArray(data64)){
let missing63;
if((data64.reader_failure === undefined) && (missing63 = "reader_failure")){
const err226 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/22/required",keyword:"required",params:{missingProperty: missing63},message:"must have required property '"+missing63+"'"};
if(vErrors === null){
vErrors = [err226];
}
else {
vErrors.push(err226);
}
errors++;
}
else {
const _errs362 = errors;
for(const key63 in data64){
if(!(key63 === "reader_failure")){
const err227 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/22/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key63},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err227];
}
else {
vErrors.push(err227);
}
errors++;
break;
}
}
if(_errs362 === errors){
if(data64.reader_failure !== undefined){
let data160 = data64.reader_failure;
const _errs363 = errors;
if(errors === _errs363){
if(data160 && typeof data160 == "object" && !Array.isArray(data160)){
let missing64;
if(((((data160.operation === undefined) && (missing64 = "operation")) || ((data160.principal === undefined) && (missing64 = "principal"))) || ((data160.resource === undefined) && (missing64 = "resource"))) || ((data160.cause === undefined) && (missing64 = "cause"))){
const err228 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_failure",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/22/properties/reader_failure/required",keyword:"required",params:{missingProperty: missing64},message:"must have required property '"+missing64+"'"};
if(vErrors === null){
vErrors = [err228];
}
else {
vErrors.push(err228);
}
errors++;
}
else {
const _errs365 = errors;
for(const key64 in data160){
if(!(((((key64 === "operation") || (key64 === "principal")) || (key64 === "resource")) || (key64 === "namespace")) || (key64 === "cause"))){
const err229 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_failure",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/22/properties/reader_failure/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key64},message:"must NOT have additional properties"};
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
if(_errs365 === errors){
if(data160.operation !== undefined){
let data161 = data160.operation;
const _errs366 = errors;
if(typeof data161 !== "string"){
const err230 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_failure/operation",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/22/properties/reader_failure/properties/operation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err230];
}
else {
vErrors.push(err230);
}
errors++;
}
if(!((((data161 === "identity") || (data161 === "source")) || (data161 === "requester")) || (data161 === "result"))){
const err231 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_failure/operation",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/22/properties/reader_failure/properties/operation/enum",keyword:"enum",params:{allowedValues: schema106.oneOf[8].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[22].properties.reader_failure.properties.operation.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err231];
}
else {
vErrors.push(err231);
}
errors++;
}
var valid70 = _errs366 === errors;
}
else {
var valid70 = true;
}
if(valid70){
if(data160.principal !== undefined){
const _errs368 = errors;
if(!(validate56(data160.principal, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_failure/principal",parentData:data160,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid70 = _errs368 === errors;
}
else {
var valid70 = true;
}
if(valid70){
if(data160.resource !== undefined){
const _errs369 = errors;
if(!(validate56(data160.resource, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_failure/resource",parentData:data160,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid70 = _errs369 === errors;
}
else {
var valid70 = true;
}
if(valid70){
if(data160.namespace !== undefined){
const _errs370 = errors;
if(!(validate56(data160.namespace, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_failure/namespace",parentData:data160,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid70 = _errs370 === errors;
}
else {
var valid70 = true;
}
if(valid70){
if(data160.cause !== undefined){
let data165 = data160.cause;
const _errs371 = errors;
if(typeof data165 !== "string"){
const err232 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_failure/cause",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/22/properties/reader_failure/properties/cause/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err232];
}
else {
vErrors.push(err232);
}
errors++;
}
if(!(((((((((((data165 === "AccessDenied") || (data165 === "Forbidden")) || (data165 === "StateResourceExpired")) || (data165 === "UnknownStateResource")) || (data165 === "DeadlineExpired")) || (data165 === "RetiredProcess")) || (data165 === "CatalogDenied")) || (data165 === "QueryDenied")) || (data165 === "QuerySourceUnavailable")) || (data165 === "ResultUnavailable")) || (data165 === "PublicationNotPublished"))){
const err233 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_failure/cause",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/22/properties/reader_failure/properties/cause/enum",keyword:"enum",params:{allowedValues: schema106.oneOf[8].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[22].properties.reader_failure.properties.cause.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err233];
}
else {
vErrors.push(err233);
}
errors++;
}
var valid70 = _errs371 === errors;
}
else {
var valid70 = true;
}
}
}
}
}
}
}
}
else {
const err234 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_failure",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/22/properties/reader_failure/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err235 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/22/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err235];
}
else {
vErrors.push(err235);
}
errors++;
}
}
var _valid5 = _errs360 === errors;
if(_valid5 && valid29){
valid29 = false;
passing3 = [passing3, 22];
}
else {
if(_valid5){
valid29 = true;
passing3 = 22;
if(props10 !== true){
props10 = true;
}
}
const _errs373 = errors;
if(errors === _errs373){
if(data64 && typeof data64 == "object" && !Array.isArray(data64)){
let missing65;
if((data64.reader_resource === undefined) && (missing65 = "reader_resource")){
const err236 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/required",keyword:"required",params:{missingProperty: missing65},message:"must have required property '"+missing65+"'"};
if(vErrors === null){
vErrors = [err236];
}
else {
vErrors.push(err236);
}
errors++;
}
else {
const _errs375 = errors;
for(const key65 in data64){
if(!(key65 === "reader_resource")){
const err237 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key65},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err237];
}
else {
vErrors.push(err237);
}
errors++;
break;
}
}
if(_errs375 === errors){
if(data64.reader_resource !== undefined){
let data166 = data64.reader_resource;
const _errs376 = errors;
if(errors === _errs376){
if(data166 && typeof data166 == "object" && !Array.isArray(data166)){
let missing66;
if((((((((data166.role === undefined) && (missing66 = "role")) || ((data166.resource === undefined) && (missing66 = "resource"))) || ((data166.expected_writer === undefined) && (missing66 = "expected_writer"))) || ((data166.actual_writer === undefined) && (missing66 = "actual_writer"))) || ((data166.phase === undefined) && (missing66 = "phase"))) || ((data166.writer_check === undefined) && (missing66 = "writer_check"))) || ((data166.revision === undefined) && (missing66 = "revision"))){
const err238 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/properties/reader_resource/required",keyword:"required",params:{missingProperty: missing66},message:"must have required property '"+missing66+"'"};
if(vErrors === null){
vErrors = [err238];
}
else {
vErrors.push(err238);
}
errors++;
}
else {
const _errs378 = errors;
for(const key66 in data166){
if(!(((((((key66 === "role") || (key66 === "resource")) || (key66 === "expected_writer")) || (key66 === "actual_writer")) || (key66 === "phase")) || (key66 === "writer_check")) || (key66 === "revision"))){
const err239 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/properties/reader_resource/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key66},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err239];
}
else {
vErrors.push(err239);
}
errors++;
break;
}
}
if(_errs378 === errors){
if(data166.role !== undefined){
let data167 = data166.role;
const _errs379 = errors;
if(typeof data167 !== "string"){
const err240 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource/role",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/properties/reader_resource/properties/role/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err240];
}
else {
vErrors.push(err240);
}
errors++;
}
if(!((data167 === "source") || (data167 === "requester"))){
const err241 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource/role",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/properties/reader_resource/properties/role/enum",keyword:"enum",params:{allowedValues: schema106.oneOf[8].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[23].properties.reader_resource.properties.role.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err241];
}
else {
vErrors.push(err241);
}
errors++;
}
var valid72 = _errs379 === errors;
}
else {
var valid72 = true;
}
if(valid72){
if(data166.resource !== undefined){
const _errs381 = errors;
if(!(validate56(data166.resource, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource/resource",parentData:data166,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid72 = _errs381 === errors;
}
else {
var valid72 = true;
}
if(valid72){
if(data166.expected_writer !== undefined){
const _errs382 = errors;
if(!(validate56(data166.expected_writer, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource/expected_writer",parentData:data166,parentDataProperty:"expected_writer",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid72 = _errs382 === errors;
}
else {
var valid72 = true;
}
if(valid72){
if(data166.actual_writer !== undefined){
const _errs383 = errors;
if(!(validate56(data166.actual_writer, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource/actual_writer",parentData:data166,parentDataProperty:"actual_writer",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid72 = _errs383 === errors;
}
else {
var valid72 = true;
}
if(valid72){
if(data166.phase !== undefined){
let data171 = data166.phase;
const _errs384 = errors;
if(typeof data171 !== "string"){
const err242 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource/phase",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/properties/reader_resource/properties/phase/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err242];
}
else {
vErrors.push(err242);
}
errors++;
}
if(!(((data171 === "active") || (data171 === "retired")) || (data171 === "reclaimed"))){
const err243 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource/phase",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/properties/reader_resource/properties/phase/enum",keyword:"enum",params:{allowedValues: schema106.oneOf[8].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[23].properties.reader_resource.properties.phase.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err243];
}
else {
vErrors.push(err243);
}
errors++;
}
var valid72 = _errs384 === errors;
}
else {
var valid72 = true;
}
if(valid72){
if(data166.writer_check !== undefined){
const _errs386 = errors;
if(typeof data166.writer_check !== "boolean"){
const err244 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource/writer_check",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/properties/reader_resource/properties/writer_check/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err244];
}
else {
vErrors.push(err244);
}
errors++;
}
var valid72 = _errs386 === errors;
}
else {
var valid72 = true;
}
if(valid72){
if(data166.revision !== undefined){
const _errs388 = errors;
if(!(validate56(data166.revision, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource/revision",parentData:data166,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid72 = _errs388 === errors;
}
else {
var valid72 = true;
}
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
const err245 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/properties/reader_resource/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err245];
}
else {
vErrors.push(err245);
}
errors++;
}
}
}
}
}
}
else {
const err246 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err246];
}
else {
vErrors.push(err246);
}
errors++;
}
}
var _valid5 = _errs373 === errors;
if(_valid5 && valid29){
valid29 = false;
passing3 = [passing3, 23];
}
else {
if(_valid5){
valid29 = true;
passing3 = 23;
if(props10 !== true){
props10 = true;
}
}
const _errs389 = errors;
if(errors === _errs389){
if(data64 && typeof data64 == "object" && !Array.isArray(data64)){
let missing67;
if((data64.watch_shape === undefined) && (missing67 = "watch_shape")){
const err247 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/24/required",keyword:"required",params:{missingProperty: missing67},message:"must have required property '"+missing67+"'"};
if(vErrors === null){
vErrors = [err247];
}
else {
vErrors.push(err247);
}
errors++;
}
else {
const _errs391 = errors;
for(const key67 in data64){
if(!(key67 === "watch_shape")){
const err248 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/24/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key67},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err248];
}
else {
vErrors.push(err248);
}
errors++;
break;
}
}
if(_errs391 === errors){
if(data64.watch_shape !== undefined){
let data174 = data64.watch_shape;
const _errs392 = errors;
if(errors === _errs392){
if(data174 && typeof data174 == "object" && !Array.isArray(data174)){
let missing68;
if(((((data174.columns === undefined) && (missing68 = "columns")) || ((data174.first_nullable === undefined) && (missing68 = "first_nullable"))) || ((data174.primary_columns === undefined) && (missing68 = "primary_columns"))) || ((data174.primary_first === undefined) && (missing68 = "primary_first"))){
const err249 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_shape",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/24/properties/watch_shape/required",keyword:"required",params:{missingProperty: missing68},message:"must have required property '"+missing68+"'"};
if(vErrors === null){
vErrors = [err249];
}
else {
vErrors.push(err249);
}
errors++;
}
else {
const _errs394 = errors;
for(const key68 in data174){
if(!((((key68 === "columns") || (key68 === "first_nullable")) || (key68 === "primary_columns")) || (key68 === "primary_first"))){
const err250 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_shape",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/24/properties/watch_shape/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key68},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err250];
}
else {
vErrors.push(err250);
}
errors++;
break;
}
}
if(_errs394 === errors){
if(data174.columns !== undefined){
const _errs395 = errors;
if(!(validate65(data174.columns, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_shape/columns",parentData:data174,parentDataProperty:"columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
errors = vErrors.length;
}
var valid74 = _errs395 === errors;
}
else {
var valid74 = true;
}
if(valid74){
if(data174.first_nullable !== undefined){
const _errs396 = errors;
if(typeof data174.first_nullable !== "boolean"){
const err251 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_shape/first_nullable",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/24/properties/watch_shape/properties/first_nullable/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err251];
}
else {
vErrors.push(err251);
}
errors++;
}
var valid74 = _errs396 === errors;
}
else {
var valid74 = true;
}
if(valid74){
if(data174.primary_columns !== undefined){
const _errs398 = errors;
if(!(validate65(data174.primary_columns, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_shape/primary_columns",parentData:data174,parentDataProperty:"primary_columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
errors = vErrors.length;
}
var valid74 = _errs398 === errors;
}
else {
var valid74 = true;
}
if(valid74){
if(data174.primary_first !== undefined){
const _errs399 = errors;
if(typeof data174.primary_first !== "boolean"){
const err252 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_shape/primary_first",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/24/properties/watch_shape/properties/primary_first/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err252];
}
else {
vErrors.push(err252);
}
errors++;
}
var valid74 = _errs399 === errors;
}
else {
var valid74 = true;
}
}
}
}
}
}
}
else {
const err253 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_shape",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/24/properties/watch_shape/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err253];
}
else {
vErrors.push(err253);
}
errors++;
}
}
}
}
}
}
else {
const err254 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/24/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err254];
}
else {
vErrors.push(err254);
}
errors++;
}
}
var _valid5 = _errs389 === errors;
if(_valid5 && valid29){
valid29 = false;
passing3 = [passing3, 24];
}
else {
if(_valid5){
valid29 = true;
passing3 = 24;
if(props10 !== true){
props10 = true;
}
}
const _errs401 = errors;
if(errors === _errs401){
if(data64 && typeof data64 == "object" && !Array.isArray(data64)){
let missing69;
if((data64.reader_template === undefined) && (missing69 = "reader_template")){
const err255 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/25/required",keyword:"required",params:{missingProperty: missing69},message:"must have required property '"+missing69+"'"};
if(vErrors === null){
vErrors = [err255];
}
else {
vErrors.push(err255);
}
errors++;
}
else {
const _errs403 = errors;
for(const key69 in data64){
if(!(key69 === "reader_template")){
const err256 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/25/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key69},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err256];
}
else {
vErrors.push(err256);
}
errors++;
break;
}
}
if(_errs403 === errors){
if(data64.reader_template !== undefined){
let data179 = data64.reader_template;
const _errs404 = errors;
if(errors === _errs404){
if(data179 && typeof data179 == "object" && !Array.isArray(data179)){
let missing70;
if(((data179.namespace === undefined) && (missing70 = "namespace")) || ((data179.present === undefined) && (missing70 = "present"))){
const err257 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_template",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/25/properties/reader_template/required",keyword:"required",params:{missingProperty: missing70},message:"must have required property '"+missing70+"'"};
if(vErrors === null){
vErrors = [err257];
}
else {
vErrors.push(err257);
}
errors++;
}
else {
const _errs406 = errors;
for(const key70 in data179){
if(!((((key70 === "namespace") || (key70 === "present")) || (key70 === "phase")) || (key70 === "manifest"))){
const err258 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_template",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/25/properties/reader_template/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key70},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err258];
}
else {
vErrors.push(err258);
}
errors++;
break;
}
}
if(_errs406 === errors){
if(data179.namespace !== undefined){
const _errs407 = errors;
if(!(validate56(data179.namespace, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_template/namespace",parentData:data179,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid76 = _errs407 === errors;
}
else {
var valid76 = true;
}
if(valid76){
if(data179.present !== undefined){
const _errs408 = errors;
if(typeof data179.present !== "boolean"){
const err259 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_template/present",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/25/properties/reader_template/properties/present/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err259];
}
else {
vErrors.push(err259);
}
errors++;
}
var valid76 = _errs408 === errors;
}
else {
var valid76 = true;
}
if(valid76){
if(data179.phase !== undefined){
let data182 = data179.phase;
const _errs410 = errors;
if(typeof data182 !== "string"){
const err260 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_template/phase",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/25/properties/reader_template/properties/phase/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err260];
}
else {
vErrors.push(err260);
}
errors++;
}
if(!(((((((((data182 === "uploading") || (data182 === "sealed")) || (data182 === "admitted")) || (data182 === "complete")) || (data182 === "cancelled")) || (data182 === "denied")) || (data182 === "rejected")) || (data182 === "retired")) || (data182 === "prepared"))){
const err261 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_template/phase",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/25/properties/reader_template/properties/phase/enum",keyword:"enum",params:{allowedValues: schema106.oneOf[8].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[25].properties.reader_template.properties.phase.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err261];
}
else {
vErrors.push(err261);
}
errors++;
}
var valid76 = _errs410 === errors;
}
else {
var valid76 = true;
}
if(valid76){
if(data179.manifest !== undefined){
const _errs412 = errors;
if(typeof data179.manifest !== "boolean"){
const err262 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_template/manifest",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/25/properties/reader_template/properties/manifest/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err262];
}
else {
vErrors.push(err262);
}
errors++;
}
var valid76 = _errs412 === errors;
}
else {
var valid76 = true;
}
}
}
}
}
}
}
else {
const err263 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_template",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/25/properties/reader_template/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err263];
}
else {
vErrors.push(err263);
}
errors++;
}
}
}
}
}
}
else {
const err264 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/25/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err264];
}
else {
vErrors.push(err264);
}
errors++;
}
}
var _valid5 = _errs401 === errors;
if(_valid5 && valid29){
valid29 = false;
passing3 = [passing3, 25];
}
else {
if(_valid5){
valid29 = true;
passing3 = 25;
if(props10 !== true){
props10 = true;
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
if(!valid29){
const err265 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf",keyword:"oneOf",params:{passingSchemas: passing3},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err265];
}
else {
vErrors.push(err265);
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
var valid28 = _errs143 === errors;
}
else {
var valid28 = true;
}
}
}
}
}
}
else {
const err266 = {instancePath:instancePath+"/refresh_status/view/failure/stopped",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err267 = {instancePath:instancePath+"/refresh_status/view/failure",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err267];
}
else {
vErrors.push(err267);
}
errors++;
}
}
var _valid4 = _errs134 === errors;
if(_valid4 && valid26){
valid26 = false;
passing2 = [passing2, 1];
}
else {
if(_valid4){
valid26 = true;
passing2 = 1;
if(props9 !== true){
props9 = true;
}
}
}
if(!valid26){
const err268 = {instancePath:instancePath+"/refresh_status/view/failure",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf",keyword:"oneOf",params:{passingSchemas: passing2},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err268];
}
else {
vErrors.push(err268);
}
errors++;
}
else {
errors = _errs132;
if(vErrors !== null){
if(_errs132){
vErrors.length = _errs132;
}
else {
vErrors = null;
}
}
}
var valid25 = _errs131 === errors;
}
else {
var valid25 = true;
}
}
}
}
}
}
}
}
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
const err269 = {instancePath:instancePath+"/refresh_status/view",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err269];
}
else {
vErrors.push(err269);
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
if(data42.diagnostic !== undefined){
const _errs414 = errors;
if(!(validate434(data42.diagnostic, {instancePath:instancePath+"/refresh_status/diagnostic",parentData:data42,parentDataProperty:"diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate434.errors : vErrors.concat(validate434.errors);
errors = vErrors.length;
}
var valid24 = _errs414 === errors;
}
else {
var valid24 = true;
}
if(valid24){
if(data42.query_diagnostic !== undefined){
const _errs415 = errors;
if(!(validate434(data42.query_diagnostic, {instancePath:instancePath+"/refresh_status/query_diagnostic",parentData:data42,parentDataProperty:"query_diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate434.errors : vErrors.concat(validate434.errors);
errors = vErrors.length;
}
var valid24 = _errs415 === errors;
}
else {
var valid24 = true;
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
const err270 = {instancePath:instancePath+"/refresh_status",schemaPath:"#/oneOf/8/properties/refresh_status/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err270];
}
else {
vErrors.push(err270);
}
errors++;
}
}
}
}
}
}
else {
const err271 = {instancePath,schemaPath:"#/oneOf/8/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err271];
}
else {
vErrors.push(err271);
}
errors++;
}
}
var _valid0 = _errs105 === errors;
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
const err272 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err272];
}
else {
vErrors.push(err272);
}
errors++;
validate406.errors = vErrors;
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
validate406.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate406.evaluated = {"dynamicProps":true,"dynamicItems":false};
