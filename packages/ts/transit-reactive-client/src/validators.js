// Generated; no runtime code generation or eval.
import lengthModule from "ajv/dist/runtime/ucs2length.js";
const ucs2length = lengthModule.default ?? lengthModule;
"use strict";
export const Diagnostic = validate52;
const schema19 = {"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"definition":{"$ref":"https://transit.invalid/generated-validator/0"},"code":{"type":"string","maxLength":96},"category":{"$ref":"https://transit.invalid/generated-validator/1"},"stage":{"$ref":"https://transit.invalid/generated-validator/2"},"outcome":{"$ref":"https://transit.invalid/generated-validator/3"},"evidence":{"$ref":"https://transit.invalid/generated-validator/4"},"message":{"type":"string","maxLength":384},"cause":{"$ref":"https://transit.invalid/generated-validator/5"},"identity":{"$ref":"https://transit.invalid/generated-validator/10"},"location":{"anyOf":[{"$ref":"https://transit.invalid/generated-validator/13"},{"type":"null"}]},"facts":{"type":"array","minItems":16,"maxItems":16,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"field":{"$ref":"https://transit.invalid/generated-validator/14"},"origin":{"$ref":"https://transit.invalid/generated-validator/15"},"availability":{"$ref":"https://transit.invalid/generated-validator/16"},"value":{"anyOf":[{"oneOf":[{"$ref":"https://transit.invalid/generated-validator/17"},{"$ref":"https://transit.invalid/generated-validator/19"},{"$ref":"https://transit.invalid/generated-validator/20"},{"$ref":"https://transit.invalid/generated-validator/21"},{"$ref":"https://transit.invalid/generated-validator/24"},{"type":"object","additionalProperties":false,"required":["location"],"properties":{"location":{"$ref":"https://transit.invalid/generated-validator/13"}}}]},{"type":"null"}]}},"required":["field","origin","availability","value"]},{"type":"null"}]}},"actions":{"type":"array","minItems":4,"maxItems":4,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"kind":{"$ref":"https://transit.invalid/generated-validator/25"},"target":{"$ref":"https://transit.invalid/generated-validator/10"}},"required":["kind","target"]},{"type":"null"}]}}},"required":["version","definition","code","category","stage","outcome","evidence","message","cause","identity","location","facts","actions"]};
const func1 = Object.prototype.hasOwnProperty;
const func2 = ucs2length;
const schema20 = {"type":"string","enum":["e8e13924650d3c8a21f2613e192a941b0c5530bcc03aa88a6b4374a9df44f024"]};

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
if(typeof data !== "string"){
validate53.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(data === "e8e13924650d3c8a21f2613e192a941b0c5530bcc03aa88a6b4374a9df44f024")){
validate53.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema20.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate53.errors = vErrors;
return errors === 0;
}
validate53.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema21 = {"type":"string","enum":["syntax","binding","unsupported","constraint","access","conflict","limit","lifecycle","integrity","unavailable","internal"]};

function validate55(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate55.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate55.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((data === "syntax") || (data === "binding")) || (data === "unsupported")) || (data === "constraint")) || (data === "access")) || (data === "conflict")) || (data === "limit")) || (data === "lifecycle")) || (data === "integrity")) || (data === "unavailable")) || (data === "internal"))){
validate55.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema21.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate55.errors = vErrors;
return errors === 0;
}
validate55.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema22 = {"type":"string","enum":["input","parse","compile","bind","prepare","submit","admission","execute","read","decode","output","reconcile","cleanup","control"]};

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
if(typeof data !== "string"){
validate57.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((((data === "input") || (data === "parse")) || (data === "compile")) || (data === "bind")) || (data === "prepare")) || (data === "submit")) || (data === "admission")) || (data === "execute")) || (data === "read")) || (data === "decode")) || (data === "output")) || (data === "reconcile")) || (data === "cleanup")) || (data === "control"))){
validate57.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema22.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate57.errors = vErrors;
return errors === 0;
}
validate57.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema23 = {"type":"string","enum":["not_applicable","not_submitted","not_dispatched","prepared","unknown","pending","input_rejected","rejected","applied","completed","failed","cancelled","retired","closed_unknown"]};

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
if(typeof data !== "string"){
validate59.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((((data === "not_applicable") || (data === "not_submitted")) || (data === "not_dispatched")) || (data === "prepared")) || (data === "unknown")) || (data === "pending")) || (data === "input_rejected")) || (data === "rejected")) || (data === "applied")) || (data === "completed")) || (data === "failed")) || (data === "cancelled")) || (data === "retired")) || (data === "closed_unknown"))){
validate59.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema23.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate59.errors = vErrors;
return errors === 0;
}
validate59.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema24 = {"type":"string","enum":["none","local_before_dispatch","saved_intent","native_receipt","domain_status"]};

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
if(typeof data !== "string"){
validate61.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((data === "none") || (data === "local_before_dispatch")) || (data === "saved_intent")) || (data === "native_receipt")) || (data === "domain_status"))){
validate61.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema24.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate61.errors = vErrors;
return errors === 0;
}
validate61.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema25 = {"anyOf":[{"type":"string","maxLength":96},{"type":"null"}]};

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
validate63.errors = vErrors;
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
validate63.errors = vErrors;
return errors === 0;
}
validate63.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema26 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/9"},{"type":"null"}]};
const schema27 = {"type":"object","additionalProperties":false,"properties":{"domain":{"$ref":"https://transit.invalid/generated-validator/6"},"id":{"$ref":"https://transit.invalid/generated-validator/7"},"realm":{"$ref":"https://transit.invalid/generated-validator/8"},"resource":{"$ref":"https://transit.invalid/generated-validator/8"},"sequence":{"$ref":"https://transit.invalid/generated-validator/8"}},"required":["domain","id","realm","resource","sequence"]};
const schema28 = {"type":"string","enum":["sql","query","mutation","catalog","application","publication","migration","reactive","serving","effect","exchange","transport","internal"]};

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
if(typeof data !== "string"){
validate67.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((((data === "sql") || (data === "query")) || (data === "mutation")) || (data === "catalog")) || (data === "application")) || (data === "publication")) || (data === "migration")) || (data === "reactive")) || (data === "serving")) || (data === "effect")) || (data === "exchange")) || (data === "transport")) || (data === "internal"))){
validate67.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema28.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate67.errors = vErrors;
return errors === 0;
}
validate67.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema29 = {"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"};
const pattern3 = new RegExp("^(0|[1-9][0-9]*)$", "u");

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
if(func2(data) > 20){
validate69.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern3.test(data)){
validate69.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
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

const schema30 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/7"},{"type":"null"}]};

function validate71(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate71.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate69(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate69.errors : vErrors.concat(validate69.errors);
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
validate71.errors = vErrors;
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
validate71.errors = vErrors;
return errors === 0;
}
validate71.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate66(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate66.evaluated;
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
validate66.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "domain") || (key0 === "id")) || (key0 === "realm")) || (key0 === "resource")) || (key0 === "sequence"))){
validate66.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.domain !== undefined){
const _errs2 = errors;
if(!(validate67(data.domain, {instancePath:instancePath+"/domain",parentData:data,parentDataProperty:"domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate67.errors : vErrors.concat(validate67.errors);
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
if(!(validate69(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate69.errors : vErrors.concat(validate69.errors);
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
if(!(validate71(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate71.errors : vErrors.concat(validate71.errors);
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
if(!(validate71(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate71.errors : vErrors.concat(validate71.errors);
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
if(!(validate71(data.sequence, {instancePath:instancePath+"/sequence",parentData:data,parentDataProperty:"sequence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate71.errors : vErrors.concat(validate71.errors);
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
validate66.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate66.errors = vErrors;
return errors === 0;
}
validate66.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate66(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate66.errors : vErrors.concat(validate66.errors);
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
validate65.errors = vErrors;
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
validate65.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate65.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema31 = {"type":"object","additionalProperties":false,"properties":{"source":{"$ref":"https://transit.invalid/generated-validator/11"},"source_encoding":{"$ref":"https://transit.invalid/generated-validator/12"},"source_truncated":{"type":"boolean"},"statement":{"$ref":"https://transit.invalid/generated-validator/8"},"offset":{"$ref":"https://transit.invalid/generated-validator/7"},"length":{"$ref":"https://transit.invalid/generated-validator/7"},"line":{"$ref":"https://transit.invalid/generated-validator/7"},"byte_column":{"$ref":"https://transit.invalid/generated-validator/7"}},"required":["source","source_encoding","source_truncated","statement","offset","length","line","byte_column"]};
const schema32 = {"anyOf":[{"type":"string","maxLength":512},{"type":"null"}]};

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
validate79.errors = vErrors;
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
validate79.errors = vErrors;
return errors === 0;
}
validate79.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema33 = {"type":"string","enum":["utf8","escaped_bytes"]};

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
if(typeof data !== "string"){
validate81.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((data === "utf8") || (data === "escaped_bytes"))){
validate81.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema33.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate81.errors = vErrors;
return errors === 0;
}
validate81.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((((data.source === undefined) && (missing0 = "source")) || ((data.source_encoding === undefined) && (missing0 = "source_encoding"))) || ((data.source_truncated === undefined) && (missing0 = "source_truncated"))) || ((data.statement === undefined) && (missing0 = "statement"))) || ((data.offset === undefined) && (missing0 = "offset"))) || ((data.length === undefined) && (missing0 = "length"))) || ((data.line === undefined) && (missing0 = "line"))) || ((data.byte_column === undefined) && (missing0 = "byte_column"))){
validate78.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "source") || (key0 === "source_encoding")) || (key0 === "source_truncated")) || (key0 === "statement")) || (key0 === "offset")) || (key0 === "length")) || (key0 === "line")) || (key0 === "byte_column"))){
validate78.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.source !== undefined){
const _errs2 = errors;
if(!(validate79(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate79.errors : vErrors.concat(validate79.errors);
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
if(!(validate81(data.source_encoding, {instancePath:instancePath+"/source_encoding",parentData:data,parentDataProperty:"source_encoding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate81.errors : vErrors.concat(validate81.errors);
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
validate78.errors = [{instancePath:instancePath+"/source_truncated",schemaPath:"#/properties/source_truncated/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
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
if(!(validate71(data.statement, {instancePath:instancePath+"/statement",parentData:data,parentDataProperty:"statement",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate71.errors : vErrors.concat(validate71.errors);
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
if(!(validate69(data.offset, {instancePath:instancePath+"/offset",parentData:data,parentDataProperty:"offset",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate69.errors : vErrors.concat(validate69.errors);
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
if(!(validate69(data.length, {instancePath:instancePath+"/length",parentData:data,parentDataProperty:"length",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate69.errors : vErrors.concat(validate69.errors);
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
if(!(validate69(data.line, {instancePath:instancePath+"/line",parentData:data,parentDataProperty:"line",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate69.errors : vErrors.concat(validate69.errors);
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
if(!(validate69(data.byte_column, {instancePath:instancePath+"/byte_column",parentData:data,parentDataProperty:"byte_column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate69.errors : vErrors.concat(validate69.errors);
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
validate78.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate78.errors = vErrors;
return errors === 0;
}
validate78.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema34 = {"type":"string","enum":["object","name","table","native_input","affected_rows","argument","option","permissions","scope","column","qualifier","constraint","key","input_row","first_occurrence","parameter","parameter_use","expected_count","actual_count","expected_type","actual_type","supplied_value","expected_value","expression","source_kind","source_basis","source_key","source_row","field_path","byte_offset","expected_resource","actual_resource","expected_source","actual_source","expected_revision","actual_revision","expected_schema","actual_schema","expected_policy","actual_policy","budget","limit","required","unit","completed_statements","emitted_rows","emitted_segments","completion","proposal","step","generation","attachment","lease","schema_origin","sampling_records","operation","native_cause","expected_bytes","presence","published","subscription","expected_codec","actual_codec","observed_clock","expected_namespace","actual_namespace","attempt","executor","resolution_reason","principal","deadline","authorization_policy","resolution_policy","protocol_status","native_effect","dependency","dependency_kind","dependency_owner"]};

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
if(typeof data !== "string"){
validate89.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((data === "object") || (data === "name")) || (data === "table")) || (data === "native_input")) || (data === "affected_rows")) || (data === "argument")) || (data === "option")) || (data === "permissions")) || (data === "scope")) || (data === "column")) || (data === "qualifier")) || (data === "constraint")) || (data === "key")) || (data === "input_row")) || (data === "first_occurrence")) || (data === "parameter")) || (data === "parameter_use")) || (data === "expected_count")) || (data === "actual_count")) || (data === "expected_type")) || (data === "actual_type")) || (data === "supplied_value")) || (data === "expected_value")) || (data === "expression")) || (data === "source_kind")) || (data === "source_basis")) || (data === "source_key")) || (data === "source_row")) || (data === "field_path")) || (data === "byte_offset")) || (data === "expected_resource")) || (data === "actual_resource")) || (data === "expected_source")) || (data === "actual_source")) || (data === "expected_revision")) || (data === "actual_revision")) || (data === "expected_schema")) || (data === "actual_schema")) || (data === "expected_policy")) || (data === "actual_policy")) || (data === "budget")) || (data === "limit")) || (data === "required")) || (data === "unit")) || (data === "completed_statements")) || (data === "emitted_rows")) || (data === "emitted_segments")) || (data === "completion")) || (data === "proposal")) || (data === "step")) || (data === "generation")) || (data === "attachment")) || (data === "lease")) || (data === "schema_origin")) || (data === "sampling_records")) || (data === "operation")) || (data === "native_cause")) || (data === "expected_bytes")) || (data === "presence")) || (data === "published")) || (data === "subscription")) || (data === "expected_codec")) || (data === "actual_codec")) || (data === "observed_clock")) || (data === "expected_namespace")) || (data === "actual_namespace")) || (data === "attempt")) || (data === "executor")) || (data === "resolution_reason")) || (data === "principal")) || (data === "deadline")) || (data === "authorization_policy")) || (data === "resolution_policy")) || (data === "protocol_status")) || (data === "native_effect")) || (data === "dependency")) || (data === "dependency_kind")) || (data === "dependency_owner"))){
validate89.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema34.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate89.errors = vErrors;
return errors === 0;
}
validate89.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema35 = {"type":"string","enum":["caller","execution","schema","authority","owner"]};

function validate91(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate91.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate91.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((data === "caller") || (data === "execution")) || (data === "schema")) || (data === "authority")) || (data === "owner"))){
validate91.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema35.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate91.errors = vErrors;
return errors === 0;
}
validate91.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema36 = {"type":"string","enum":["provided","truncated","unrecorded","unavailable","withheld","inapplicable"]};

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
if(typeof data !== "string"){
validate93.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((data === "provided") || (data === "truncated")) || (data === "unrecorded")) || (data === "unavailable")) || (data === "withheld")) || (data === "inapplicable"))){
validate93.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema36.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate93.errors = vErrors;
return errors === 0;
}
validate93.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema37 = {"type":"object","additionalProperties":false,"required":["text"],"properties":{"text":{"type":"string","maxLength":256}}};

function validate95(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate95.evaluated;
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
validate95.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "text")){
validate95.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
validate95.errors = [{instancePath:instancePath+"/text",schemaPath:"#/properties/text/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"}];
return false;
}
}
else {
validate95.errors = [{instancePath:instancePath+"/text",schemaPath:"#/properties/text/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
}
}
}
}
else {
validate95.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate95.errors = vErrors;
return errors === 0;
}
validate95.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema38 = {"type":"object","additionalProperties":false,"required":["signed"],"properties":{"signed":{"$ref":"https://transit.invalid/generated-validator/18"}}};
const schema39 = {"type":"string","maxLength":20,"pattern":"^(0|-?[1-9][0-9]*)$"};
const pattern4 = new RegExp("^(0|-?[1-9][0-9]*)$", "u");

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
if(errors === 0){
if(typeof data === "string"){
if(func2(data) > 20){
validate98.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern4.test(data)){
validate98.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(0|-?[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|-?[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate98.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate98.errors = vErrors;
return errors === 0;
}
validate98.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if((data.signed === undefined) && (missing0 = "signed")){
validate97.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "signed")){
validate97.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.signed !== undefined){
if(!(validate98(data.signed, {instancePath:instancePath+"/signed",parentData:data,parentDataProperty:"signed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate98.errors : vErrors.concat(validate98.errors);
errors = vErrors.length;
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

const schema40 = {"type":"object","additionalProperties":false,"required":["unsigned"],"properties":{"unsigned":{"$ref":"https://transit.invalid/generated-validator/7"}}};

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
if((data.unsigned === undefined) && (missing0 = "unsigned")){
validate101.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "unsigned")){
validate101.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.unsigned !== undefined){
if(!(validate69(data.unsigned, {instancePath:instancePath+"/unsigned",parentData:data,parentDataProperty:"unsigned",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate69.errors : vErrors.concat(validate69.errors);
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

const schema41 = {"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"type":"boolean"}}};

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
if((data.boolean === undefined) && (missing0 = "boolean")){
validate104.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "boolean")){
validate104.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.boolean !== undefined){
if(typeof data.boolean !== "boolean"){
validate104.errors = [{instancePath:instancePath+"/boolean",schemaPath:"#/properties/boolean/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
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

const schema42 = {"type":"object","additionalProperties":false,"required":["digest"],"properties":{"digest":{"$ref":"https://transit.invalid/generated-validator/23"}}};
const schema43 = {"type":"array","minItems":32,"maxItems":32,"items":{"$ref":"https://transit.invalid/generated-validator/22"}};
const schema44 = {"type":"integer","minimum":0,"maximum":255};

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
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate108.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate108.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate108.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate108.errors = vErrors;
return errors === 0;
}
validate108.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate107(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate107.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 32){
validate107.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"}];
return false;
}
else {
if(data.length < 32){
validate107.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate108(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate108.errors : vErrors.concat(validate108.errors);
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
validate107.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate107.errors = vErrors;
return errors === 0;
}
validate107.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


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
if((data.digest === undefined) && (missing0 = "digest")){
validate106.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "digest")){
validate106.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.digest !== undefined){
if(!(validate107(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate107.errors : vErrors.concat(validate107.errors);
errors = vErrors.length;
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

const schema45 = {"type":"string","enum":["correct_input","inspect_status","resume_exact","cancel_wait","cancel_mutation","refresh","recompile","retry_read","inspect_scope","reconcile_effect","contact_operator"]};

function validate113(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate113.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate113.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((data === "correct_input") || (data === "inspect_status")) || (data === "resume_exact")) || (data === "cancel_wait")) || (data === "cancel_mutation")) || (data === "refresh")) || (data === "recompile")) || (data === "retry_read")) || (data === "inspect_scope")) || (data === "reconcile_effect")) || (data === "contact_operator"))){
validate113.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema45.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate113.errors = vErrors;
return errors === 0;
}
validate113.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if((((((((((((((data.version === undefined) && (missing0 = "version")) || ((data.definition === undefined) && (missing0 = "definition"))) || ((data.code === undefined) && (missing0 = "code"))) || ((data.category === undefined) && (missing0 = "category"))) || ((data.stage === undefined) && (missing0 = "stage"))) || ((data.outcome === undefined) && (missing0 = "outcome"))) || ((data.evidence === undefined) && (missing0 = "evidence"))) || ((data.message === undefined) && (missing0 = "message"))) || ((data.cause === undefined) && (missing0 = "cause"))) || ((data.identity === undefined) && (missing0 = "identity"))) || ((data.location === undefined) && (missing0 = "location"))) || ((data.facts === undefined) && (missing0 = "facts"))) || ((data.actions === undefined) && (missing0 = "actions"))){
validate52.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema19.properties, key0))){
validate52.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate52.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"}];
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
if(!(validate53(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
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
validate52.errors = [{instancePath:instancePath+"/code",schemaPath:"#/properties/code/maxLength",keyword:"maxLength",params:{limit: 96},message:"must NOT have more than 96 characters"}];
return false;
}
}
else {
validate52.errors = [{instancePath:instancePath+"/code",schemaPath:"#/properties/code/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
if(!(validate55(data.category, {instancePath:instancePath+"/category",parentData:data,parentDataProperty:"category",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate57(data.stage, {instancePath:instancePath+"/stage",parentData:data,parentDataProperty:"stage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
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
if(!(validate59(data.outcome, {instancePath:instancePath+"/outcome",parentData:data,parentDataProperty:"outcome",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate61(data.evidence, {instancePath:instancePath+"/evidence",parentData:data,parentDataProperty:"evidence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate61.errors : vErrors.concat(validate61.errors);
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
validate52.errors = [{instancePath:instancePath+"/message",schemaPath:"#/properties/message/maxLength",keyword:"maxLength",params:{limit: 384},message:"must NOT have more than 384 characters"}];
return false;
}
}
else {
validate52.errors = [{instancePath:instancePath+"/message",schemaPath:"#/properties/message/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
if(!(validate63(data.cause, {instancePath:instancePath+"/cause",parentData:data,parentDataProperty:"cause",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate63.errors : vErrors.concat(validate63.errors);
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
if(!(validate65(data.identity, {instancePath:instancePath+"/identity",parentData:data,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
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
if(!(validate78(data10, {instancePath:instancePath+"/location",parentData:data,parentDataProperty:"location",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate78.errors : vErrors.concat(validate78.errors);
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
validate52.errors = vErrors;
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
validate52.errors = [{instancePath:instancePath+"/facts",schemaPath:"#/properties/facts/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
if(data11.length < 16){
validate52.errors = [{instancePath:instancePath+"/facts",schemaPath:"#/properties/facts/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"}];
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
if(!(validate89(data12.field, {instancePath:instancePath+"/facts/" + i0+"/field",parentData:data12,parentDataProperty:"field",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate89.errors : vErrors.concat(validate89.errors);
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
if(!(validate91(data12.origin, {instancePath:instancePath+"/facts/" + i0+"/origin",parentData:data12,parentDataProperty:"origin",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate91.errors : vErrors.concat(validate91.errors);
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
if(!(validate93(data12.availability, {instancePath:instancePath+"/facts/" + i0+"/availability",parentData:data12,parentDataProperty:"availability",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate93.errors : vErrors.concat(validate93.errors);
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
if(!(validate95(data16, {instancePath:instancePath+"/facts/" + i0+"/value",parentData:data12,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate95.errors : vErrors.concat(validate95.errors);
errors = vErrors.length;
}
var _valid3 = _errs33 === errors;
if(_valid3){
valid6 = true;
passing0 = 0;
var props2 = true;
}
const _errs34 = errors;
if(!(validate97(data16, {instancePath:instancePath+"/facts/" + i0+"/value",parentData:data12,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate97.errors : vErrors.concat(validate97.errors);
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
if(!(validate101(data16, {instancePath:instancePath+"/facts/" + i0+"/value",parentData:data12,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate101.errors : vErrors.concat(validate101.errors);
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
if(!(validate104(data16, {instancePath:instancePath+"/facts/" + i0+"/value",parentData:data12,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate104.errors : vErrors.concat(validate104.errors);
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
if(!(validate106(data16, {instancePath:instancePath+"/facts/" + i0+"/value",parentData:data12,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate106.errors : vErrors.concat(validate106.errors);
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
if(!(validate78(data16.location, {instancePath:instancePath+"/facts/" + i0+"/value/location",parentData:data16,parentDataProperty:"location",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate78.errors : vErrors.concat(validate78.errors);
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
validate52.errors = vErrors;
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
validate52.errors = [{instancePath:instancePath+"/facts",schemaPath:"#/properties/facts/type",keyword:"type",params:{type: "array"},message:"must be array"}];
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
validate52.errors = [{instancePath:instancePath+"/actions",schemaPath:"#/properties/actions/maxItems",keyword:"maxItems",params:{limit: 4},message:"must NOT have more than 4 items"}];
return false;
}
else {
if(data18.length < 4){
validate52.errors = [{instancePath:instancePath+"/actions",schemaPath:"#/properties/actions/minItems",keyword:"minItems",params:{limit: 4},message:"must NOT have fewer than 4 items"}];
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
if(!(validate113(data19.kind, {instancePath:instancePath+"/actions/" + i1+"/kind",parentData:data19,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate113.errors : vErrors.concat(validate113.errors);
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
if(!(validate65(data19.target, {instancePath:instancePath+"/actions/" + i1+"/target",parentData:data19,parentDataProperty:"target",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
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
validate52.errors = vErrors;
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
validate52.errors = [{instancePath:instancePath+"/actions",schemaPath:"#/properties/actions/type",keyword:"type",params:{type: "array"},message:"must be array"}];
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
validate52.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate52.errors = vErrors;
return errors === 0;
}
validate52.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const SignedCommand = validate116;
const schema46 = {"type":"object","additionalProperties":false,"properties":{"request":{"$ref":"https://transit.invalid/generated-validator/30"},"signature":{"$ref":"https://transit.invalid/generated-validator/31"}},"required":["request","signature"]};
const schema47 = {"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"definition":{"$ref":"https://transit.invalid/generated-validator/0"},"realm":{"$ref":"https://transit.invalid/generated-validator/26"},"principal":{"$ref":"https://transit.invalid/generated-validator/26"},"sequence":{"$ref":"https://transit.invalid/generated-validator/26"},"command":{"$ref":"https://transit.invalid/generated-validator/29"}},"required":["definition","realm","principal","sequence","command"]};
const schema48 = {"type":"integer","minimum":0,"maximum":9007199254740991};

function validate119(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate119.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate119.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 9007199254740991 || isNaN(data)){
validate119.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate119.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate119.errors = vErrors;
return errors === 0;
}
validate119.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema49 = {"type":"object","additionalProperties":false,"properties":{"send":{"$ref":"https://transit.invalid/generated-validator/28"}},"required":["send"]};
const schema50 = {"type":"object","additionalProperties":false,"properties":{"pid":{"$ref":"https://transit.invalid/generated-validator/26"},"value":{"$ref":"https://transit.invalid/generated-validator/27"}},"required":["pid","value"]};
const schema51 = {"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512};
const pattern5 = new RegExp("^(?:[0-9a-f]{2})*$", "u");

function validate126(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate126.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func2(data) > 512){
validate126.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"}];
return false;
}
else {
if(!pattern5.test(data)){
validate126.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""}];
return false;
}
}
}
else {
validate126.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate126.errors = vErrors;
return errors === 0;
}
validate126.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(((data.pid === undefined) && (missing0 = "pid")) || ((data.value === undefined) && (missing0 = "value"))){
validate124.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "pid") || (key0 === "value"))){
validate124.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.pid !== undefined){
const _errs2 = errors;
if(!(validate119(data.pid, {instancePath:instancePath+"/pid",parentData:data,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate126(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate126.errors : vErrors.concat(validate126.errors);
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
validate124.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate124.errors = vErrors;
return errors === 0;
}
validate124.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if((data.send === undefined) && (missing0 = "send")){
validate123.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "send")){
validate123.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.send !== undefined){
if(!(validate124(data.send, {instancePath:instancePath+"/send",parentData:data,parentDataProperty:"send",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate124.errors : vErrors.concat(validate124.errors);
errors = vErrors.length;
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
if((((((data.definition === undefined) && (missing0 = "definition")) || ((data.realm === undefined) && (missing0 = "realm"))) || ((data.principal === undefined) && (missing0 = "principal"))) || ((data.sequence === undefined) && (missing0 = "sequence"))) || ((data.command === undefined) && (missing0 = "command"))){
validate117.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "version") || (key0 === "definition")) || (key0 === "realm")) || (key0 === "principal")) || (key0 === "sequence")) || (key0 === "command"))){
validate117.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate117.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"}];
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
if(!(validate53(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
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
if(!(validate119(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.sequence, {instancePath:instancePath+"/sequence",parentData:data,parentDataProperty:"sequence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate123(data.command, {instancePath:instancePath+"/command",parentData:data,parentDataProperty:"command",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate123.errors : vErrors.concat(validate123.errors);
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
validate117.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate117.errors = vErrors;
return errors === 0;
}
validate117.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema52 = {"type":"array","minItems":64,"maxItems":64,"items":{"$ref":"https://transit.invalid/generated-validator/22"}};

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
if(data.length > 64){
validate131.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 64},message:"must NOT have more than 64 items"}];
return false;
}
else {
if(data.length < 64){
validate131.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 64},message:"must NOT have fewer than 64 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate108(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate108.errors : vErrors.concat(validate108.errors);
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
validate131.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate131.errors = vErrors;
return errors === 0;
}
validate131.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


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
if(((data.request === undefined) && (missing0 = "request")) || ((data.signature === undefined) && (missing0 = "signature"))){
validate116.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "request") || (key0 === "signature"))){
validate116.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.request !== undefined){
const _errs2 = errors;
if(!(validate117(data.request, {instancePath:instancePath+"/request",parentData:data,parentDataProperty:"request",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate117.errors : vErrors.concat(validate117.errors);
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
if(!(validate131(data.signature, {instancePath:instancePath+"/signature",parentData:data,parentDataProperty:"signature",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate131.errors : vErrors.concat(validate131.errors);
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
validate116.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate116.errors = vErrors;
return errors === 0;
}
validate116.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const ServingRead = validate134;
const schema53 = {"type":"object","additionalProperties":false,"properties":{"read":{"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"https://transit.invalid/generated-validator/26"},"principal":{"$ref":"https://transit.invalid/generated-validator/26"},"service":{"$ref":"https://transit.invalid/generated-validator/26"},"ingress":{"$ref":"https://transit.invalid/generated-validator/26"},"kind":{"type":"string","enum":["discovery","status","result","disposition"]},"operation":{"$ref":"https://transit.invalid/generated-validator/26"}},"required":["realm","principal","service","ingress","kind"]},"signature":{"$ref":"https://transit.invalid/generated-validator/31"},"identity":{"$ref":"https://transit.invalid/generated-validator/35"}},"required":["read","signature","identity"]};
const schema54 = {"type":"object","additionalProperties":false,"properties":{"query":{"$ref":"https://transit.invalid/generated-validator/34"},"signature":{"$ref":"https://transit.invalid/generated-validator/31"}},"required":["query","signature"]};
const schema55 = {"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"definition":{"$ref":"https://transit.invalid/generated-validator/0"},"realm":{"$ref":"https://transit.invalid/generated-validator/26"},"principal":{"$ref":"https://transit.invalid/generated-validator/26"},"kind":{"$ref":"https://transit.invalid/generated-validator/33"}},"required":["realm","principal","kind"]};
const schema56 = {"oneOf":[{"$ref":"https://transit.invalid/generated-validator/32"}]};
const schema57 = {"type":"object","additionalProperties":false,"required":["identity"],"properties":{"identity":{"type":"object","maxProperties":0}}};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.identity === undefined) && (missing0 = "identity")){
validate147.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "identity")){
validate147.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
validate147.errors = [{instancePath:instancePath+"/identity",schemaPath:"#/properties/identity/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"}];
return false;
}
}
else {
validate147.errors = [{instancePath:instancePath+"/identity",schemaPath:"#/properties/identity/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
}
}
}
}
else {
validate147.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate147.errors = vErrors;
return errors === 0;
}
validate147.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
let passing0 = null;
const _errs1 = errors;
if(!(validate147(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate147.errors : vErrors.concat(validate147.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
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
validate146.errors = vErrors;
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
validate146.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate146.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate142(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate142.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.realm === undefined) && (missing0 = "realm")) || ((data.principal === undefined) && (missing0 = "principal"))) || ((data.kind === undefined) && (missing0 = "kind"))){
validate142.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "version") || (key0 === "definition")) || (key0 === "realm")) || (key0 === "principal")) || (key0 === "kind"))){
validate142.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate142.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"}];
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
if(!(validate53(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
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
if(!(validate119(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.kind !== undefined){
const _errs6 = errors;
if(!(validate146(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
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
validate142.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate142.errors = vErrors;
return errors === 0;
}
validate142.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.query === undefined) && (missing0 = "query")) || ((data.signature === undefined) && (missing0 = "signature"))){
validate141.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "query") || (key0 === "signature"))){
validate141.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.query !== undefined){
const _errs2 = errors;
if(!(validate142(data.query, {instancePath:instancePath+"/query",parentData:data,parentDataProperty:"query",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate142.errors : vErrors.concat(validate142.errors);
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
if(!(validate131(data.signature, {instancePath:instancePath+"/signature",parentData:data,parentDataProperty:"signature",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate131.errors : vErrors.concat(validate131.errors);
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
validate141.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate141.errors = vErrors;
return errors === 0;
}
validate141.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if((((data.read === undefined) && (missing0 = "read")) || ((data.signature === undefined) && (missing0 = "signature"))) || ((data.identity === undefined) && (missing0 = "identity"))){
validate134.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "read") || (key0 === "signature")) || (key0 === "identity"))){
validate134.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
validate134.errors = [{instancePath:instancePath+"/read",schemaPath:"#/properties/read/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"}];
return false;
}
else {
const _errs4 = errors;
for(const key1 in data0){
if(!((((((key1 === "realm") || (key1 === "principal")) || (key1 === "service")) || (key1 === "ingress")) || (key1 === "kind")) || (key1 === "operation"))){
validate134.errors = [{instancePath:instancePath+"/read",schemaPath:"#/properties/read/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs4 === errors){
if(data0.realm !== undefined){
const _errs5 = errors;
if(!(validate119(data0.realm, {instancePath:instancePath+"/read/realm",parentData:data0,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data0.principal, {instancePath:instancePath+"/read/principal",parentData:data0,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data0.service, {instancePath:instancePath+"/read/service",parentData:data0,parentDataProperty:"service",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data0.ingress, {instancePath:instancePath+"/read/ingress",parentData:data0,parentDataProperty:"ingress",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
validate134.errors = [{instancePath:instancePath+"/read/kind",schemaPath:"#/properties/read/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((data5 === "discovery") || (data5 === "status")) || (data5 === "result")) || (data5 === "disposition"))){
validate134.errors = [{instancePath:instancePath+"/read/kind",schemaPath:"#/properties/read/properties/kind/enum",keyword:"enum",params:{allowedValues: schema53.properties.read.properties.kind.enum},message:"must be equal to one of the allowed values"}];
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
if(!(validate119(data0.operation, {instancePath:instancePath+"/read/operation",parentData:data0,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
validate134.errors = [{instancePath:instancePath+"/read",schemaPath:"#/properties/read/type",keyword:"type",params:{type: "object"},message:"must be object"}];
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
const _errs12 = errors;
if(!(validate131(data.signature, {instancePath:instancePath+"/signature",parentData:data,parentDataProperty:"signature",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate131.errors : vErrors.concat(validate131.errors);
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
if(!(validate141(data.identity, {instancePath:instancePath+"/identity",parentData:data,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate141.errors : vErrors.concat(validate141.errors);
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
else {
validate134.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate134.errors = vErrors;
return errors === 0;
}
validate134.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const ServingResponse = validate153;
const schema58 = {"type":"object","additionalProperties":false,"properties":{"service":{"$ref":"https://transit.invalid/generated-validator/26"},"resource":{"$ref":"https://transit.invalid/generated-validator/26"},"revision":{"$ref":"https://transit.invalid/generated-validator/26"},"policy_revision":{"$ref":"https://transit.invalid/generated-validator/26"},"stage":{"$ref":"https://transit.invalid/generated-validator/36"},"binding":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"revision":{"$ref":"https://transit.invalid/generated-validator/26"},"target":{"$ref":"https://transit.invalid/generated-validator/26"},"codec":{"$ref":"https://transit.invalid/generated-validator/37"},"active_limit":{"$ref":"https://transit.invalid/generated-validator/22"},"wait_before_ms":{"$ref":"https://transit.invalid/generated-validator/26"},"published":{"type":"boolean"}},"required":["revision","target","codec","active_limit","wait_before_ms"]},{"type":"null"}]},"operation":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"principal":{"$ref":"https://transit.invalid/generated-validator/26"},"operation":{"$ref":"https://transit.invalid/generated-validator/26"},"binding":{"$ref":"https://transit.invalid/generated-validator/26"},"codec":{"$ref":"https://transit.invalid/generated-validator/37"},"deadline_ms":{"$ref":"https://transit.invalid/generated-validator/26"},"digest":{"$ref":"https://transit.invalid/generated-validator/23"},"target":{"$ref":"https://transit.invalid/generated-validator/26"},"correlation":{"$ref":"https://transit.invalid/generated-validator/26"},"policy_revision":{"$ref":"https://transit.invalid/generated-validator/26"},"phase":{"$ref":"https://transit.invalid/generated-validator/38"},"resolution_input":{"$ref":"https://transit.invalid/generated-validator/26"},"result":{"$ref":"https://transit.invalid/generated-validator/27"},"reply_bytes":{"$ref":"https://transit.invalid/generated-validator/37"}},"required":["principal","operation","binding","codec","deadline_ms","digest","target","correlation","policy_revision"]},{"type":"null"}]},"diagnostic":{"anyOf":[{"$ref":"Diagnostic"},{"type":"null"}]},"disposition":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"record":{"$ref":"https://transit.invalid/generated-validator/41"},"diagnostic":{"anyOf":[{"$ref":"Diagnostic"},{"type":"null"}]}},"required":["record","diagnostic"]},{"type":"null"}]},"capabilities":{"type":"object","additionalProperties":false,"properties":{"http":{"type":"boolean"},"sse":{"type":"boolean"},"websocket":{"type":"boolean"},"grpc":{"type":"boolean"},"flight":{"type":"boolean"}},"required":[]}},"required":["service","resource","revision","policy_revision"]};
const schema59 = {"type":"string","enum":["ingress_accepted","not_observed","service_admitted","completed","cancelled","timed_out","failed","rejected"]};

function validate158(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate158.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate158.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((data === "ingress_accepted") || (data === "not_observed")) || (data === "service_admitted")) || (data === "completed")) || (data === "cancelled")) || (data === "timed_out")) || (data === "failed")) || (data === "rejected"))){
validate158.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema59.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate158.errors = vErrors;
return errors === 0;
}
validate158.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema60 = {"type":"integer","minimum":0,"maximum":65535};

function validate162(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate162.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate162.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 65535 || isNaN(data)){
validate162.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate162.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate162.errors = vErrors;
return errors === 0;
}
validate162.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema61 = {"type":"string","enum":["admitted","completed","cancelled","timed_out","failed"]};

function validate175(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate175.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate175.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((data === "admitted") || (data === "completed")) || (data === "cancelled")) || (data === "timed_out")) || (data === "failed"))){
validate175.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema61.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate175.errors = vErrors;
return errors === 0;
}
validate175.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema62 = {"type":"object","additionalProperties":false,"properties":{"reason":{"$ref":"https://transit.invalid/generated-validator/39"},"input":{"$ref":"https://transit.invalid/generated-validator/26"},"kind":{"$ref":"https://transit.invalid/generated-validator/40"},"subject":{"$ref":"https://transit.invalid/generated-validator/7"},"generation":{"$ref":"https://transit.invalid/generated-validator/7"},"payload":{"$ref":"https://transit.invalid/generated-validator/23"},"cause":{"$ref":"https://transit.invalid/generated-validator/27"}},"required":["reason","input","kind","subject","generation","payload","cause"]};
const schema63 = {"type":"string","enum":["InvalidServingFrame","ServingExternalOriginRequired","UnexpectedServingOrigin","InvalidServingCommand","InvalidServingIdentity","InvalidServiceBinding","InvalidServicePolicy","ServingDenied","ServiceRevisionConflict","ServingIdentityConflict","ServingCapacity","ServiceUnpublished","InvalidWaitLifetime","ServingOperationNotFound","UnknownServingCorrelation","UnexpectedServingReplySource","UnexpectedTimerObserver","InvalidTimerObservation","PrematureTimer","UnsupportedServingFrame","InvalidReactiveSource","ReactiveSessionNotFound","ReactiveGenerationConflict","ReactiveSessionClosed","ReactiveSessionExpired","ReactiveResetRequired","InvalidReactiveLease","ReactiveCapacity","InvalidReactiveAttachment","ReactiveAttachmentConflict","ReactiveSubscriptionConflict","ReactiveLeaseConflict","InvalidRefreshBudget","InvalidRefreshTemplate","RefreshGenerationConflict","RefreshNotFound","RefreshResultConflict","UnexpectedRefreshWake","AccessDenied","QueryDenied","CatalogDenied","ResourceUnavailable","QuerySourceUnavailable","ResultUnavailable","PublicationNotPublished","UnsupportedReactiveSource","InvalidReactiveProgress","TableNotFound"]};

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
if(typeof data !== "string"){
validate182.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((((((((((((((((((((((((((((((((((((((data === "InvalidServingFrame") || (data === "ServingExternalOriginRequired")) || (data === "UnexpectedServingOrigin")) || (data === "InvalidServingCommand")) || (data === "InvalidServingIdentity")) || (data === "InvalidServiceBinding")) || (data === "InvalidServicePolicy")) || (data === "ServingDenied")) || (data === "ServiceRevisionConflict")) || (data === "ServingIdentityConflict")) || (data === "ServingCapacity")) || (data === "ServiceUnpublished")) || (data === "InvalidWaitLifetime")) || (data === "ServingOperationNotFound")) || (data === "UnknownServingCorrelation")) || (data === "UnexpectedServingReplySource")) || (data === "UnexpectedTimerObserver")) || (data === "InvalidTimerObservation")) || (data === "PrematureTimer")) || (data === "UnsupportedServingFrame")) || (data === "InvalidReactiveSource")) || (data === "ReactiveSessionNotFound")) || (data === "ReactiveGenerationConflict")) || (data === "ReactiveSessionClosed")) || (data === "ReactiveSessionExpired")) || (data === "ReactiveResetRequired")) || (data === "InvalidReactiveLease")) || (data === "ReactiveCapacity")) || (data === "InvalidReactiveAttachment")) || (data === "ReactiveAttachmentConflict")) || (data === "ReactiveSubscriptionConflict")) || (data === "ReactiveLeaseConflict")) || (data === "InvalidRefreshBudget")) || (data === "InvalidRefreshTemplate")) || (data === "RefreshGenerationConflict")) || (data === "RefreshNotFound")) || (data === "RefreshResultConflict")) || (data === "UnexpectedRefreshWake")) || (data === "AccessDenied")) || (data === "QueryDenied")) || (data === "CatalogDenied")) || (data === "ResourceUnavailable")) || (data === "QuerySourceUnavailable")) || (data === "ResultUnavailable")) || (data === "PublicationNotPublished")) || (data === "UnsupportedReactiveSource")) || (data === "InvalidReactiveProgress")) || (data === "TableNotFound"))){
validate182.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema63.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate182.errors = vErrors;
return errors === 0;
}
validate182.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema64 = {"type":"string","enum":["service","reactive","refresh"]};

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
if(!(((data === "service") || (data === "reactive")) || (data === "refresh"))){
validate185.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema64.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate185.errors = vErrors;
return errors === 0;
}
validate185.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if((((((((data.reason === undefined) && (missing0 = "reason")) || ((data.input === undefined) && (missing0 = "input"))) || ((data.kind === undefined) && (missing0 = "kind"))) || ((data.subject === undefined) && (missing0 = "subject"))) || ((data.generation === undefined) && (missing0 = "generation"))) || ((data.payload === undefined) && (missing0 = "payload"))) || ((data.cause === undefined) && (missing0 = "cause"))){
validate181.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "reason") || (key0 === "input")) || (key0 === "kind")) || (key0 === "subject")) || (key0 === "generation")) || (key0 === "payload")) || (key0 === "cause"))){
validate181.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.reason !== undefined){
const _errs2 = errors;
if(!(validate182(data.reason, {instancePath:instancePath+"/reason",parentData:data,parentDataProperty:"reason",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate182.errors : vErrors.concat(validate182.errors);
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
if(!(validate119(data.input, {instancePath:instancePath+"/input",parentData:data,parentDataProperty:"input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate185(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate185.errors : vErrors.concat(validate185.errors);
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
if(!(validate69(data.subject, {instancePath:instancePath+"/subject",parentData:data,parentDataProperty:"subject",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate69.errors : vErrors.concat(validate69.errors);
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
if(!(validate69(data.generation, {instancePath:instancePath+"/generation",parentData:data,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate69.errors : vErrors.concat(validate69.errors);
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
if(!(validate107(data.payload, {instancePath:instancePath+"/payload",parentData:data,parentDataProperty:"payload",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate107.errors : vErrors.concat(validate107.errors);
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
if(!(validate126(data.cause, {instancePath:instancePath+"/cause",parentData:data,parentDataProperty:"cause",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate126.errors : vErrors.concat(validate126.errors);
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
validate181.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate181.errors = vErrors;
return errors === 0;
}
validate181.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.service === undefined) && (missing0 = "service")) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.revision === undefined) && (missing0 = "revision"))) || ((data.policy_revision === undefined) && (missing0 = "policy_revision"))){
validate153.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema58.properties, key0))){
validate153.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.service !== undefined){
const _errs2 = errors;
if(!(validate119(data.service, {instancePath:instancePath+"/service",parentData:data,parentDataProperty:"service",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.policy_revision, {instancePath:instancePath+"/policy_revision",parentData:data,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate158(data.stage, {instancePath:instancePath+"/stage",parentData:data,parentDataProperty:"stage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate158.errors : vErrors.concat(validate158.errors);
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
if(!(validate119(data5.revision, {instancePath:instancePath+"/binding/revision",parentData:data5,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data5.target, {instancePath:instancePath+"/binding/target",parentData:data5,parentDataProperty:"target",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate162(data5.codec, {instancePath:instancePath+"/binding/codec",parentData:data5,parentDataProperty:"codec",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate162.errors : vErrors.concat(validate162.errors);
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
if(!(validate108(data5.active_limit, {instancePath:instancePath+"/binding/active_limit",parentData:data5,parentDataProperty:"active_limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate108.errors : vErrors.concat(validate108.errors);
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
if(!(validate119(data5.wait_before_ms, {instancePath:instancePath+"/binding/wait_before_ms",parentData:data5,parentDataProperty:"wait_before_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
validate153.errors = vErrors;
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
if(!(func1.call(schema58.properties.operation.anyOf[0].properties, key2))){
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
if(!(validate119(data12.principal, {instancePath:instancePath+"/operation/principal",parentData:data12,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data12.operation, {instancePath:instancePath+"/operation/operation",parentData:data12,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data12.binding, {instancePath:instancePath+"/operation/binding",parentData:data12,parentDataProperty:"binding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate162(data12.codec, {instancePath:instancePath+"/operation/codec",parentData:data12,parentDataProperty:"codec",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate162.errors : vErrors.concat(validate162.errors);
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
if(!(validate119(data12.deadline_ms, {instancePath:instancePath+"/operation/deadline_ms",parentData:data12,parentDataProperty:"deadline_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate107(data12.digest, {instancePath:instancePath+"/operation/digest",parentData:data12,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate107.errors : vErrors.concat(validate107.errors);
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
if(!(validate119(data12.target, {instancePath:instancePath+"/operation/target",parentData:data12,parentDataProperty:"target",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data12.correlation, {instancePath:instancePath+"/operation/correlation",parentData:data12,parentDataProperty:"correlation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data12.policy_revision, {instancePath:instancePath+"/operation/policy_revision",parentData:data12,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate175(data12.phase, {instancePath:instancePath+"/operation/phase",parentData:data12,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate175.errors : vErrors.concat(validate175.errors);
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
if(!(validate119(data12.resolution_input, {instancePath:instancePath+"/operation/resolution_input",parentData:data12,parentDataProperty:"resolution_input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate126(data12.result, {instancePath:instancePath+"/operation/result",parentData:data12,parentDataProperty:"result",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate126.errors : vErrors.concat(validate126.errors);
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
if(!(validate162(data12.reply_bytes, {instancePath:instancePath+"/operation/reply_bytes",parentData:data12,parentDataProperty:"reply_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate162.errors : vErrors.concat(validate162.errors);
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
validate153.errors = vErrors;
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
if(!(validate52(data26, {instancePath:instancePath+"/diagnostic",parentData:data,parentDataProperty:"diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate52.errors : vErrors.concat(validate52.errors);
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
validate153.errors = vErrors;
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
if(!(validate181(data27.record, {instancePath:instancePath+"/disposition/record",parentData:data27,parentDataProperty:"record",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate181.errors : vErrors.concat(validate181.errors);
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
if(!(validate52(data29, {instancePath:instancePath+"/disposition/diagnostic",parentData:data27,parentDataProperty:"diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate52.errors : vErrors.concat(validate52.errors);
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
validate153.errors = vErrors;
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
validate153.errors = [{instancePath:instancePath+"/capabilities",schemaPath:"#/properties/capabilities/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs61 === errors){
if(data30.http !== undefined){
const _errs62 = errors;
if(typeof data30.http !== "boolean"){
validate153.errors = [{instancePath:instancePath+"/capabilities/http",schemaPath:"#/properties/capabilities/properties/http/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
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
validate153.errors = [{instancePath:instancePath+"/capabilities/sse",schemaPath:"#/properties/capabilities/properties/sse/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
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
validate153.errors = [{instancePath:instancePath+"/capabilities/websocket",schemaPath:"#/properties/capabilities/properties/websocket/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
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
validate153.errors = [{instancePath:instancePath+"/capabilities/grpc",schemaPath:"#/properties/capabilities/properties/grpc/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
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
validate153.errors = [{instancePath:instancePath+"/capabilities/flight",schemaPath:"#/properties/capabilities/properties/flight/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
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
validate153.errors = [{instancePath:instancePath+"/capabilities",schemaPath:"#/properties/capabilities/type",keyword:"type",params:{type: "object"},message:"must be object"}];
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
validate153.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate153.errors = vErrors;
return errors === 0;
}
validate153.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Receipt = validate193;
const schema65 = {"type":"object","additionalProperties":false,"properties":{"stage":{"$ref":"https://transit.invalid/generated-validator/36"},"receipt":{"$ref":"https://transit.invalid/generated-validator/42"}},"required":["receipt"]};
const schema66 = {"type":"object","additionalProperties":false,"properties":{"position":{"$ref":"https://transit.invalid/generated-validator/26"}},"required":["position"]};

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
if((data.position === undefined) && (missing0 = "position")){
validate195.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "position")){
validate195.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.position !== undefined){
if(!(validate119(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
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
if((data.receipt === undefined) && (missing0 = "receipt")){
validate193.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "stage") || (key0 === "receipt"))){
validate193.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.stage !== undefined){
const _errs2 = errors;
if(!(validate158(data.stage, {instancePath:instancePath+"/stage",parentData:data,parentDataProperty:"stage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate158.errors : vErrors.concat(validate158.errors);
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
if(!(validate195(data.receipt, {instancePath:instancePath+"/receipt",parentData:data,parentDataProperty:"receipt",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate195.errors : vErrors.concat(validate195.errors);
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
validate193.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate193.errors = vErrors;
return errors === 0;
}
validate193.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const ReactiveRead = validate198;
const schema67 = {"type":"object","additionalProperties":false,"properties":{"read":{"$ref":"https://transit.invalid/generated-validator/49"},"signature":{"$ref":"https://transit.invalid/generated-validator/31"},"identity":{"$ref":"https://transit.invalid/generated-validator/35"}},"required":["read","signature","identity"]};
const schema68 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"https://transit.invalid/generated-validator/43"},"kind":{"$ref":"https://transit.invalid/generated-validator/44"},"attachment":{"$ref":"https://transit.invalid/generated-validator/26"},"nonce":{"$ref":"https://transit.invalid/generated-validator/45"},"cursor":{"$ref":"https://transit.invalid/generated-validator/48"}},"required":["scope","kind"]};
const schema69 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"https://transit.invalid/generated-validator/26"},"principal":{"$ref":"https://transit.invalid/generated-validator/26"},"service":{"$ref":"https://transit.invalid/generated-validator/26"},"ingress":{"$ref":"https://transit.invalid/generated-validator/26"},"session":{"$ref":"https://transit.invalid/generated-validator/26"},"generation":{"$ref":"https://transit.invalid/generated-validator/26"},"subscription":{"$ref":"https://transit.invalid/generated-validator/26"},"subscription_generation":{"$ref":"https://transit.invalid/generated-validator/26"}},"required":["realm","principal","service","ingress","session","generation"]};

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
if(((((((data.realm === undefined) && (missing0 = "realm")) || ((data.principal === undefined) && (missing0 = "principal"))) || ((data.service === undefined) && (missing0 = "service"))) || ((data.ingress === undefined) && (missing0 = "ingress"))) || ((data.session === undefined) && (missing0 = "session"))) || ((data.generation === undefined) && (missing0 = "generation"))){
validate200.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "realm") || (key0 === "principal")) || (key0 === "service")) || (key0 === "ingress")) || (key0 === "session")) || (key0 === "generation")) || (key0 === "subscription")) || (key0 === "subscription_generation"))){
validate200.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate119(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.service, {instancePath:instancePath+"/service",parentData:data,parentDataProperty:"service",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.ingress, {instancePath:instancePath+"/ingress",parentData:data,parentDataProperty:"ingress",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.session, {instancePath:instancePath+"/session",parentData:data,parentDataProperty:"session",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.generation, {instancePath:instancePath+"/generation",parentData:data,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.subscription, {instancePath:instancePath+"/subscription",parentData:data,parentDataProperty:"subscription",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.subscription_generation, {instancePath:instancePath+"/subscription_generation",parentData:data,parentDataProperty:"subscription_generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
validate200.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate200.errors = vErrors;
return errors === 0;
}
validate200.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema70 = {"type":"string","enum":["session","snapshot","events"]};

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
if(typeof data !== "string"){
validate210.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((data === "session") || (data === "snapshot")) || (data === "events"))){
validate210.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema70.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate210.errors = vErrors;
return errors === 0;
}
validate210.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema71 = {"type":"array","minItems":16,"maxItems":16,"items":{"$ref":"https://transit.invalid/generated-validator/22"}};

function validate213(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate213.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 16){
validate213.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
if(data.length < 16){
validate213.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate108(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate108.errors : vErrors.concat(validate108.errors);
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
validate213.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate213.errors = vErrors;
return errors === 0;
}
validate213.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema72 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/47"},{"type":"null"}]};
const schema73 = {"type":"object","additionalProperties":false,"properties":{"position":{"$ref":"https://transit.invalid/generated-validator/46"},"signature":{"$ref":"https://transit.invalid/generated-validator/31"}},"required":["position","signature"]};
const schema74 = {"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"scope":{"$ref":"https://transit.invalid/generated-validator/43"},"watch_revision":{"$ref":"https://transit.invalid/generated-validator/26"},"resource":{"$ref":"https://transit.invalid/generated-validator/26"},"schema":{"$ref":"https://transit.invalid/generated-validator/23"},"data_revision":{"$ref":"https://transit.invalid/generated-validator/26"},"outcome_position":{"$ref":"https://transit.invalid/generated-validator/26"}},"required":["scope","watch_revision","resource","schema","data_revision"]};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.scope === undefined) && (missing0 = "scope")) || ((data.watch_revision === undefined) && (missing0 = "watch_revision"))) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.schema === undefined) && (missing0 = "schema"))) || ((data.data_revision === undefined) && (missing0 = "data_revision"))){
validate218.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "version") || (key0 === "scope")) || (key0 === "watch_revision")) || (key0 === "resource")) || (key0 === "schema")) || (key0 === "data_revision")) || (key0 === "outcome_position"))){
validate218.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate218.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"}];
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
if(!(validate200(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate200.errors : vErrors.concat(validate200.errors);
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
if(!(validate119(data.watch_revision, {instancePath:instancePath+"/watch_revision",parentData:data,parentDataProperty:"watch_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate107(data.schema, {instancePath:instancePath+"/schema",parentData:data,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate107.errors : vErrors.concat(validate107.errors);
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
if(!(validate119(data.data_revision, {instancePath:instancePath+"/data_revision",parentData:data,parentDataProperty:"data_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.outcome_position, {instancePath:instancePath+"/outcome_position",parentData:data,parentDataProperty:"outcome_position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
validate218.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate218.errors = vErrors;
return errors === 0;
}
validate218.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate217(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate217.evaluated;
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
validate217.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "position") || (key0 === "signature"))){
validate217.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.position !== undefined){
const _errs2 = errors;
if(!(validate218(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate218.errors : vErrors.concat(validate218.errors);
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
if(!(validate131(data.signature, {instancePath:instancePath+"/signature",parentData:data,parentDataProperty:"signature",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate131.errors : vErrors.concat(validate131.errors);
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
validate217.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate217.errors = vErrors;
return errors === 0;
}
validate217.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate217(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate217.errors : vErrors.concat(validate217.errors);
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
validate216.errors = vErrors;
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
validate216.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate216.evaluated = {"dynamicProps":true,"dynamicItems":false};


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
if(((data.scope === undefined) && (missing0 = "scope")) || ((data.kind === undefined) && (missing0 = "kind"))){
validate199.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "scope") || (key0 === "kind")) || (key0 === "attachment")) || (key0 === "nonce")) || (key0 === "cursor"))){
validate199.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate200(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate200.errors : vErrors.concat(validate200.errors);
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
if(!(validate210(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate210.errors : vErrors.concat(validate210.errors);
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
if(!(validate119(data.attachment, {instancePath:instancePath+"/attachment",parentData:data,parentDataProperty:"attachment",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate213(data.nonce, {instancePath:instancePath+"/nonce",parentData:data,parentDataProperty:"nonce",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate213.errors : vErrors.concat(validate213.errors);
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
if(!(validate216(data.cursor, {instancePath:instancePath+"/cursor",parentData:data,parentDataProperty:"cursor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate216.errors : vErrors.concat(validate216.errors);
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
if((((data.read === undefined) && (missing0 = "read")) || ((data.signature === undefined) && (missing0 = "signature"))) || ((data.identity === undefined) && (missing0 = "identity"))){
validate198.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "read") || (key0 === "signature")) || (key0 === "identity"))){
validate198.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.read !== undefined){
const _errs2 = errors;
if(!(validate199(data.read, {instancePath:instancePath+"/read",parentData:data,parentDataProperty:"read",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate199.errors : vErrors.concat(validate199.errors);
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
if(!(validate131(data.signature, {instancePath:instancePath+"/signature",parentData:data,parentDataProperty:"signature",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate131.errors : vErrors.concat(validate131.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.identity !== undefined){
const _errs4 = errors;
if(!(validate141(data.identity, {instancePath:instancePath+"/identity",parentData:data,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate141.errors : vErrors.concat(validate141.errors);
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
validate198.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate198.errors = vErrors;
return errors === 0;
}
validate198.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const ReactiveResponse = validate232;
const schema75 = {"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"session":{"$ref":"https://transit.invalid/generated-validator/51"},"source":{"$ref":"https://transit.invalid/generated-validator/55"},"snapshot":{"$ref":"https://transit.invalid/generated-validator/70"},"event":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"source_changed":{"type":"boolean"},"resource":{"$ref":"https://transit.invalid/generated-validator/26"},"data_revision":{"$ref":"https://transit.invalid/generated-validator/26"},"outcome":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"resource":{"$ref":"https://transit.invalid/generated-validator/26"},"operation":{"$ref":"https://transit.invalid/generated-validator/26"},"phase":{"$ref":"https://transit.invalid/generated-validator/38"},"resolution_input":{"$ref":"https://transit.invalid/generated-validator/26"},"diagnostic":{"anyOf":[{"$ref":"Diagnostic"},{"type":"null"}]}},"required":["resource","operation","phase","resolution_input"]},{"type":"null"}]}},"required":["source_changed","resource","data_revision"]},{"type":"null"}]},"cursor":{"$ref":"https://transit.invalid/generated-validator/48"}},"required":["session"]};
const schema76 = {"type":"object","additionalProperties":false,"properties":{"principal":{"$ref":"https://transit.invalid/generated-validator/26"},"session":{"$ref":"https://transit.invalid/generated-validator/26"},"generation":{"$ref":"https://transit.invalid/generated-validator/26"},"source_revision":{"$ref":"https://transit.invalid/generated-validator/26"},"open_digest":{"$ref":"https://transit.invalid/generated-validator/23"},"lease_before_ms":{"$ref":"https://transit.invalid/generated-validator/26"},"phase":{"$ref":"https://transit.invalid/generated-validator/50"},"attachment":{"$ref":"https://transit.invalid/generated-validator/26"},"nonce":{"$ref":"https://transit.invalid/generated-validator/45"},"subscription":{"$ref":"https://transit.invalid/generated-validator/26"},"subscription_generation":{"$ref":"https://transit.invalid/generated-validator/26"},"operation":{"$ref":"https://transit.invalid/generated-validator/26"}},"required":["principal","session","generation","source_revision","open_digest","lease_before_ms"]};
const schema77 = {"type":"string","enum":["open","closed","expired"]};

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
if(typeof data !== "string"){
validate240.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((data === "open") || (data === "closed")) || (data === "expired"))){
validate240.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema77.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate240.errors = vErrors;
return errors === 0;
}
validate240.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(((((((data.principal === undefined) && (missing0 = "principal")) || ((data.session === undefined) && (missing0 = "session"))) || ((data.generation === undefined) && (missing0 = "generation"))) || ((data.source_revision === undefined) && (missing0 = "source_revision"))) || ((data.open_digest === undefined) && (missing0 = "open_digest"))) || ((data.lease_before_ms === undefined) && (missing0 = "lease_before_ms"))){
validate233.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema76.properties, key0))){
validate233.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.principal !== undefined){
const _errs2 = errors;
if(!(validate119(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.session, {instancePath:instancePath+"/session",parentData:data,parentDataProperty:"session",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.generation, {instancePath:instancePath+"/generation",parentData:data,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.source_revision, {instancePath:instancePath+"/source_revision",parentData:data,parentDataProperty:"source_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate107(data.open_digest, {instancePath:instancePath+"/open_digest",parentData:data,parentDataProperty:"open_digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate107.errors : vErrors.concat(validate107.errors);
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
if(!(validate119(data.lease_before_ms, {instancePath:instancePath+"/lease_before_ms",parentData:data,parentDataProperty:"lease_before_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate240(data.phase, {instancePath:instancePath+"/phase",parentData:data,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate240.errors : vErrors.concat(validate240.errors);
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
if(!(validate119(data.attachment, {instancePath:instancePath+"/attachment",parentData:data,parentDataProperty:"attachment",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate213(data.nonce, {instancePath:instancePath+"/nonce",parentData:data,parentDataProperty:"nonce",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate213.errors : vErrors.concat(validate213.errors);
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
if(!(validate119(data.subscription, {instancePath:instancePath+"/subscription",parentData:data,parentDataProperty:"subscription",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.subscription_generation, {instancePath:instancePath+"/subscription_generation",parentData:data,parentDataProperty:"subscription_generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.operation, {instancePath:instancePath+"/operation",parentData:data,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
validate233.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate233.errors = vErrors;
return errors === 0;
}
validate233.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema78 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/54"},{"type":"null"}]};
const schema79 = {"type":"object","additionalProperties":false,"properties":{"revision":{"$ref":"https://transit.invalid/generated-validator/26"},"target":{"$ref":"https://transit.invalid/generated-validator/26"},"resource":{"$ref":"https://transit.invalid/generated-validator/26"},"realm":{"$ref":"https://transit.invalid/generated-validator/26"},"catalog":{"$ref":"https://transit.invalid/generated-validator/52"},"object":{"$ref":"https://transit.invalid/generated-validator/52"},"metadata_revision":{"$ref":"https://transit.invalid/generated-validator/52"},"metadata_length":{"$ref":"https://transit.invalid/generated-validator/53"},"metadata_digest":{"$ref":"https://transit.invalid/generated-validator/23"},"published":{"type":"boolean"}},"required":["revision","target","resource","realm","catalog","object","metadata_revision","metadata_length","metadata_digest"]};
const schema80 = {"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20};

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
if(errors === 0){
if(typeof data === "string"){
if(func2(data) > 20){
validate254.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern3.test(data)){
validate254.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate254.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate254.errors = vErrors;
return errors === 0;
}
validate254.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema81 = {"type":"integer","minimum":0,"maximum":4294967295};

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
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate258.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 4294967295 || isNaN(data)){
validate258.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate258.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate258.errors = vErrors;
return errors === 0;
}
validate258.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate249(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate249.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((((data.revision === undefined) && (missing0 = "revision")) || ((data.target === undefined) && (missing0 = "target"))) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.realm === undefined) && (missing0 = "realm"))) || ((data.catalog === undefined) && (missing0 = "catalog"))) || ((data.object === undefined) && (missing0 = "object"))) || ((data.metadata_revision === undefined) && (missing0 = "metadata_revision"))) || ((data.metadata_length === undefined) && (missing0 = "metadata_length"))) || ((data.metadata_digest === undefined) && (missing0 = "metadata_digest"))){
validate249.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema79.properties, key0))){
validate249.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.revision !== undefined){
const _errs2 = errors;
if(!(validate119(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.target, {instancePath:instancePath+"/target",parentData:data,parentDataProperty:"target",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate254(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate254.errors : vErrors.concat(validate254.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.object !== undefined){
const _errs7 = errors;
if(!(validate254(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate254.errors : vErrors.concat(validate254.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.metadata_revision !== undefined){
const _errs8 = errors;
if(!(validate254(data.metadata_revision, {instancePath:instancePath+"/metadata_revision",parentData:data,parentDataProperty:"metadata_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate254.errors : vErrors.concat(validate254.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.metadata_length !== undefined){
const _errs9 = errors;
if(!(validate258(data.metadata_length, {instancePath:instancePath+"/metadata_length",parentData:data,parentDataProperty:"metadata_length",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate258.errors : vErrors.concat(validate258.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.metadata_digest !== undefined){
const _errs10 = errors;
if(!(validate107(data.metadata_digest, {instancePath:instancePath+"/metadata_digest",parentData:data,parentDataProperty:"metadata_digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate107.errors : vErrors.concat(validate107.errors);
errors = vErrors.length;
}
var valid0 = _errs10 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.published !== undefined){
const _errs11 = errors;
if(typeof data.published !== "boolean"){
validate249.errors = [{instancePath:instancePath+"/published",schemaPath:"#/properties/published/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
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
validate249.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate249.errors = vErrors;
return errors === 0;
}
validate249.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate249(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate249.errors : vErrors.concat(validate249.errors);
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
validate248.errors = vErrors;
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
validate248.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate248.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema82 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/69"},{"type":"null"}]};
const schema83 = {"type":"object","additionalProperties":false,"properties":{"observation":{"$ref":"https://transit.invalid/generated-validator/63"},"rows":{"$ref":"https://transit.invalid/generated-validator/68"},"more":{"type":"boolean"}},"required":["observation"]};
const schema84 = {"type":"object","additionalProperties":false,"properties":{"data_revision":{"$ref":"https://transit.invalid/generated-validator/26"},"basis":{"$ref":"https://transit.invalid/generated-validator/58"},"schema":{"$ref":"https://transit.invalid/generated-validator/62"}},"required":["data_revision","basis","schema"]};
const schema85 = {"type":"object","additionalProperties":false,"properties":{"cut":{"$ref":"https://transit.invalid/generated-validator/57"},"contract":{"$ref":"https://transit.invalid/generated-validator/23"},"schema":{"$ref":"https://transit.invalid/generated-validator/23"}},"required":["cut","contract","schema"]};
const schema86 = {"type":"object","additionalProperties":false,"properties":{"kind":{"$ref":"https://transit.invalid/generated-validator/56"},"resource":{"$ref":"https://transit.invalid/generated-validator/26"},"revision":{"$ref":"https://transit.invalid/generated-validator/26"},"head":{"$ref":"https://transit.invalid/generated-validator/23"}},"required":["kind","resource","revision"]};
const schema87 = {"type":"string","enum":["kv","table","document"]};

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
if(typeof data !== "string"){
validate269.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((data === "kv") || (data === "table")) || (data === "document"))){
validate269.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema87.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate269.errors = vErrors;
return errors === 0;
}
validate269.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if((((data.kind === undefined) && (missing0 = "kind")) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.revision === undefined) && (missing0 = "revision"))){
validate268.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "kind") || (key0 === "resource")) || (key0 === "revision")) || (key0 === "head"))){
validate268.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.kind !== undefined){
const _errs2 = errors;
if(!(validate269(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate269.errors : vErrors.concat(validate269.errors);
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
if(!(validate119(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate107(data.head, {instancePath:instancePath+"/head",parentData:data,parentDataProperty:"head",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate107.errors : vErrors.concat(validate107.errors);
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
validate268.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate268.errors = vErrors;
return errors === 0;
}
validate268.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate267(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate267.evaluated;
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
validate267.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "cut") || (key0 === "contract")) || (key0 === "schema"))){
validate267.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.cut !== undefined){
const _errs2 = errors;
if(!(validate268(data.cut, {instancePath:instancePath+"/cut",parentData:data,parentDataProperty:"cut",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate268.errors : vErrors.concat(validate268.errors);
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
if(!(validate107(data.contract, {instancePath:instancePath+"/contract",parentData:data,parentDataProperty:"contract",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate107.errors : vErrors.concat(validate107.errors);
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
if(!(validate107(data.schema, {instancePath:instancePath+"/schema",parentData:data,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate107.errors : vErrors.concat(validate107.errors);
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
validate267.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate267.errors = vErrors;
return errors === 0;
}
validate267.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema88 = {"type":"object","additionalProperties":false,"properties":{"names":{"$ref":"https://transit.invalid/generated-validator/61"},"value_type":{"type":"string","enum":["int64"]}},"required":["names"]};
const schema89 = {"type":"array","minItems":2,"maxItems":2,"items":{"$ref":"https://transit.invalid/generated-validator/60"}};
const schema90 = {"type":"object","additionalProperties":false,"properties":{"len":{"$ref":"https://transit.invalid/generated-validator/22"},"data":{"$ref":"https://transit.invalid/generated-validator/59"}},"required":["len"]};
const schema91 = {"type":"array","minItems":255,"maxItems":255,"items":{"$ref":"https://transit.invalid/generated-validator/22"}};

function validate282(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate282.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 255){
validate282.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 255},message:"must NOT have more than 255 items"}];
return false;
}
else {
if(data.length < 255){
validate282.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 255},message:"must NOT have fewer than 255 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate108(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate108.errors : vErrors.concat(validate108.errors);
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
validate282.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate282.errors = vErrors;
return errors === 0;
}
validate282.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


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
if((data.len === undefined) && (missing0 = "len")){
validate280.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "len") || (key0 === "data"))){
validate280.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.len !== undefined){
const _errs2 = errors;
if(!(validate108(data.len, {instancePath:instancePath+"/len",parentData:data,parentDataProperty:"len",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate108.errors : vErrors.concat(validate108.errors);
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
if(!(validate282(data.data, {instancePath:instancePath+"/data",parentData:data,parentDataProperty:"data",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate282.errors : vErrors.concat(validate282.errors);
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
validate280.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate280.errors = vErrors;
return errors === 0;
}
validate280.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(data.length > 2){
validate279.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 2},message:"must NOT have more than 2 items"}];
return false;
}
else {
if(data.length < 2){
validate279.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 2},message:"must NOT have fewer than 2 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate280(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate280.errors : vErrors.concat(validate280.errors);
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


function validate278(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate278.evaluated;
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
validate278.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "names") || (key0 === "value_type"))){
validate278.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.names !== undefined){
const _errs2 = errors;
if(!(validate279(data.names, {instancePath:instancePath+"/names",parentData:data,parentDataProperty:"names",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate279.errors : vErrors.concat(validate279.errors);
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
validate278.errors = [{instancePath:instancePath+"/value_type",schemaPath:"#/properties/value_type/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(data1 === "int64")){
validate278.errors = [{instancePath:instancePath+"/value_type",schemaPath:"#/properties/value_type/enum",keyword:"enum",params:{allowedValues: schema88.properties.value_type.enum},message:"must be equal to one of the allowed values"}];
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
validate278.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate278.errors = vErrors;
return errors === 0;
}
validate278.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if((((data.data_revision === undefined) && (missing0 = "data_revision")) || ((data.basis === undefined) && (missing0 = "basis"))) || ((data.schema === undefined) && (missing0 = "schema"))){
validate265.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "data_revision") || (key0 === "basis")) || (key0 === "schema"))){
validate265.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.data_revision !== undefined){
const _errs2 = errors;
if(!(validate119(data.data_revision, {instancePath:instancePath+"/data_revision",parentData:data,parentDataProperty:"data_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate267(data.basis, {instancePath:instancePath+"/basis",parentData:data,parentDataProperty:"basis",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate267.errors : vErrors.concat(validate267.errors);
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
if(!(validate278(data.schema, {instancePath:instancePath+"/schema",parentData:data,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate278.errors : vErrors.concat(validate278.errors);
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
validate265.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate265.errors = vErrors;
return errors === 0;
}
validate265.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema92 = {"type":"array","minItems":8,"maxItems":8,"items":{"$ref":"https://transit.invalid/generated-validator/67"}};
const schema93 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/66"},{"type":"null"}]};
const schema94 = {"type":"object","additionalProperties":false,"properties":{"key":{"$ref":"https://transit.invalid/generated-validator/64"},"value":{"$ref":"https://transit.invalid/generated-validator/65"}},"required":["key","value"]};
const schema95 = {"type":"string","pattern":"^(0|-[1-9][0-9]*|[1-9][0-9]*)$","maxLength":20};
const pattern7 = new RegExp("^(0|-[1-9][0-9]*|[1-9][0-9]*)$", "u");

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
if(typeof data === "string"){
if(func2(data) > 20){
validate292.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern7.test(data)){
validate292.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(0|-[1-9][0-9]*|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|-[1-9][0-9]*|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate292.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate292.errors = vErrors;
return errors === 0;
}
validate292.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema96 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/64"},{"type":"null"}]};

function validate294(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate294.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate292(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate292.errors : vErrors.concat(validate292.errors);
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
validate294.errors = vErrors;
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
validate294.errors = vErrors;
return errors === 0;
}
validate294.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(((data.key === undefined) && (missing0 = "key")) || ((data.value === undefined) && (missing0 = "value"))){
validate291.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "key") || (key0 === "value"))){
validate291.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.key !== undefined){
const _errs2 = errors;
if(!(validate292(data.key, {instancePath:instancePath+"/key",parentData:data,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate292.errors : vErrors.concat(validate292.errors);
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
if(!(validate294(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate294.errors : vErrors.concat(validate294.errors);
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


function validate290(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate290.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate291(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate291.errors : vErrors.concat(validate291.errors);
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
validate290.errors = vErrors;
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
validate290.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate290.evaluated = {"dynamicProps":true,"dynamicItems":false};


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
if(Array.isArray(data)){
if(data.length > 8){
validate289.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
if(data.length < 8){
validate289.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 8},message:"must NOT have fewer than 8 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate290(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate290.errors : vErrors.concat(validate290.errors);
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
validate289.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate289.errors = vErrors;
return errors === 0;
}
validate289.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


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
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.observation === undefined) && (missing0 = "observation")){
validate264.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "observation") || (key0 === "rows")) || (key0 === "more"))){
validate264.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.observation !== undefined){
const _errs2 = errors;
if(!(validate265(data.observation, {instancePath:instancePath+"/observation",parentData:data,parentDataProperty:"observation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate265.errors : vErrors.concat(validate265.errors);
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
if(!(validate289(data.rows, {instancePath:instancePath+"/rows",parentData:data,parentDataProperty:"rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate289.errors : vErrors.concat(validate289.errors);
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
validate264.errors = [{instancePath:instancePath+"/more",schemaPath:"#/properties/more/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
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
validate264.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate264.errors = vErrors;
return errors === 0;
}
validate264.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate263(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate263.evaluated;
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
validate263.errors = vErrors;
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
validate263.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate263.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate232(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate232.evaluated;
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
validate232.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "version") || (key0 === "session")) || (key0 === "source")) || (key0 === "snapshot")) || (key0 === "event")) || (key0 === "cursor"))){
validate232.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate232.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"}];
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
if(!(validate233(data.session, {instancePath:instancePath+"/session",parentData:data,parentDataProperty:"session",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate233.errors : vErrors.concat(validate233.errors);
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
if(!(validate248(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate248.errors : vErrors.concat(validate248.errors);
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
if(!(validate263(data.snapshot, {instancePath:instancePath+"/snapshot",parentData:data,parentDataProperty:"snapshot",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate263.errors : vErrors.concat(validate263.errors);
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
if(!(validate119(data4.resource, {instancePath:instancePath+"/event/resource",parentData:data4,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data4.data_revision, {instancePath:instancePath+"/event/data_revision",parentData:data4,parentDataProperty:"data_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data8.resource, {instancePath:instancePath+"/event/outcome/resource",parentData:data8,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data8.operation, {instancePath:instancePath+"/event/outcome/operation",parentData:data8,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate175(data8.phase, {instancePath:instancePath+"/event/outcome/phase",parentData:data8,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate175.errors : vErrors.concat(validate175.errors);
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
if(!(validate119(data8.resolution_input, {instancePath:instancePath+"/event/outcome/resolution_input",parentData:data8,parentDataProperty:"resolution_input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate52(data13, {instancePath:instancePath+"/event/outcome/diagnostic",parentData:data8,parentDataProperty:"diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate52.errors : vErrors.concat(validate52.errors);
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
validate232.errors = vErrors;
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
if(!(validate216(data.cursor, {instancePath:instancePath+"/cursor",parentData:data,parentDataProperty:"cursor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate216.errors : vErrors.concat(validate216.errors);
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
validate232.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate232.errors = vErrors;
return errors === 0;
}
validate232.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Bootstrap = validate310;
const schema97 = {"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"attach":{"$ref":"https://transit.invalid/generated-validator/71"},"read":{"$ref":"https://transit.invalid/generated-validator/72"}},"required":["attach","read"]};
const schema98 = {"type":"object","additionalProperties":false,"properties":{"request":{"$ref":"https://transit.invalid/generated-validator/30"},"signature":{"$ref":"https://transit.invalid/generated-validator/31"}},"required":["request","signature"]};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.request === undefined) && (missing0 = "request")) || ((data.signature === undefined) && (missing0 = "signature"))){
validate311.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "request") || (key0 === "signature"))){
validate311.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.request !== undefined){
const _errs2 = errors;
if(!(validate117(data.request, {instancePath:instancePath+"/request",parentData:data,parentDataProperty:"request",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate117.errors : vErrors.concat(validate117.errors);
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
if(!(validate131(data.signature, {instancePath:instancePath+"/signature",parentData:data,parentDataProperty:"signature",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate131.errors : vErrors.concat(validate131.errors);
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
validate311.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate311.errors = vErrors;
return errors === 0;
}
validate311.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema99 = {"type":"object","additionalProperties":false,"properties":{"read":{"$ref":"https://transit.invalid/generated-validator/49"},"signature":{"$ref":"https://transit.invalid/generated-validator/31"},"identity":{"$ref":"https://transit.invalid/generated-validator/35"}},"required":["read","signature","identity"]};

function validate315(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate315.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.read === undefined) && (missing0 = "read")) || ((data.signature === undefined) && (missing0 = "signature"))) || ((data.identity === undefined) && (missing0 = "identity"))){
validate315.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "read") || (key0 === "signature")) || (key0 === "identity"))){
validate315.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.read !== undefined){
const _errs2 = errors;
if(!(validate199(data.read, {instancePath:instancePath+"/read",parentData:data,parentDataProperty:"read",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate199.errors : vErrors.concat(validate199.errors);
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
if(!(validate131(data.signature, {instancePath:instancePath+"/signature",parentData:data,parentDataProperty:"signature",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate131.errors : vErrors.concat(validate131.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.identity !== undefined){
const _errs4 = errors;
if(!(validate141(data.identity, {instancePath:instancePath+"/identity",parentData:data,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate141.errors : vErrors.concat(validate141.errors);
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
validate315.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate315.errors = vErrors;
return errors === 0;
}
validate315.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(((data.attach === undefined) && (missing0 = "attach")) || ((data.read === undefined) && (missing0 = "read"))){
validate310.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "version") || (key0 === "attach")) || (key0 === "read"))){
validate310.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate310.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"}];
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
if(!(validate311(data.attach, {instancePath:instancePath+"/attach",parentData:data,parentDataProperty:"attach",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate311.errors : vErrors.concat(validate311.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.read !== undefined){
const _errs4 = errors;
if(!(validate315(data.read, {instancePath:instancePath+"/read",parentData:data,parentDataProperty:"read",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate315.errors : vErrors.concat(validate315.errors);
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
validate310.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate310.errors = vErrors;
return errors === 0;
}
validate310.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const ClientMessage = validate320;
const schema100 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["attach"],"properties":{"attach":{"$ref":"https://transit.invalid/generated-validator/73"}}},{"type":"object","additionalProperties":false,"required":["command"],"properties":{"command":{"$ref":"https://transit.invalid/generated-validator/71"}}},{"type":"object","additionalProperties":false,"required":["control"],"properties":{"control":{"$ref":"https://transit.invalid/generated-validator/71"}}},{"type":"object","additionalProperties":false,"required":["read"],"properties":{"read":{"$ref":"https://transit.invalid/generated-validator/72"}}}]};
const schema101 = {"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"attach":{"$ref":"https://transit.invalid/generated-validator/71"},"read":{"$ref":"https://transit.invalid/generated-validator/72"}},"required":["attach","read"]};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.attach === undefined) && (missing0 = "attach")) || ((data.read === undefined) && (missing0 = "read"))){
validate321.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "version") || (key0 === "attach")) || (key0 === "read"))){
validate321.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate321.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"}];
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
if(!(validate311(data.attach, {instancePath:instancePath+"/attach",parentData:data,parentDataProperty:"attach",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate311.errors : vErrors.concat(validate311.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.read !== undefined){
const _errs4 = errors;
if(!(validate315(data.read, {instancePath:instancePath+"/read",parentData:data,parentDataProperty:"read",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate315.errors : vErrors.concat(validate315.errors);
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
validate321.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate321.errors = vErrors;
return errors === 0;
}
validate321.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(!(validate321(data.attach, {instancePath:instancePath+"/attach",parentData:data,parentDataProperty:"attach",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate321.errors : vErrors.concat(validate321.errors);
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
if((data.command === undefined) && (missing1 = "command")){
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
if(!(key1 === "command")){
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
if(data.command !== undefined){
if(!(validate311(data.command, {instancePath:instancePath+"/command",parentData:data,parentDataProperty:"command",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate311.errors : vErrors.concat(validate311.errors);
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
if((data.control === undefined) && (missing2 = "control")){
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
if(!(key2 === "control")){
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
if(data.control !== undefined){
if(!(validate311(data.control, {instancePath:instancePath+"/control",parentData:data,parentDataProperty:"control",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate311.errors : vErrors.concat(validate311.errors);
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
if((data.read === undefined) && (missing3 = "read")){
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
if(!(key3 === "read")){
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
if(data.read !== undefined){
if(!(validate315(data.read, {instancePath:instancePath+"/read",parentData:data,parentDataProperty:"read",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate315.errors : vErrors.concat(validate315.errors);
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
validate320.errors = vErrors;
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
validate320.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate320.evaluated = {"dynamicProps":true,"dynamicItems":false};

export const ServerMessage = validate328;
const schema102 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["challenge"],"properties":{"challenge":{"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"nonce":{"$ref":"https://transit.invalid/generated-validator/45"},"valid_for_ms":{"$ref":"https://transit.invalid/generated-validator/53"}},"required":["nonce"]}}},{"type":"object","additionalProperties":false,"required":["attached"],"properties":{"attached":{"type":"object","additionalProperties":false,"properties":{"session":{"$ref":"https://transit.invalid/generated-validator/26"},"generation":{"$ref":"https://transit.invalid/generated-validator/26"},"attachment":{"$ref":"https://transit.invalid/generated-validator/26"}},"required":["session","generation","attachment"]}}},{"$ref":"https://transit.invalid/generated-validator/75"},{"type":"object","additionalProperties":false,"required":["observation"],"properties":{"observation":{"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"session":{"$ref":"https://transit.invalid/generated-validator/51"},"source":{"$ref":"https://transit.invalid/generated-validator/55"},"snapshot":{"$ref":"https://transit.invalid/generated-validator/70"},"event":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"source_changed":{"type":"boolean"},"resource":{"$ref":"https://transit.invalid/generated-validator/26"},"data_revision":{"$ref":"https://transit.invalid/generated-validator/26"},"outcome":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"resource":{"$ref":"https://transit.invalid/generated-validator/26"},"operation":{"$ref":"https://transit.invalid/generated-validator/26"},"phase":{"$ref":"https://transit.invalid/generated-validator/38"},"resolution_input":{"$ref":"https://transit.invalid/generated-validator/26"},"diagnostic":{"anyOf":[{"$ref":"Diagnostic"},{"type":"null"}]}},"required":["resource","operation","phase","resolution_input"]},{"type":"null"}]}},"required":["source_changed","resource","data_revision"]},{"type":"null"}]},"cursor":{"$ref":"https://transit.invalid/generated-validator/48"}},"required":["session"]}}},{"type":"object","additionalProperties":false,"required":["event"],"properties":{"event":{"type":"object","additionalProperties":false,"properties":{"cursor":{"$ref":"https://transit.invalid/generated-validator/47"},"event":{"type":"object","additionalProperties":false,"properties":{"source_changed":{"type":"boolean"},"resource":{"$ref":"https://transit.invalid/generated-validator/26"},"data_revision":{"$ref":"https://transit.invalid/generated-validator/26"},"outcome":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"resource":{"$ref":"https://transit.invalid/generated-validator/26"},"operation":{"$ref":"https://transit.invalid/generated-validator/26"},"phase":{"$ref":"https://transit.invalid/generated-validator/38"},"resolution_input":{"$ref":"https://transit.invalid/generated-validator/26"},"diagnostic":{"anyOf":[{"$ref":"Diagnostic"},{"type":"null"}]}},"required":["resource","operation","phase","resolution_input"]},{"type":"null"}]}},"required":["source_changed","resource","data_revision"]}},"required":["cursor","event"]}}},{"type":"object","additionalProperties":false,"required":["heartbeat"],"properties":{"heartbeat":{"type":"object","additionalProperties":false,"properties":{"version":{"const":1}},"required":[]}}},{"type":"object","additionalProperties":false,"required":["terminal"],"properties":{"terminal":{"type":"object","additionalProperties":false,"properties":{"reason":{"type":"string","enum":["denied","closed","expired","fenced","reset_required","interrupted","invalid_message","capacity"]},"diagnostic":{"anyOf":[{"$ref":"Diagnostic"},{"type":"null"}]}},"required":["reason"]}}}]};
const schema103 = {"type":"object","additionalProperties":false,"required":["receipt"],"properties":{"receipt":{"$ref":"https://transit.invalid/generated-validator/74"}}};
const schema104 = {"type":"object","additionalProperties":false,"properties":{"stage":{"$ref":"https://transit.invalid/generated-validator/36"},"receipt":{"$ref":"https://transit.invalid/generated-validator/42"}},"required":["receipt"]};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.receipt === undefined) && (missing0 = "receipt")){
validate335.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "stage") || (key0 === "receipt"))){
validate335.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.stage !== undefined){
const _errs2 = errors;
if(!(validate158(data.stage, {instancePath:instancePath+"/stage",parentData:data,parentDataProperty:"stage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate158.errors : vErrors.concat(validate158.errors);
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
if(!(validate195(data.receipt, {instancePath:instancePath+"/receipt",parentData:data,parentDataProperty:"receipt",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate195.errors : vErrors.concat(validate195.errors);
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
validate335.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate335.errors = vErrors;
return errors === 0;
}
validate335.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate334(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate334.evaluated;
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
validate334.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "receipt")){
validate334.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.receipt !== undefined){
if(!(validate335(data.receipt, {instancePath:instancePath+"/receipt",parentData:data,parentDataProperty:"receipt",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate335.errors : vErrors.concat(validate335.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate334.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate334.errors = vErrors;
return errors === 0;
}
validate334.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate328(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate328.evaluated;
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
if(!(validate213(data0.nonce, {instancePath:instancePath+"/challenge/nonce",parentData:data0,parentDataProperty:"nonce",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate213.errors : vErrors.concat(validate213.errors);
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
if(!(validate258(data0.valid_for_ms, {instancePath:instancePath+"/challenge/valid_for_ms",parentData:data0,parentDataProperty:"valid_for_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate258.errors : vErrors.concat(validate258.errors);
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
if(!(validate119(data4.session, {instancePath:instancePath+"/attached/session",parentData:data4,parentDataProperty:"session",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data4.generation, {instancePath:instancePath+"/attached/generation",parentData:data4,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data4.attachment, {instancePath:instancePath+"/attached/attachment",parentData:data4,parentDataProperty:"attachment",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate334(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate334.errors : vErrors.concat(validate334.errors);
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
if(!(validate233(data8.session, {instancePath:instancePath+"/observation/session",parentData:data8,parentDataProperty:"session",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate233.errors : vErrors.concat(validate233.errors);
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
if(!(validate248(data8.source, {instancePath:instancePath+"/observation/source",parentData:data8,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate248.errors : vErrors.concat(validate248.errors);
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
if(!(validate263(data8.snapshot, {instancePath:instancePath+"/observation/snapshot",parentData:data8,parentDataProperty:"snapshot",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate263.errors : vErrors.concat(validate263.errors);
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
if(!(validate119(data13.resource, {instancePath:instancePath+"/observation/event/resource",parentData:data13,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data13.data_revision, {instancePath:instancePath+"/observation/event/data_revision",parentData:data13,parentDataProperty:"data_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data17.resource, {instancePath:instancePath+"/observation/event/outcome/resource",parentData:data17,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data17.operation, {instancePath:instancePath+"/observation/event/outcome/operation",parentData:data17,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate175(data17.phase, {instancePath:instancePath+"/observation/event/outcome/phase",parentData:data17,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate175.errors : vErrors.concat(validate175.errors);
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
if(!(validate119(data17.resolution_input, {instancePath:instancePath+"/observation/event/outcome/resolution_input",parentData:data17,parentDataProperty:"resolution_input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate52(data22, {instancePath:instancePath+"/observation/event/outcome/diagnostic",parentData:data17,parentDataProperty:"diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate52.errors : vErrors.concat(validate52.errors);
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
if(!(validate216(data8.cursor, {instancePath:instancePath+"/observation/cursor",parentData:data8,parentDataProperty:"cursor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate216.errors : vErrors.concat(validate216.errors);
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
if(!(validate217(data24.cursor, {instancePath:instancePath+"/event/cursor",parentData:data24,parentDataProperty:"cursor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate217.errors : vErrors.concat(validate217.errors);
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
if(!(validate119(data26.resource, {instancePath:instancePath+"/event/event/resource",parentData:data26,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data26.data_revision, {instancePath:instancePath+"/event/event/data_revision",parentData:data26,parentDataProperty:"data_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data30.resource, {instancePath:instancePath+"/event/event/outcome/resource",parentData:data30,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data30.operation, {instancePath:instancePath+"/event/event/outcome/operation",parentData:data30,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate175(data30.phase, {instancePath:instancePath+"/event/event/outcome/phase",parentData:data30,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate175.errors : vErrors.concat(validate175.errors);
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
if(!(validate119(data30.resolution_input, {instancePath:instancePath+"/event/event/outcome/resolution_input",parentData:data30,parentDataProperty:"resolution_input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate52(data35, {instancePath:instancePath+"/event/event/outcome/diagnostic",parentData:data30,parentDataProperty:"diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate52.errors : vErrors.concat(validate52.errors);
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
const err61 = {instancePath:instancePath+"/terminal/reason",schemaPath:"#/oneOf/6/properties/terminal/properties/reason/enum",keyword:"enum",params:{allowedValues: schema102.oneOf[6].properties.terminal.properties.reason.enum},message:"must be equal to one of the allowed values"};
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
if(!(validate52(data40, {instancePath:instancePath+"/terminal/diagnostic",parentData:data38,parentDataProperty:"diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate52.errors : vErrors.concat(validate52.errors);
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
validate328.errors = vErrors;
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
validate328.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate328.evaluated = {"dynamicProps":true,"dynamicItems":false};

export const Discovery = validate360;
const schema105 = {"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"service":{"$ref":"https://transit.invalid/generated-validator/26"},"ingress":{"$ref":"https://transit.invalid/generated-validator/26"},"resource":{"$ref":"https://transit.invalid/generated-validator/26"},"binding_revision":{"$ref":"https://transit.invalid/generated-validator/26"},"watch_revision":{"$ref":"https://transit.invalid/generated-validator/26"},"sse":{"type":"boolean"},"websocket":{"type":"boolean"},"subprotocol":{"type":"string","maxLength":256},"openapi_sha256":{"$ref":"https://transit.invalid/generated-validator/23"},"asyncapi_sha256":{"$ref":"https://transit.invalid/generated-validator/23"}},"required":["service","ingress","resource","binding_revision","watch_revision","openapi_sha256","asyncapi_sha256"]};

function validate360(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate360.evaluated;
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
validate360.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema105.properties, key0))){
validate360.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate360.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"}];
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
if(!(validate119(data.service, {instancePath:instancePath+"/service",parentData:data,parentDataProperty:"service",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.ingress, {instancePath:instancePath+"/ingress",parentData:data,parentDataProperty:"ingress",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.binding_revision, {instancePath:instancePath+"/binding_revision",parentData:data,parentDataProperty:"binding_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.watch_revision, {instancePath:instancePath+"/watch_revision",parentData:data,parentDataProperty:"watch_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
validate360.errors = [{instancePath:instancePath+"/sse",schemaPath:"#/properties/sse/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
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
validate360.errors = [{instancePath:instancePath+"/websocket",schemaPath:"#/properties/websocket/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
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
validate360.errors = [{instancePath:instancePath+"/subprotocol",schemaPath:"#/properties/subprotocol/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"}];
return false;
}
}
else {
validate360.errors = [{instancePath:instancePath+"/subprotocol",schemaPath:"#/properties/subprotocol/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
if(!(validate107(data.openapi_sha256, {instancePath:instancePath+"/openapi_sha256",parentData:data,parentDataProperty:"openapi_sha256",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate107.errors : vErrors.concat(validate107.errors);
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
if(!(validate107(data.asyncapi_sha256, {instancePath:instancePath+"/asyncapi_sha256",parentData:data,parentDataProperty:"asyncapi_sha256",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate107.errors : vErrors.concat(validate107.errors);
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
validate360.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate360.errors = vErrors;
return errors === 0;
}
validate360.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Error = validate368;
const schema106 = {"type":"object","additionalProperties":false,"properties":{"err":{"type":"string","enum":["ServingRequestFailed","HttpCapacity","InvalidHttpRequest"]},"reason":{"anyOf":[{"type":"string","enum":["denied","closed","expired","fenced","reset_required","not_found","conflict","result_not_completed","unavailable","capacity","invalid_request","internal_failure"]},{"type":"null"}]},"diagnostic":{"anyOf":[{"$ref":"Diagnostic"},{"type":"null"}]}},"required":["err"]};

function validate368(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate368.evaluated;
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
validate368.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "err") || (key0 === "reason")) || (key0 === "diagnostic"))){
validate368.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.err !== undefined){
let data0 = data.err;
const _errs2 = errors;
if(typeof data0 !== "string"){
validate368.errors = [{instancePath:instancePath+"/err",schemaPath:"#/properties/err/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((data0 === "ServingRequestFailed") || (data0 === "HttpCapacity")) || (data0 === "InvalidHttpRequest"))){
validate368.errors = [{instancePath:instancePath+"/err",schemaPath:"#/properties/err/enum",keyword:"enum",params:{allowedValues: schema106.properties.err.enum},message:"must be equal to one of the allowed values"}];
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
const err1 = {instancePath:instancePath+"/reason",schemaPath:"#/properties/reason/anyOf/0/enum",keyword:"enum",params:{allowedValues: schema106.properties.reason.anyOf[0].enum},message:"must be equal to one of the allowed values"};
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
validate368.errors = vErrors;
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
if(!(validate52(data2, {instancePath:instancePath+"/diagnostic",parentData:data,parentDataProperty:"diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate52.errors : vErrors.concat(validate52.errors);
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
validate368.errors = vErrors;
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
validate368.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate368.errors = vErrors;
return errors === 0;
}
validate368.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const SseItem = validate370;
const schema107 = {"type":"object","additionalProperties":false,"properties":{"event":{"type":"string","enum":["attached","event","heartbeat","terminal"]},"data":{"type":"string","maxLength":8192},"id":{"type":"string","pattern":"^(?:[0-9a-f]{2})+$","maxLength":512}},"required":["event","data"]};
const pattern8 = new RegExp("^(?:[0-9a-f]{2})+$", "u");

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
if(((data.event === undefined) && (missing0 = "event")) || ((data.data === undefined) && (missing0 = "data"))){
validate370.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "event") || (key0 === "data")) || (key0 === "id"))){
validate370.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.event !== undefined){
let data0 = data.event;
const _errs2 = errors;
if(typeof data0 !== "string"){
validate370.errors = [{instancePath:instancePath+"/event",schemaPath:"#/properties/event/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((data0 === "attached") || (data0 === "event")) || (data0 === "heartbeat")) || (data0 === "terminal"))){
validate370.errors = [{instancePath:instancePath+"/event",schemaPath:"#/properties/event/enum",keyword:"enum",params:{allowedValues: schema107.properties.event.enum},message:"must be equal to one of the allowed values"}];
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
validate370.errors = [{instancePath:instancePath+"/data",schemaPath:"#/properties/data/maxLength",keyword:"maxLength",params:{limit: 8192},message:"must NOT have more than 8192 characters"}];
return false;
}
}
else {
validate370.errors = [{instancePath:instancePath+"/data",schemaPath:"#/properties/data/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
validate370.errors = [{instancePath:instancePath+"/id",schemaPath:"#/properties/id/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"}];
return false;
}
else {
if(!pattern8.test(data2)){
validate370.errors = [{instancePath:instancePath+"/id",schemaPath:"#/properties/id/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})+$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})+$"+"\""}];
return false;
}
}
}
else {
validate370.errors = [{instancePath:instancePath+"/id",schemaPath:"#/properties/id/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
validate370.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate370.errors = vErrors;
return errors === 0;
}
validate370.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const HostRequest = validate371;
const schema108 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["describe"],"properties":{"describe":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["clock"],"properties":{"clock":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["inspect"],"properties":{"inspect":{"$ref":"https://transit.invalid/generated-validator/49"}}},{"type":"object","additionalProperties":false,"required":["covered"],"properties":{"covered":{"type":"object","additionalProperties":false,"properties":{"observation":{"$ref":"https://transit.invalid/generated-validator/63"},"captured":{"$ref":"https://transit.invalid/generated-validator/58"}},"required":["observation","captured"]}}},{"type":"object","additionalProperties":false,"required":["prepare"],"properties":{"prepare":{"oneOf":[{"type":"object","additionalProperties":false,"required":["open"],"properties":{"open":{"type":"object","additionalProperties":false,"properties":{"session":{"$ref":"https://transit.invalid/generated-validator/26"},"source_revision":{"$ref":"https://transit.invalid/generated-validator/26"},"lease_before_ms":{"$ref":"https://transit.invalid/generated-validator/26"}},"required":["session","source_revision","lease_before_ms"]}}},{"type":"object","additionalProperties":false,"required":["attach"],"properties":{"attach":{"type":"object","additionalProperties":false,"properties":{"identity":{"$ref":"https://transit.invalid/generated-validator/76"},"expected":{"$ref":"https://transit.invalid/generated-validator/26"},"nonce":{"$ref":"https://transit.invalid/generated-validator/45"}},"required":["identity","expected","nonce"]}}},{"type":"object","additionalProperties":false,"required":["subscribe"],"properties":{"subscribe":{"type":"object","additionalProperties":false,"properties":{"identity":{"$ref":"https://transit.invalid/generated-validator/76"},"expected":{"$ref":"https://transit.invalid/generated-validator/26"},"subscription":{"$ref":"https://transit.invalid/generated-validator/26"},"operation":{"$ref":"https://transit.invalid/generated-validator/26"}},"required":["identity","expected","subscription"]}}},{"type":"object","additionalProperties":false,"required":["renew"],"properties":{"renew":{"type":"object","additionalProperties":false,"properties":{"identity":{"$ref":"https://transit.invalid/generated-validator/76"},"expected":{"$ref":"https://transit.invalid/generated-validator/26"},"lease_before_ms":{"$ref":"https://transit.invalid/generated-validator/26"}},"required":["identity","expected","lease_before_ms"]}}},{"type":"object","additionalProperties":false,"required":["unsubscribe"],"properties":{"unsubscribe":{"type":"object","additionalProperties":false,"properties":{"identity":{"$ref":"https://transit.invalid/generated-validator/76"},"subscription":{"$ref":"https://transit.invalid/generated-validator/26"},"generation":{"$ref":"https://transit.invalid/generated-validator/26"}},"required":["identity","subscription","generation"]}}},{"type":"object","additionalProperties":false,"required":["close"],"properties":{"close":{"$ref":"https://transit.invalid/generated-validator/76"}}}]}}},{"type":"object","additionalProperties":false,"required":["submit"],"properties":{"submit":{"$ref":"https://transit.invalid/generated-validator/71"}}},{"type":"object","additionalProperties":false,"required":["observe"],"properties":{"observe":{"$ref":"https://transit.invalid/generated-validator/26"}}},{"type":"object","additionalProperties":false,"required":["sign_read"],"properties":{"sign_read":{"$ref":"https://transit.invalid/generated-validator/49"}}},{"type":"object","additionalProperties":false,"required":["refresh_prepare"],"properties":{"refresh_prepare":{"oneOf":[{"type":"object","additionalProperties":false,"required":["follow"],"properties":{"follow":{"type":"object","additionalProperties":false,"properties":{"session":{"$ref":"https://transit.invalid/generated-validator/76"},"expected":{"$ref":"https://transit.invalid/generated-validator/26"},"template":{"$ref":"https://transit.invalid/generated-validator/52"},"limit":{"$ref":"https://transit.invalid/generated-validator/22"}},"required":["session","expected","template","limit"]}}},{"type":"object","additionalProperties":false,"required":["invalidate"],"properties":{"invalidate":{"$ref":"https://transit.invalid/generated-validator/77"}}},{"type":"object","additionalProperties":false,"required":["acknowledged"],"properties":{"acknowledged":{"type":"object","additionalProperties":false,"properties":{"selection":{"$ref":"https://transit.invalid/generated-validator/77"},"namespace":{"$ref":"https://transit.invalid/generated-validator/52"}},"required":["selection","namespace"]}}},{"type":"object","additionalProperties":false,"required":["pause"],"properties":{"pause":{"$ref":"https://transit.invalid/generated-validator/77"}}}]}}},{"type":"object","additionalProperties":false,"required":["refresh_status"],"properties":{"refresh_status":{"$ref":"https://transit.invalid/generated-validator/77"}}}]};
const schema109 = {"type":"object","additionalProperties":false,"properties":{"session":{"$ref":"https://transit.invalid/generated-validator/26"},"generation":{"$ref":"https://transit.invalid/generated-validator/26"}},"required":["session","generation"]};

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
if(((data.session === undefined) && (missing0 = "session")) || ((data.generation === undefined) && (missing0 = "generation"))){
validate378.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "session") || (key0 === "generation"))){
validate378.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.session !== undefined){
const _errs2 = errors;
if(!(validate119(data.session, {instancePath:instancePath+"/session",parentData:data,parentDataProperty:"session",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.generation, {instancePath:instancePath+"/generation",parentData:data,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
validate378.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate378.errors = vErrors;
return errors === 0;
}
validate378.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema110 = {"type":"object","additionalProperties":false,"properties":{"session":{"$ref":"https://transit.invalid/generated-validator/76"},"generation":{"$ref":"https://transit.invalid/generated-validator/26"}},"required":["session","generation"]};

function validate402(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate402.evaluated;
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
validate402.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "session") || (key0 === "generation"))){
validate402.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.session !== undefined){
const _errs2 = errors;
if(!(validate378(data.session, {instancePath:instancePath+"/session",parentData:data,parentDataProperty:"session",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate378.errors : vErrors.concat(validate378.errors);
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
if(!(validate119(data.generation, {instancePath:instancePath+"/generation",parentData:data,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
validate402.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate402.errors = vErrors;
return errors === 0;
}
validate402.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(!(validate199(data.inspect, {instancePath:instancePath+"/inspect",parentData:data,parentDataProperty:"inspect",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate199.errors : vErrors.concat(validate199.errors);
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
if(!(validate265(data3.observation, {instancePath:instancePath+"/covered/observation",parentData:data3,parentDataProperty:"observation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate265.errors : vErrors.concat(validate265.errors);
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
if(!(validate267(data3.captured, {instancePath:instancePath+"/covered/captured",parentData:data3,parentDataProperty:"captured",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate267.errors : vErrors.concat(validate267.errors);
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
if(!(validate119(data7.session, {instancePath:instancePath+"/prepare/open/session",parentData:data7,parentDataProperty:"session",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data7.source_revision, {instancePath:instancePath+"/prepare/open/source_revision",parentData:data7,parentDataProperty:"source_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data7.lease_before_ms, {instancePath:instancePath+"/prepare/open/lease_before_ms",parentData:data7,parentDataProperty:"lease_before_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate378(data11.identity, {instancePath:instancePath+"/prepare/attach/identity",parentData:data11,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate378.errors : vErrors.concat(validate378.errors);
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
if(!(validate119(data11.expected, {instancePath:instancePath+"/prepare/attach/expected",parentData:data11,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate213(data11.nonce, {instancePath:instancePath+"/prepare/attach/nonce",parentData:data11,parentDataProperty:"nonce",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate213.errors : vErrors.concat(validate213.errors);
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
if(!(validate378(data15.identity, {instancePath:instancePath+"/prepare/subscribe/identity",parentData:data15,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate378.errors : vErrors.concat(validate378.errors);
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
if(!(validate119(data15.expected, {instancePath:instancePath+"/prepare/subscribe/expected",parentData:data15,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data15.subscription, {instancePath:instancePath+"/prepare/subscribe/subscription",parentData:data15,parentDataProperty:"subscription",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data15.operation, {instancePath:instancePath+"/prepare/subscribe/operation",parentData:data15,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate378(data20.identity, {instancePath:instancePath+"/prepare/renew/identity",parentData:data20,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate378.errors : vErrors.concat(validate378.errors);
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
if(!(validate119(data20.expected, {instancePath:instancePath+"/prepare/renew/expected",parentData:data20,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data20.lease_before_ms, {instancePath:instancePath+"/prepare/renew/lease_before_ms",parentData:data20,parentDataProperty:"lease_before_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate378(data24.identity, {instancePath:instancePath+"/prepare/unsubscribe/identity",parentData:data24,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate378.errors : vErrors.concat(validate378.errors);
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
if(!(validate119(data24.subscription, {instancePath:instancePath+"/prepare/unsubscribe/subscription",parentData:data24,parentDataProperty:"subscription",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data24.generation, {instancePath:instancePath+"/prepare/unsubscribe/generation",parentData:data24,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate378(data6.close, {instancePath:instancePath+"/prepare/close",parentData:data6,parentDataProperty:"close",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate378.errors : vErrors.concat(validate378.errors);
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
if(!(validate311(data.submit, {instancePath:instancePath+"/submit",parentData:data,parentDataProperty:"submit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate311.errors : vErrors.concat(validate311.errors);
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
if(!(validate119(data.observe, {instancePath:instancePath+"/observe",parentData:data,parentDataProperty:"observe",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate199(data.sign_read, {instancePath:instancePath+"/sign_read",parentData:data,parentDataProperty:"sign_read",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate199.errors : vErrors.concat(validate199.errors);
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
if(((((data33.session === undefined) && (missing22 = "session")) || ((data33.expected === undefined) && (missing22 = "expected"))) || ((data33.template === undefined) && (missing22 = "template"))) || ((data33.limit === undefined) && (missing22 = "limit"))){
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
if(!((((key22 === "session") || (key22 === "expected")) || (key22 === "template")) || (key22 === "limit"))){
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
if(!(validate378(data33.session, {instancePath:instancePath+"/refresh_prepare/follow/session",parentData:data33,parentDataProperty:"session",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate378.errors : vErrors.concat(validate378.errors);
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
if(!(validate119(data33.expected, {instancePath:instancePath+"/refresh_prepare/follow/expected",parentData:data33,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate254(data33.template, {instancePath:instancePath+"/refresh_prepare/follow/template",parentData:data33,parentDataProperty:"template",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate254.errors : vErrors.concat(validate254.errors);
errors = vErrors.length;
}
var valid25 = _errs103 === errors;
}
else {
var valid25 = true;
}
if(valid25){
if(data33.limit !== undefined){
const _errs104 = errors;
if(!(validate108(data33.limit, {instancePath:instancePath+"/refresh_prepare/follow/limit",parentData:data33,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate108.errors : vErrors.concat(validate108.errors);
errors = vErrors.length;
}
var valid25 = _errs104 === errors;
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
else {
const err71 = {instancePath:instancePath+"/refresh_prepare/follow",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/0/properties/follow/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err71];
}
else {
vErrors.push(err71);
}
errors++;
}
}
}
}
}
}
else {
const err72 = {instancePath:instancePath+"/refresh_prepare",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err72];
}
else {
vErrors.push(err72);
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
const _errs105 = errors;
if(errors === _errs105){
if(data32 && typeof data32 == "object" && !Array.isArray(data32)){
let missing23;
if((data32.invalidate === undefined) && (missing23 = "invalidate")){
const err73 = {instancePath:instancePath+"/refresh_prepare",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/1/required",keyword:"required",params:{missingProperty: missing23},message:"must have required property '"+missing23+"'"};
if(vErrors === null){
vErrors = [err73];
}
else {
vErrors.push(err73);
}
errors++;
}
else {
const _errs107 = errors;
for(const key23 in data32){
if(!(key23 === "invalidate")){
const err74 = {instancePath:instancePath+"/refresh_prepare",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key23},message:"must NOT have additional properties"};
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
if(_errs107 === errors){
if(data32.invalidate !== undefined){
if(!(validate402(data32.invalidate, {instancePath:instancePath+"/refresh_prepare/invalidate",parentData:data32,parentDataProperty:"invalidate",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate402.errors : vErrors.concat(validate402.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err75 = {instancePath:instancePath+"/refresh_prepare",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err75];
}
else {
vErrors.push(err75);
}
errors++;
}
}
var _valid2 = _errs105 === errors;
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
const _errs109 = errors;
if(errors === _errs109){
if(data32 && typeof data32 == "object" && !Array.isArray(data32)){
let missing24;
if((data32.acknowledged === undefined) && (missing24 = "acknowledged")){
const err76 = {instancePath:instancePath+"/refresh_prepare",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/2/required",keyword:"required",params:{missingProperty: missing24},message:"must have required property '"+missing24+"'"};
if(vErrors === null){
vErrors = [err76];
}
else {
vErrors.push(err76);
}
errors++;
}
else {
const _errs111 = errors;
for(const key24 in data32){
if(!(key24 === "acknowledged")){
const err77 = {instancePath:instancePath+"/refresh_prepare",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key24},message:"must NOT have additional properties"};
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
if(_errs111 === errors){
if(data32.acknowledged !== undefined){
let data39 = data32.acknowledged;
const _errs112 = errors;
if(errors === _errs112){
if(data39 && typeof data39 == "object" && !Array.isArray(data39)){
let missing25;
if(((data39.selection === undefined) && (missing25 = "selection")) || ((data39.namespace === undefined) && (missing25 = "namespace"))){
const err78 = {instancePath:instancePath+"/refresh_prepare/acknowledged",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/2/properties/acknowledged/required",keyword:"required",params:{missingProperty: missing25},message:"must have required property '"+missing25+"'"};
if(vErrors === null){
vErrors = [err78];
}
else {
vErrors.push(err78);
}
errors++;
}
else {
const _errs114 = errors;
for(const key25 in data39){
if(!((key25 === "selection") || (key25 === "namespace"))){
const err79 = {instancePath:instancePath+"/refresh_prepare/acknowledged",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/2/properties/acknowledged/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key25},message:"must NOT have additional properties"};
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
if(_errs114 === errors){
if(data39.selection !== undefined){
const _errs115 = errors;
if(!(validate402(data39.selection, {instancePath:instancePath+"/refresh_prepare/acknowledged/selection",parentData:data39,parentDataProperty:"selection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate402.errors : vErrors.concat(validate402.errors);
errors = vErrors.length;
}
var valid28 = _errs115 === errors;
}
else {
var valid28 = true;
}
if(valid28){
if(data39.namespace !== undefined){
const _errs116 = errors;
if(!(validate254(data39.namespace, {instancePath:instancePath+"/refresh_prepare/acknowledged/namespace",parentData:data39,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate254.errors : vErrors.concat(validate254.errors);
errors = vErrors.length;
}
var valid28 = _errs116 === errors;
}
else {
var valid28 = true;
}
}
}
}
}
else {
const err80 = {instancePath:instancePath+"/refresh_prepare/acknowledged",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/2/properties/acknowledged/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err81 = {instancePath:instancePath+"/refresh_prepare",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err81];
}
else {
vErrors.push(err81);
}
errors++;
}
}
var _valid2 = _errs109 === errors;
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
const _errs117 = errors;
if(errors === _errs117){
if(data32 && typeof data32 == "object" && !Array.isArray(data32)){
let missing26;
if((data32.pause === undefined) && (missing26 = "pause")){
const err82 = {instancePath:instancePath+"/refresh_prepare",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/3/required",keyword:"required",params:{missingProperty: missing26},message:"must have required property '"+missing26+"'"};
if(vErrors === null){
vErrors = [err82];
}
else {
vErrors.push(err82);
}
errors++;
}
else {
const _errs119 = errors;
for(const key26 in data32){
if(!(key26 === "pause")){
const err83 = {instancePath:instancePath+"/refresh_prepare",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key26},message:"must NOT have additional properties"};
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
if(_errs119 === errors){
if(data32.pause !== undefined){
if(!(validate402(data32.pause, {instancePath:instancePath+"/refresh_prepare/pause",parentData:data32,parentDataProperty:"pause",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate402.errors : vErrors.concat(validate402.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err84 = {instancePath:instancePath+"/refresh_prepare",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err84];
}
else {
vErrors.push(err84);
}
errors++;
}
}
var _valid2 = _errs117 === errors;
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
const err85 = {instancePath:instancePath+"/refresh_prepare",schemaPath:"#/oneOf/8/properties/refresh_prepare/oneOf",keyword:"oneOf",params:{passingSchemas: passing2},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err85];
}
else {
vErrors.push(err85);
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
const err86 = {instancePath,schemaPath:"#/oneOf/8/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err86];
}
else {
vErrors.push(err86);
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
const _errs121 = errors;
if(errors === _errs121){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing27;
if((data.refresh_status === undefined) && (missing27 = "refresh_status")){
const err87 = {instancePath,schemaPath:"#/oneOf/9/required",keyword:"required",params:{missingProperty: missing27},message:"must have required property '"+missing27+"'"};
if(vErrors === null){
vErrors = [err87];
}
else {
vErrors.push(err87);
}
errors++;
}
else {
const _errs123 = errors;
for(const key27 in data){
if(!(key27 === "refresh_status")){
const err88 = {instancePath,schemaPath:"#/oneOf/9/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key27},message:"must NOT have additional properties"};
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
if(_errs123 === errors){
if(data.refresh_status !== undefined){
if(!(validate402(data.refresh_status, {instancePath:instancePath+"/refresh_status",parentData:data,parentDataProperty:"refresh_status",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate402.errors : vErrors.concat(validate402.errors);
errors = vErrors.length;
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
var _valid0 = _errs121 === errors;
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
const err90 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err90];
}
else {
vErrors.push(err90);
}
errors++;
validate371.errors = vErrors;
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
validate371.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate371.evaluated = {"dynamicProps":true,"dynamicItems":false};

export const HostResponse = validate410;
const schema111 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["description"],"properties":{"description":{"type":"object","additionalProperties":false,"properties":{"connection":{"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"https://transit.invalid/generated-validator/26"},"principal":{"$ref":"https://transit.invalid/generated-validator/26"},"service":{"$ref":"https://transit.invalid/generated-validator/26"},"ingress":{"$ref":"https://transit.invalid/generated-validator/26"}},"required":["realm","principal","service","ingress"]},"discovery":{"$ref":"https://transit.invalid/generated-validator/78"},"observed_ms":{"$ref":"https://transit.invalid/generated-validator/26"},"max_lease_ms":{"$ref":"https://transit.invalid/generated-validator/53"}},"required":["connection","discovery","observed_ms"]}}},{"type":"object","additionalProperties":false,"required":["clock"],"properties":{"clock":{"type":"object","additionalProperties":false,"properties":{"observed_ms":{"$ref":"https://transit.invalid/generated-validator/26"},"max_lease_ms":{"$ref":"https://transit.invalid/generated-validator/53"}},"required":["observed_ms"]}}},{"type":"object","additionalProperties":false,"required":["inspection"],"properties":{"inspection":{"type":"object","additionalProperties":false,"properties":{"response":{"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"session":{"$ref":"https://transit.invalid/generated-validator/51"},"source":{"$ref":"https://transit.invalid/generated-validator/55"},"snapshot":{"$ref":"https://transit.invalid/generated-validator/70"},"event":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"source_changed":{"type":"boolean"},"resource":{"$ref":"https://transit.invalid/generated-validator/26"},"data_revision":{"$ref":"https://transit.invalid/generated-validator/26"},"outcome":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"resource":{"$ref":"https://transit.invalid/generated-validator/26"},"operation":{"$ref":"https://transit.invalid/generated-validator/26"},"phase":{"$ref":"https://transit.invalid/generated-validator/38"},"resolution_input":{"$ref":"https://transit.invalid/generated-validator/26"},"diagnostic":{"$ref":"https://transit.invalid/generated-validator/93"}},"required":["resource","operation","phase","resolution_input"]},{"type":"null"}]}},"required":["source_changed","resource","data_revision"]},{"type":"null"}]},"cursor":{"$ref":"https://transit.invalid/generated-validator/48"}},"required":["session"]},"observation":{"$ref":"https://transit.invalid/generated-validator/63"}},"required":["response","observation"]}}},{"type":"object","additionalProperties":false,"required":["covered"],"properties":{"covered":{"type":"boolean"}}},{"type":"object","additionalProperties":false,"required":["prepared"],"properties":{"prepared":{"$ref":"https://transit.invalid/generated-validator/71"}}},{"$ref":"https://transit.invalid/generated-validator/75"},{"type":"object","additionalProperties":false,"required":["observation"],"properties":{"observation":{"oneOf":[{"type":"object","additionalProperties":false,"required":["pending"],"properties":{"pending":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["committed"],"properties":{"committed":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["rejected"],"properties":{"rejected":{"type":"object","additionalProperties":false,"properties":{"record":{"$ref":"https://transit.invalid/generated-validator/41"},"diagnostic":{"$ref":"https://transit.invalid/generated-validator/93"}},"required":["record","diagnostic"]}}}]}}},{"type":"object","additionalProperties":false,"required":["signed_read"],"properties":{"signed_read":{"$ref":"https://transit.invalid/generated-validator/72"}}},{"type":"object","additionalProperties":false,"required":["refresh_status"],"properties":{"refresh_status":{"type":"object","additionalProperties":false,"properties":{"resource":{"$ref":"https://transit.invalid/generated-validator/26"},"revision":{"$ref":"https://transit.invalid/generated-validator/26"},"policy_revision":{"$ref":"https://transit.invalid/generated-validator/26"},"view":{"type":"object","additionalProperties":false,"properties":{"principal":{"$ref":"https://transit.invalid/generated-validator/26"},"session":{"$ref":"https://transit.invalid/generated-validator/76"},"generation":{"$ref":"https://transit.invalid/generated-validator/26"},"source":{"$ref":"https://transit.invalid/generated-validator/54"},"template":{"$ref":"https://transit.invalid/generated-validator/52"},"namespace":{"$ref":"https://transit.invalid/generated-validator/52"},"dirty":{"$ref":"https://transit.invalid/generated-validator/26"},"covered":{"$ref":"https://transit.invalid/generated-validator/26"},"starts":{"$ref":"https://transit.invalid/generated-validator/22"},"limit":{"$ref":"https://transit.invalid/generated-validator/22"},"next_start_ms":{"$ref":"https://transit.invalid/generated-validator/26"},"enabled":{"type":"boolean"},"phase":{"$ref":"https://transit.invalid/generated-validator/94"},"failure":{"oneOf":[{"$ref":"https://transit.invalid/generated-validator/95"},{"type":"object","additionalProperties":false,"required":["stopped"],"properties":{"stopped":{"type":"object","additionalProperties":false,"properties":{"reason":{"type":"string","enum":["paused","budget_exhausted","session_closed","session_expired","source_changed","binding_unpublished","service_denied","native_denied","query_denied","catalog_denied","resource_unavailable","query_source_unavailable","result_unavailable","result_unpublished","template_invalid","upload_closed","namespace_occupied","query_rejected","query_cancelled","query_retired"]},"input":{"$ref":"https://transit.invalid/generated-validator/26"},"witness":{"oneOf":[{"$ref":"https://transit.invalid/generated-validator/95"},{"type":"object","additionalProperties":false,"required":["revision"],"properties":{"revision":{"type":"object","additionalProperties":false,"properties":{"kind":{"type":"string","enum":["binding","policy","watch","refresh"]},"expected":{"$ref":"https://transit.invalid/generated-validator/26"},"actual":{"$ref":"https://transit.invalid/generated-validator/26"},"proposed":{"$ref":"https://transit.invalid/generated-validator/26"},"present":{"type":"boolean"}},"required":["kind","expected","actual","proposed","present"]}}},{"type":"object","additionalProperties":false,"required":["policy"],"properties":{"policy":{"type":"object","additionalProperties":false,"properties":{"principal":{"$ref":"https://transit.invalid/generated-validator/26"},"revision":{"$ref":"https://transit.invalid/generated-validator/26"},"present":{"type":"boolean"},"commands":{"type":"boolean"},"reads":{"type":"boolean"}},"required":["principal","revision","present","commands","reads"]}}},{"type":"object","additionalProperties":false,"required":["identity"],"properties":{"identity":{"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/23"},"actual":{"$ref":"https://transit.invalid/generated-validator/23"}},"required":["expected","actual"]}}},{"type":"object","additionalProperties":false,"required":["capacity"],"properties":{"capacity":{"type":"object","additionalProperties":false,"properties":{"kind":{"type":"string","enum":["service","caller","service_slots","sessions","caller_sessions"]},"actual":{"$ref":"https://transit.invalid/generated-validator/22"},"limit":{"$ref":"https://transit.invalid/generated-validator/22"}},"required":["kind","actual","limit"]}}},{"type":"object","additionalProperties":false,"required":["generation"],"properties":{"generation":{"$ref":"https://transit.invalid/generated-validator/96"}}},{"type":"object","additionalProperties":false,"required":["session"],"properties":{"session":{"type":"object","additionalProperties":false,"properties":{"phase":{"$ref":"https://transit.invalid/generated-validator/50"},"deadline":{"$ref":"https://transit.invalid/generated-validator/26"},"observed":{"$ref":"https://transit.invalid/generated-validator/26"},"clock_known":{"type":"boolean"}},"required":["phase","deadline","observed","clock_known"]}}},{"type":"object","additionalProperties":false,"required":["source"],"properties":{"source":{"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/26"},"actual":{"$ref":"https://transit.invalid/generated-validator/26"},"present":{"type":"boolean"},"published":{"type":"boolean"},"target":{"$ref":"https://transit.invalid/generated-validator/26"},"resource":{"$ref":"https://transit.invalid/generated-validator/26"},"metadata":{"$ref":"https://transit.invalid/generated-validator/23"}},"required":["expected","actual","present","published","target","resource","metadata"]}}},{"type":"object","additionalProperties":false,"required":["lease"],"properties":{"lease":{"type":"object","additionalProperties":false,"properties":{"kind":{"type":"string","enum":["clock","interval","binding","process","resource","observer"]},"requested":{"$ref":"https://transit.invalid/generated-validator/26"},"observed":{"$ref":"https://transit.invalid/generated-validator/26"},"limit":{"$ref":"https://transit.invalid/generated-validator/26"}},"required":["kind","requested","observed","limit"]}}},{"type":"object","additionalProperties":false,"required":["attachment"],"properties":{"attachment":{"$ref":"https://transit.invalid/generated-validator/96"}}},{"type":"object","additionalProperties":false,"required":["subscription"],"properties":{"subscription":{"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/26"},"actual":{"$ref":"https://transit.invalid/generated-validator/26"},"requested":{"$ref":"https://transit.invalid/generated-validator/26"},"active":{"$ref":"https://transit.invalid/generated-validator/26"}},"required":["expected","actual","requested","active"]}}},{"type":"object","additionalProperties":false,"required":["renewal"],"properties":{"renewal":{"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/26"},"actual":{"$ref":"https://transit.invalid/generated-validator/26"},"proposed":{"$ref":"https://transit.invalid/generated-validator/26"}},"required":["expected","actual","proposed"]}}},{"type":"object","additionalProperties":false,"required":["binding"],"properties":{"binding":{"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/26"},"actual":{"$ref":"https://transit.invalid/generated-validator/26"},"expected_codec":{"$ref":"https://transit.invalid/generated-validator/37"},"actual_codec":{"$ref":"https://transit.invalid/generated-validator/37"},"target":{"$ref":"https://transit.invalid/generated-validator/26"},"present":{"type":"boolean"},"published":{"type":"boolean"}},"required":["expected","actual","expected_codec","actual_codec","target","present","published"]}}},{"type":"object","additionalProperties":false,"required":["refresh"],"properties":{"refresh":{"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/52"},"actual":{"$ref":"https://transit.invalid/generated-validator/52"},"phase":{"$ref":"https://transit.invalid/generated-validator/94"}},"required":["expected","actual","phase"]}}},{"type":"object","additionalProperties":false,"required":["frame"],"properties":{"frame":{"type":"object","additionalProperties":false,"properties":{"correlation":{"$ref":"https://transit.invalid/generated-validator/26"},"expected":{"$ref":"https://transit.invalid/generated-validator/26"},"actual":{"$ref":"https://transit.invalid/generated-validator/26"},"kind":{"type":"string","enum":["reply_source","observer","timer","administrator"]},"actual_known":{"type":"boolean"}},"required":["correlation","expected","actual","kind"]}}},{"type":"object","additionalProperties":false,"required":["target"],"properties":{"target":{"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/26"},"actual":{"$ref":"https://transit.invalid/generated-validator/26"},"kind":{"type":"string","enum":["source","resource"]}},"required":["expected","actual","kind"]}}},{"type":"object","additionalProperties":false,"required":["basis"],"properties":{"basis":{"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/23"},"actual":{"$ref":"https://transit.invalid/generated-validator/23"},"kind":{"type":"string","enum":["schema","contract","metadata"]}},"required":["expected","actual","kind"]}}},{"type":"object","additionalProperties":false,"required":["source_kind"],"properties":{"source_kind":{"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/56"},"actual":{"$ref":"https://transit.invalid/generated-validator/56"}},"required":["expected","actual"]}}},{"type":"object","additionalProperties":false,"required":["table"],"properties":{"table":{"$ref":"https://transit.invalid/generated-validator/52"}}},{"type":"object","additionalProperties":false,"required":["watch_type"],"properties":{"watch_type":{"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/97"},"actual":{"$ref":"https://transit.invalid/generated-validator/97"},"column":{"$ref":"https://transit.invalid/generated-validator/22"}},"required":["expected","actual"]}}},{"type":"object","additionalProperties":false,"required":["progress"],"properties":{"progress":{"type":"object","additionalProperties":false,"properties":{"present":{"type":"boolean"},"actual":{"$ref":"https://transit.invalid/generated-validator/26"},"limit":{"$ref":"https://transit.invalid/generated-validator/26"},"key":{"$ref":"https://transit.invalid/generated-validator/23"},"length":{"$ref":"https://transit.invalid/generated-validator/22"}},"required":["present","actual","limit","key","length"]}}},{"type":"object","additionalProperties":false,"required":["reader_identity"],"properties":{"reader_identity":{"type":"object","additionalProperties":false,"properties":{"field":{"type":"string","enum":["principal","pid","permissions","turn_pid"]},"expected":{"$ref":"https://transit.invalid/generated-validator/26"},"actual":{"$ref":"https://transit.invalid/generated-validator/26"},"present":{"type":"boolean"},"policy_revision":{"$ref":"https://transit.invalid/generated-validator/26"},"policy_known":{"type":"boolean"}},"required":["field","expected","actual"]}}},{"type":"object","additionalProperties":false,"required":["reader_failure"],"properties":{"reader_failure":{"type":"object","additionalProperties":false,"properties":{"operation":{"type":"string","enum":["identity","source","requester","result"]},"principal":{"$ref":"https://transit.invalid/generated-validator/26"},"resource":{"$ref":"https://transit.invalid/generated-validator/26"},"namespace":{"$ref":"https://transit.invalid/generated-validator/26"},"cause":{"type":"string","enum":["AccessDenied","Forbidden","StateResourceExpired","UnknownStateResource","DeadlineExpired","RetiredProcess","CatalogDenied","QueryDenied","QuerySourceUnavailable","ResultUnavailable","PublicationNotPublished"]}},"required":["operation","principal","resource","cause"]}}},{"type":"object","additionalProperties":false,"required":["reader_resource"],"properties":{"reader_resource":{"type":"object","additionalProperties":false,"properties":{"role":{"type":"string","enum":["source","requester"]},"resource":{"$ref":"https://transit.invalid/generated-validator/26"},"expected_writer":{"$ref":"https://transit.invalid/generated-validator/26"},"actual_writer":{"$ref":"https://transit.invalid/generated-validator/26"},"phase":{"type":"string","enum":["active","retired","reclaimed"]},"writer_check":{"type":"boolean"},"revision":{"$ref":"https://transit.invalid/generated-validator/26"}},"required":["role","resource","expected_writer","actual_writer","phase","writer_check","revision"]}}},{"type":"object","additionalProperties":false,"required":["watch_shape"],"properties":{"watch_shape":{"type":"object","additionalProperties":false,"properties":{"columns":{"$ref":"https://transit.invalid/generated-validator/22"},"first_nullable":{"type":"boolean"},"primary_columns":{"$ref":"https://transit.invalid/generated-validator/22"},"primary_first":{"type":"boolean"}},"required":["columns","first_nullable","primary_columns","primary_first"]}}},{"type":"object","additionalProperties":false,"required":["reader_template"],"properties":{"reader_template":{"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"https://transit.invalid/generated-validator/26"},"present":{"type":"boolean"},"phase":{"type":"string","enum":["uploading","sealed","admitted","complete","cancelled","denied","rejected","retired"]},"manifest":{"type":"boolean"}},"required":["namespace","present"]}}}]}},"required":["reason","input"]}}}]}},"required":["principal","session","generation","source","template","namespace","dirty","covered","limit"]},"diagnostic":{"$ref":"https://transit.invalid/generated-validator/93"},"query_diagnostic":{"$ref":"https://transit.invalid/generated-validator/93"}},"required":["resource","revision","policy_revision","view"]}}}]};
const schema112 = {"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"service":{"$ref":"https://transit.invalid/generated-validator/26"},"ingress":{"$ref":"https://transit.invalid/generated-validator/26"},"resource":{"$ref":"https://transit.invalid/generated-validator/26"},"binding_revision":{"$ref":"https://transit.invalid/generated-validator/26"},"watch_revision":{"$ref":"https://transit.invalid/generated-validator/26"},"sse":{"type":"boolean"},"websocket":{"type":"boolean"},"subprotocol":{"type":"string","maxLength":256},"openapi_sha256":{"$ref":"https://transit.invalid/generated-validator/23"},"asyncapi_sha256":{"$ref":"https://transit.invalid/generated-validator/23"}},"required":["service","ingress","resource","binding_revision","watch_revision","openapi_sha256","asyncapi_sha256"]};

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
if((((((((data.service === undefined) && (missing0 = "service")) || ((data.ingress === undefined) && (missing0 = "ingress"))) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.binding_revision === undefined) && (missing0 = "binding_revision"))) || ((data.watch_revision === undefined) && (missing0 = "watch_revision"))) || ((data.openapi_sha256 === undefined) && (missing0 = "openapi_sha256"))) || ((data.asyncapi_sha256 === undefined) && (missing0 = "asyncapi_sha256"))){
validate415.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema112.properties, key0))){
validate415.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate415.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"}];
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
if(!(validate119(data.service, {instancePath:instancePath+"/service",parentData:data,parentDataProperty:"service",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.ingress, {instancePath:instancePath+"/ingress",parentData:data,parentDataProperty:"ingress",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.binding_revision, {instancePath:instancePath+"/binding_revision",parentData:data,parentDataProperty:"binding_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.watch_revision, {instancePath:instancePath+"/watch_revision",parentData:data,parentDataProperty:"watch_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
validate415.errors = [{instancePath:instancePath+"/sse",schemaPath:"#/properties/sse/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
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
validate415.errors = [{instancePath:instancePath+"/websocket",schemaPath:"#/properties/websocket/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
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
validate415.errors = [{instancePath:instancePath+"/subprotocol",schemaPath:"#/properties/subprotocol/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"}];
return false;
}
}
else {
validate415.errors = [{instancePath:instancePath+"/subprotocol",schemaPath:"#/properties/subprotocol/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
if(!(validate107(data.openapi_sha256, {instancePath:instancePath+"/openapi_sha256",parentData:data,parentDataProperty:"openapi_sha256",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate107.errors : vErrors.concat(validate107.errors);
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
if(!(validate107(data.asyncapi_sha256, {instancePath:instancePath+"/asyncapi_sha256",parentData:data,parentDataProperty:"asyncapi_sha256",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate107.errors : vErrors.concat(validate107.errors);
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
validate415.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate415.errors = vErrors;
return errors === 0;
}
validate415.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema113 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/92"},{"type":"null"}]};
const schema114 = {"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"definition":{"$ref":"https://transit.invalid/generated-validator/0"},"code":{"type":"string","maxLength":96},"category":{"$ref":"https://transit.invalid/generated-validator/1"},"stage":{"$ref":"https://transit.invalid/generated-validator/2"},"outcome":{"$ref":"https://transit.invalid/generated-validator/3"},"evidence":{"$ref":"https://transit.invalid/generated-validator/4"},"message":{"type":"string","maxLength":384},"cause":{"$ref":"https://transit.invalid/generated-validator/5"},"identity":{"$ref":"https://transit.invalid/generated-validator/80"},"location":{"$ref":"https://transit.invalid/generated-validator/82"},"facts":{"$ref":"https://transit.invalid/generated-validator/88"},"actions":{"$ref":"https://transit.invalid/generated-validator/91"}},"required":["version","definition","code","category","stage","outcome","evidence","message"]};
const schema115 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/79"},{"type":"null"}]};
const schema116 = {"type":"object","additionalProperties":false,"properties":{"domain":{"$ref":"https://transit.invalid/generated-validator/6"},"id":{"$ref":"https://transit.invalid/generated-validator/7"},"realm":{"$ref":"https://transit.invalid/generated-validator/8"},"resource":{"$ref":"https://transit.invalid/generated-validator/8"},"sequence":{"$ref":"https://transit.invalid/generated-validator/8"}},"required":["domain","id"]};

function validate446(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate446.evaluated;
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
validate446.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "domain") || (key0 === "id")) || (key0 === "realm")) || (key0 === "resource")) || (key0 === "sequence"))){
validate446.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.domain !== undefined){
const _errs2 = errors;
if(!(validate67(data.domain, {instancePath:instancePath+"/domain",parentData:data,parentDataProperty:"domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate67.errors : vErrors.concat(validate67.errors);
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
if(!(validate69(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate69.errors : vErrors.concat(validate69.errors);
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
if(!(validate71(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate71.errors : vErrors.concat(validate71.errors);
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
if(!(validate71(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate71.errors : vErrors.concat(validate71.errors);
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
if(!(validate71(data.sequence, {instancePath:instancePath+"/sequence",parentData:data,parentDataProperty:"sequence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate71.errors : vErrors.concat(validate71.errors);
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
validate446.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate446.errors = vErrors;
return errors === 0;
}
validate446.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate446(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate446.errors : vErrors.concat(validate446.errors);
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
validate445.errors = vErrors;
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
validate445.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate445.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema117 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/81"},{"type":"null"}]};
const schema118 = {"type":"object","additionalProperties":false,"properties":{"source":{"$ref":"https://transit.invalid/generated-validator/11"},"source_encoding":{"$ref":"https://transit.invalid/generated-validator/12"},"source_truncated":{"type":"boolean"},"statement":{"$ref":"https://transit.invalid/generated-validator/8"},"offset":{"$ref":"https://transit.invalid/generated-validator/7"},"length":{"$ref":"https://transit.invalid/generated-validator/7"},"line":{"$ref":"https://transit.invalid/generated-validator/7"},"byte_column":{"$ref":"https://transit.invalid/generated-validator/7"}},"required":["offset","length","line","byte_column"]};

function validate455(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate455.evaluated;
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
validate455.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "source") || (key0 === "source_encoding")) || (key0 === "source_truncated")) || (key0 === "statement")) || (key0 === "offset")) || (key0 === "length")) || (key0 === "line")) || (key0 === "byte_column"))){
validate455.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.source !== undefined){
const _errs2 = errors;
if(!(validate79(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate79.errors : vErrors.concat(validate79.errors);
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
if(!(validate81(data.source_encoding, {instancePath:instancePath+"/source_encoding",parentData:data,parentDataProperty:"source_encoding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate81.errors : vErrors.concat(validate81.errors);
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
validate455.errors = [{instancePath:instancePath+"/source_truncated",schemaPath:"#/properties/source_truncated/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
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
if(!(validate71(data.statement, {instancePath:instancePath+"/statement",parentData:data,parentDataProperty:"statement",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate71.errors : vErrors.concat(validate71.errors);
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
if(!(validate69(data.offset, {instancePath:instancePath+"/offset",parentData:data,parentDataProperty:"offset",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate69.errors : vErrors.concat(validate69.errors);
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
if(!(validate69(data.length, {instancePath:instancePath+"/length",parentData:data,parentDataProperty:"length",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate69.errors : vErrors.concat(validate69.errors);
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
if(!(validate69(data.line, {instancePath:instancePath+"/line",parentData:data,parentDataProperty:"line",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate69.errors : vErrors.concat(validate69.errors);
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
if(!(validate69(data.byte_column, {instancePath:instancePath+"/byte_column",parentData:data,parentDataProperty:"byte_column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate69.errors : vErrors.concat(validate69.errors);
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
validate455.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate455.errors = vErrors;
return errors === 0;
}
validate455.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate454(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate454.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate455(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate455.errors : vErrors.concat(validate455.errors);
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
validate454.errors = vErrors;
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
validate454.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate454.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema119 = {"type":"array","minItems":16,"maxItems":16,"items":{"$ref":"https://transit.invalid/generated-validator/87"}};
const schema120 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/86"},{"type":"null"}]};
const schema121 = {"type":"object","additionalProperties":false,"properties":{"field":{"$ref":"https://transit.invalid/generated-validator/14"},"origin":{"$ref":"https://transit.invalid/generated-validator/15"},"availability":{"$ref":"https://transit.invalid/generated-validator/16"},"value":{"$ref":"https://transit.invalid/generated-validator/85"}},"required":["field","origin","availability","value"]};
const schema122 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/84"},{"type":"null"}]};
const schema123 = {"oneOf":[{"$ref":"https://transit.invalid/generated-validator/17"},{"$ref":"https://transit.invalid/generated-validator/19"},{"$ref":"https://transit.invalid/generated-validator/20"},{"$ref":"https://transit.invalid/generated-validator/21"},{"$ref":"https://transit.invalid/generated-validator/24"},{"$ref":"https://transit.invalid/generated-validator/83"}]};
const schema124 = {"type":"object","additionalProperties":false,"required":["location"],"properties":{"location":{"$ref":"https://transit.invalid/generated-validator/81"}}};

function validate478(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate478.evaluated;
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
validate478.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "location")){
validate478.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.location !== undefined){
if(!(validate455(data.location, {instancePath:instancePath+"/location",parentData:data,parentDataProperty:"location",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate455.errors : vErrors.concat(validate455.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate478.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate478.errors = vErrors;
return errors === 0;
}
validate478.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
let passing0 = null;
const _errs1 = errors;
if(!(validate95(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate95.errors : vErrors.concat(validate95.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs2 = errors;
if(!(validate97(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate97.errors : vErrors.concat(validate97.errors);
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
if(!(validate101(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate101.errors : vErrors.concat(validate101.errors);
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
if(!(validate104(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate104.errors : vErrors.concat(validate104.errors);
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
if(!(validate106(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate106.errors : vErrors.concat(validate106.errors);
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
if(!(validate478(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate478.errors : vErrors.concat(validate478.errors);
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
validate472.errors = vErrors;
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
validate472.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate472.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate471(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate471.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate472(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate472.errors : vErrors.concat(validate472.errors);
errors = vErrors.length;
}
else {
var props0 = validate472.evaluated.props;
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
validate471.errors = vErrors;
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
validate471.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate471.evaluated = {"dynamicProps":true,"dynamicItems":false};


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
let missing0;
if(((((data.field === undefined) && (missing0 = "field")) || ((data.origin === undefined) && (missing0 = "origin"))) || ((data.availability === undefined) && (missing0 = "availability"))) || ((data.value === undefined) && (missing0 = "value"))){
validate467.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "field") || (key0 === "origin")) || (key0 === "availability")) || (key0 === "value"))){
validate467.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.field !== undefined){
const _errs2 = errors;
if(!(validate89(data.field, {instancePath:instancePath+"/field",parentData:data,parentDataProperty:"field",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate89.errors : vErrors.concat(validate89.errors);
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
if(!(validate91(data.origin, {instancePath:instancePath+"/origin",parentData:data,parentDataProperty:"origin",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate91.errors : vErrors.concat(validate91.errors);
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
if(!(validate93(data.availability, {instancePath:instancePath+"/availability",parentData:data,parentDataProperty:"availability",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate93.errors : vErrors.concat(validate93.errors);
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
if(!(validate471(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate471.errors : vErrors.concat(validate471.errors);
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
validate467.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate467.errors = vErrors;
return errors === 0;
}
validate467.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs1 = errors;
if(!(validate467(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
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
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 16){
validate465.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
if(data.length < 16){
validate465.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate466(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate466.errors : vErrors.concat(validate466.errors);
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
validate465.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate465.errors = vErrors;
return errors === 0;
}
validate465.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema125 = {"type":"array","minItems":4,"maxItems":4,"items":{"$ref":"https://transit.invalid/generated-validator/90"}};
const schema126 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/89"},{"type":"null"}]};
const schema127 = {"type":"object","additionalProperties":false,"properties":{"kind":{"$ref":"https://transit.invalid/generated-validator/25"},"target":{"$ref":"https://transit.invalid/generated-validator/80"}},"required":["kind"]};

function validate488(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate488.evaluated;
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
validate488.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "kind") || (key0 === "target"))){
validate488.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.kind !== undefined){
const _errs2 = errors;
if(!(validate113(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate113.errors : vErrors.concat(validate113.errors);
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
if(!(validate445(data.target, {instancePath:instancePath+"/target",parentData:data,parentDataProperty:"target",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate445.errors : vErrors.concat(validate445.errors);
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
validate488.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate488.errors = vErrors;
return errors === 0;
}
validate488.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate487(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate487.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate488(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate488.errors : vErrors.concat(validate488.errors);
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
validate487.errors = vErrors;
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
validate487.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate487.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate486(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate486.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 4){
validate486.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 4},message:"must NOT have more than 4 items"}];
return false;
}
else {
if(data.length < 4){
validate486.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 4},message:"must NOT have fewer than 4 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate487(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate487.errors : vErrors.concat(validate487.errors);
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
validate486.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate486.errors = vErrors;
return errors === 0;
}
validate486.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


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
if(((((((((data.version === undefined) && (missing0 = "version")) || ((data.definition === undefined) && (missing0 = "definition"))) || ((data.code === undefined) && (missing0 = "code"))) || ((data.category === undefined) && (missing0 = "category"))) || ((data.stage === undefined) && (missing0 = "stage"))) || ((data.outcome === undefined) && (missing0 = "outcome"))) || ((data.evidence === undefined) && (missing0 = "evidence"))) || ((data.message === undefined) && (missing0 = "message"))){
validate438.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema114.properties, key0))){
validate438.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate438.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"}];
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
if(!(validate53(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
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
validate438.errors = [{instancePath:instancePath+"/code",schemaPath:"#/properties/code/maxLength",keyword:"maxLength",params:{limit: 96},message:"must NOT have more than 96 characters"}];
return false;
}
}
else {
validate438.errors = [{instancePath:instancePath+"/code",schemaPath:"#/properties/code/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
if(!(validate55(data.category, {instancePath:instancePath+"/category",parentData:data,parentDataProperty:"category",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate57(data.stage, {instancePath:instancePath+"/stage",parentData:data,parentDataProperty:"stage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
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
if(!(validate59(data.outcome, {instancePath:instancePath+"/outcome",parentData:data,parentDataProperty:"outcome",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate61(data.evidence, {instancePath:instancePath+"/evidence",parentData:data,parentDataProperty:"evidence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate61.errors : vErrors.concat(validate61.errors);
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
validate438.errors = [{instancePath:instancePath+"/message",schemaPath:"#/properties/message/maxLength",keyword:"maxLength",params:{limit: 384},message:"must NOT have more than 384 characters"}];
return false;
}
}
else {
validate438.errors = [{instancePath:instancePath+"/message",schemaPath:"#/properties/message/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
if(!(validate63(data.cause, {instancePath:instancePath+"/cause",parentData:data,parentDataProperty:"cause",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate63.errors : vErrors.concat(validate63.errors);
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
if(!(validate445(data.identity, {instancePath:instancePath+"/identity",parentData:data,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate445.errors : vErrors.concat(validate445.errors);
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
if(!(validate454(data.location, {instancePath:instancePath+"/location",parentData:data,parentDataProperty:"location",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate454.errors : vErrors.concat(validate454.errors);
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
if(!(validate465(data.facts, {instancePath:instancePath+"/facts",parentData:data,parentDataProperty:"facts",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate465.errors : vErrors.concat(validate465.errors);
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
if(!(validate486(data.actions, {instancePath:instancePath+"/actions",parentData:data,parentDataProperty:"actions",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate486.errors : vErrors.concat(validate486.errors);
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
validate438.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate438.errors = vErrors;
return errors === 0;
}
validate438.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate437(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate437.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate438(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate438.errors : vErrors.concat(validate438.errors);
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
validate437.errors = vErrors;
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
validate437.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate437.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema128 = {"type":"string","enum":["idle","copying","admitted","ready","paused","denied","exhausted","failed"]};

function validate517(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate517.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate517.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((data === "idle") || (data === "copying")) || (data === "admitted")) || (data === "ready")) || (data === "paused")) || (data === "denied")) || (data === "exhausted")) || (data === "failed"))){
validate517.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema128.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate517.errors = vErrors;
return errors === 0;
}
validate517.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema129 = {"type":"object","additionalProperties":false,"required":["none"],"properties":{"none":{"type":"object","maxProperties":0}}};

function validate519(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate519.evaluated;
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
validate519.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "none")){
validate519.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
validate519.errors = [{instancePath:instancePath+"/none",schemaPath:"#/properties/none/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"}];
return false;
}
}
else {
validate519.errors = [{instancePath:instancePath+"/none",schemaPath:"#/properties/none/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
}
}
}
}
else {
validate519.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate519.errors = vErrors;
return errors === 0;
}
validate519.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema130 = {"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/26"},"actual":{"$ref":"https://transit.invalid/generated-validator/26"}},"required":["expected","actual"]};

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
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.expected === undefined) && (missing0 = "expected")) || ((data.actual === undefined) && (missing0 = "actual"))){
validate532.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "expected") || (key0 === "actual"))){
validate532.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.expected !== undefined){
const _errs2 = errors;
if(!(validate119(data.expected, {instancePath:instancePath+"/expected",parentData:data,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data.actual, {instancePath:instancePath+"/actual",parentData:data,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
validate532.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate532.errors = vErrors;
return errors === 0;
}
validate532.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema131 = {"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary","int8","int16","int32","int128","uint8","uint16","uint32","uint128","float32","decimal","date","time","timestamp","interval","uuid","structure","list","array","map","tagged_union","json"]};

function validate573(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate573.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate573.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((((((((((((((((((data === "int64") || (data === "uint64")) || (data === "float64")) || (data === "boolean")) || (data === "utf8")) || (data === "binary")) || (data === "int8")) || (data === "int16")) || (data === "int32")) || (data === "int128")) || (data === "uint8")) || (data === "uint16")) || (data === "uint32")) || (data === "uint128")) || (data === "float32")) || (data === "decimal")) || (data === "date")) || (data === "time")) || (data === "timestamp")) || (data === "interval")) || (data === "uuid")) || (data === "structure")) || (data === "list")) || (data === "array")) || (data === "map")) || (data === "tagged_union")) || (data === "json"))){
validate573.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema131.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate573.errors = vErrors;
return errors === 0;
}
validate573.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate410(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate410.evaluated;
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
if(!((((key2 === "realm") || (key2 === "principal")) || (key2 === "service")) || (key2 === "ingress"))){
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
if(!(validate119(data1.realm, {instancePath:instancePath+"/description/connection/realm",parentData:data1,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data1.principal, {instancePath:instancePath+"/description/connection/principal",parentData:data1,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data1.service, {instancePath:instancePath+"/description/connection/service",parentData:data1,parentDataProperty:"service",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate119(data1.ingress, {instancePath:instancePath+"/description/connection/ingress",parentData:data1,parentDataProperty:"ingress",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
const _errs14 = errors;
if(!(validate415(data0.discovery, {instancePath:instancePath+"/description/discovery",parentData:data0,parentDataProperty:"discovery",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate415.errors : vErrors.concat(validate415.errors);
errors = vErrors.length;
}
var valid2 = _errs14 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data0.observed_ms !== undefined){
const _errs15 = errors;
if(!(validate119(data0.observed_ms, {instancePath:instancePath+"/description/observed_ms",parentData:data0,parentDataProperty:"observed_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid2 = _errs15 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data0.max_lease_ms !== undefined){
const _errs16 = errors;
if(!(validate258(data0.max_lease_ms, {instancePath:instancePath+"/description/max_lease_ms",parentData:data0,parentDataProperty:"max_lease_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate258.errors : vErrors.concat(validate258.errors);
errors = vErrors.length;
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
const _errs17 = errors;
if(errors === _errs17){
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
const _errs19 = errors;
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
if(_errs19 === errors){
if(data.clock !== undefined){
let data9 = data.clock;
const _errs20 = errors;
if(errors === _errs20){
if(data9 && typeof data9 == "object" && !Array.isArray(data9)){
let missing4;
if((data9.observed_ms === undefined) && (missing4 = "observed_ms")){
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
const _errs22 = errors;
for(const key4 in data9){
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
if(_errs22 === errors){
if(data9.observed_ms !== undefined){
const _errs23 = errors;
if(!(validate119(data9.observed_ms, {instancePath:instancePath+"/clock/observed_ms",parentData:data9,parentDataProperty:"observed_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid5 = _errs23 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data9.max_lease_ms !== undefined){
const _errs24 = errors;
if(!(validate258(data9.max_lease_ms, {instancePath:instancePath+"/clock/max_lease_ms",parentData:data9,parentDataProperty:"max_lease_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate258.errors : vErrors.concat(validate258.errors);
errors = vErrors.length;
}
var valid5 = _errs24 === errors;
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
var _valid0 = _errs17 === errors;
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
const _errs25 = errors;
if(errors === _errs25){
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
const _errs27 = errors;
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
if(_errs27 === errors){
if(data.inspection !== undefined){
let data12 = data.inspection;
const _errs28 = errors;
if(errors === _errs28){
if(data12 && typeof data12 == "object" && !Array.isArray(data12)){
let missing6;
if(((data12.response === undefined) && (missing6 = "response")) || ((data12.observation === undefined) && (missing6 = "observation"))){
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
const _errs30 = errors;
for(const key6 in data12){
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
if(_errs30 === errors){
if(data12.response !== undefined){
let data13 = data12.response;
const _errs31 = errors;
if(errors === _errs31){
if(data13 && typeof data13 == "object" && !Array.isArray(data13)){
let missing7;
if((data13.session === undefined) && (missing7 = "session")){
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
const _errs33 = errors;
for(const key7 in data13){
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
if(_errs33 === errors){
if(data13.version !== undefined){
const _errs34 = errors;
if(1 !== data13.version){
const err21 = {instancePath:instancePath+"/inspection/response/version",schemaPath:"#/oneOf/2/properties/inspection/properties/response/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
}
errors++;
}
var valid8 = _errs34 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data13.session !== undefined){
const _errs35 = errors;
if(!(validate233(data13.session, {instancePath:instancePath+"/inspection/response/session",parentData:data13,parentDataProperty:"session",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate233.errors : vErrors.concat(validate233.errors);
errors = vErrors.length;
}
var valid8 = _errs35 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data13.source !== undefined){
const _errs36 = errors;
if(!(validate248(data13.source, {instancePath:instancePath+"/inspection/response/source",parentData:data13,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate248.errors : vErrors.concat(validate248.errors);
errors = vErrors.length;
}
var valid8 = _errs36 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data13.snapshot !== undefined){
const _errs37 = errors;
if(!(validate263(data13.snapshot, {instancePath:instancePath+"/inspection/response/snapshot",parentData:data13,parentDataProperty:"snapshot",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate263.errors : vErrors.concat(validate263.errors);
errors = vErrors.length;
}
var valid8 = _errs37 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data13.event !== undefined){
let data18 = data13.event;
const _errs38 = errors;
const _errs39 = errors;
let valid9 = false;
const _errs40 = errors;
if(errors === _errs40){
if(data18 && typeof data18 == "object" && !Array.isArray(data18)){
let missing8;
if((((data18.source_changed === undefined) && (missing8 = "source_changed")) || ((data18.resource === undefined) && (missing8 = "resource"))) || ((data18.data_revision === undefined) && (missing8 = "data_revision"))){
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
const _errs42 = errors;
for(const key8 in data18){
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
if(_errs42 === errors){
if(data18.source_changed !== undefined){
const _errs43 = errors;
if(typeof data18.source_changed !== "boolean"){
const err24 = {instancePath:instancePath+"/inspection/response/event/source_changed",schemaPath:"#/oneOf/2/properties/inspection/properties/response/properties/event/anyOf/0/properties/source_changed/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
}
errors++;
}
var valid10 = _errs43 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data18.resource !== undefined){
const _errs45 = errors;
if(!(validate119(data18.resource, {instancePath:instancePath+"/inspection/response/event/resource",parentData:data18,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid10 = _errs45 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data18.data_revision !== undefined){
const _errs46 = errors;
if(!(validate119(data18.data_revision, {instancePath:instancePath+"/inspection/response/event/data_revision",parentData:data18,parentDataProperty:"data_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid10 = _errs46 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data18.outcome !== undefined){
let data22 = data18.outcome;
const _errs47 = errors;
const _errs48 = errors;
let valid11 = false;
const _errs49 = errors;
if(errors === _errs49){
if(data22 && typeof data22 == "object" && !Array.isArray(data22)){
let missing9;
if(((((data22.resource === undefined) && (missing9 = "resource")) || ((data22.operation === undefined) && (missing9 = "operation"))) || ((data22.phase === undefined) && (missing9 = "phase"))) || ((data22.resolution_input === undefined) && (missing9 = "resolution_input"))){
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
const _errs51 = errors;
for(const key9 in data22){
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
if(_errs51 === errors){
if(data22.resource !== undefined){
const _errs52 = errors;
if(!(validate119(data22.resource, {instancePath:instancePath+"/inspection/response/event/outcome/resource",parentData:data22,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid12 = _errs52 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data22.operation !== undefined){
const _errs53 = errors;
if(!(validate119(data22.operation, {instancePath:instancePath+"/inspection/response/event/outcome/operation",parentData:data22,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid12 = _errs53 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data22.phase !== undefined){
const _errs54 = errors;
if(!(validate175(data22.phase, {instancePath:instancePath+"/inspection/response/event/outcome/phase",parentData:data22,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate175.errors : vErrors.concat(validate175.errors);
errors = vErrors.length;
}
var valid12 = _errs54 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data22.resolution_input !== undefined){
const _errs55 = errors;
if(!(validate119(data22.resolution_input, {instancePath:instancePath+"/inspection/response/event/outcome/resolution_input",parentData:data22,parentDataProperty:"resolution_input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid12 = _errs55 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data22.diagnostic !== undefined){
const _errs56 = errors;
if(!(validate437(data22.diagnostic, {instancePath:instancePath+"/inspection/response/event/outcome/diagnostic",parentData:data22,parentDataProperty:"diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate437.errors : vErrors.concat(validate437.errors);
errors = vErrors.length;
}
var valid12 = _errs56 === errors;
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
var _valid2 = _errs49 === errors;
valid11 = valid11 || _valid2;
const _errs57 = errors;
if(data22 !== null){
const err28 = {instancePath:instancePath+"/inspection/response/event/outcome",schemaPath:"#/oneOf/2/properties/inspection/properties/response/properties/event/anyOf/0/properties/outcome/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err28];
}
else {
vErrors.push(err28);
}
errors++;
}
var _valid2 = _errs57 === errors;
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
errors = _errs48;
if(vErrors !== null){
if(_errs48){
vErrors.length = _errs48;
}
else {
vErrors = null;
}
}
}
var valid10 = _errs47 === errors;
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
var _valid1 = _errs40 === errors;
valid9 = valid9 || _valid1;
const _errs59 = errors;
if(data18 !== null){
const err31 = {instancePath:instancePath+"/inspection/response/event",schemaPath:"#/oneOf/2/properties/inspection/properties/response/properties/event/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err31];
}
else {
vErrors.push(err31);
}
errors++;
}
var _valid1 = _errs59 === errors;
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
var valid8 = _errs38 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data13.cursor !== undefined){
const _errs61 = errors;
if(!(validate216(data13.cursor, {instancePath:instancePath+"/inspection/response/cursor",parentData:data13,parentDataProperty:"cursor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate216.errors : vErrors.concat(validate216.errors);
errors = vErrors.length;
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
var valid7 = _errs31 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data12.observation !== undefined){
const _errs62 = errors;
if(!(validate265(data12.observation, {instancePath:instancePath+"/inspection/observation",parentData:data12,parentDataProperty:"observation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate265.errors : vErrors.concat(validate265.errors);
errors = vErrors.length;
}
var valid7 = _errs62 === errors;
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
var _valid0 = _errs25 === errors;
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
const _errs63 = errors;
if(errors === _errs63){
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
const _errs65 = errors;
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
if(_errs65 === errors){
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
var _valid0 = _errs63 === errors;
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
const _errs68 = errors;
if(errors === _errs68){
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
const _errs70 = errors;
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
if(_errs70 === errors){
if(data.prepared !== undefined){
if(!(validate311(data.prepared, {instancePath:instancePath+"/prepared",parentData:data,parentDataProperty:"prepared",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate311.errors : vErrors.concat(validate311.errors);
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
var _valid0 = _errs68 === errors;
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
const _errs72 = errors;
if(!(validate334(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate334.errors : vErrors.concat(validate334.errors);
errors = vErrors.length;
}
var _valid0 = _errs72 === errors;
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
const _errs73 = errors;
if(errors === _errs73){
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
const _errs75 = errors;
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
if(_errs75 === errors){
if(data.observation !== undefined){
let data32 = data.observation;
const _errs77 = errors;
let valid16 = false;
let passing1 = null;
const _errs78 = errors;
if(errors === _errs78){
if(data32 && typeof data32 == "object" && !Array.isArray(data32)){
let missing13;
if((data32.pending === undefined) && (missing13 = "pending")){
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
const _errs80 = errors;
for(const key13 in data32){
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
if(_errs80 === errors){
if(data32.pending !== undefined){
let data33 = data32.pending;
const _errs81 = errors;
if(errors === _errs81){
if(data33 && typeof data33 == "object" && !Array.isArray(data33)){
if(Object.keys(data33).length > 0){
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
var _valid3 = _errs78 === errors;
if(_valid3){
valid16 = true;
passing1 = 0;
var props7 = true;
}
const _errs83 = errors;
if(errors === _errs83){
if(data32 && typeof data32 == "object" && !Array.isArray(data32)){
let missing14;
if((data32.committed === undefined) && (missing14 = "committed")){
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
const _errs85 = errors;
for(const key14 in data32){
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
if(_errs85 === errors){
if(data32.committed !== undefined){
let data34 = data32.committed;
const _errs86 = errors;
if(errors === _errs86){
if(data34 && typeof data34 == "object" && !Array.isArray(data34)){
if(Object.keys(data34).length > 0){
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
var _valid3 = _errs83 === errors;
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
const _errs88 = errors;
if(errors === _errs88){
if(data32 && typeof data32 == "object" && !Array.isArray(data32)){
let missing15;
if((data32.rejected === undefined) && (missing15 = "rejected")){
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
const _errs90 = errors;
for(const key15 in data32){
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
if(_errs90 === errors){
if(data32.rejected !== undefined){
let data35 = data32.rejected;
const _errs91 = errors;
if(errors === _errs91){
if(data35 && typeof data35 == "object" && !Array.isArray(data35)){
let missing16;
if(((data35.record === undefined) && (missing16 = "record")) || ((data35.diagnostic === undefined) && (missing16 = "diagnostic"))){
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
const _errs93 = errors;
for(const key16 in data35){
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
if(_errs93 === errors){
if(data35.record !== undefined){
const _errs94 = errors;
if(!(validate181(data35.record, {instancePath:instancePath+"/observation/rejected/record",parentData:data35,parentDataProperty:"record",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate181.errors : vErrors.concat(validate181.errors);
errors = vErrors.length;
}
var valid20 = _errs94 === errors;
}
else {
var valid20 = true;
}
if(valid20){
if(data35.diagnostic !== undefined){
const _errs95 = errors;
if(!(validate437(data35.diagnostic, {instancePath:instancePath+"/observation/rejected/diagnostic",parentData:data35,parentDataProperty:"diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate437.errors : vErrors.concat(validate437.errors);
errors = vErrors.length;
}
var valid20 = _errs95 === errors;
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
var _valid3 = _errs88 === errors;
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
errors = _errs77;
if(vErrors !== null){
if(_errs77){
vErrors.length = _errs77;
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
var _valid0 = _errs73 === errors;
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
const _errs96 = errors;
if(errors === _errs96){
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
const _errs98 = errors;
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
if(_errs98 === errors){
if(data.signed_read !== undefined){
if(!(validate315(data.signed_read, {instancePath:instancePath+"/signed_read",parentData:data,parentDataProperty:"signed_read",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate315.errors : vErrors.concat(validate315.errors);
errors = vErrors.length;
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
var _valid0 = _errs96 === errors;
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
const _errs100 = errors;
if(errors === _errs100){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing18;
if((data.refresh_status === undefined) && (missing18 = "refresh_status")){
const err66 = {instancePath,schemaPath:"#/oneOf/8/required",keyword:"required",params:{missingProperty: missing18},message:"must have required property '"+missing18+"'"};
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
for(const key18 in data){
if(!(key18 === "refresh_status")){
const err67 = {instancePath,schemaPath:"#/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key18},message:"must NOT have additional properties"};
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
if(data.refresh_status !== undefined){
let data39 = data.refresh_status;
const _errs103 = errors;
if(errors === _errs103){
if(data39 && typeof data39 == "object" && !Array.isArray(data39)){
let missing19;
if(((((data39.resource === undefined) && (missing19 = "resource")) || ((data39.revision === undefined) && (missing19 = "revision"))) || ((data39.policy_revision === undefined) && (missing19 = "policy_revision"))) || ((data39.view === undefined) && (missing19 = "view"))){
const err68 = {instancePath:instancePath+"/refresh_status",schemaPath:"#/oneOf/8/properties/refresh_status/required",keyword:"required",params:{missingProperty: missing19},message:"must have required property '"+missing19+"'"};
if(vErrors === null){
vErrors = [err68];
}
else {
vErrors.push(err68);
}
errors++;
}
else {
const _errs105 = errors;
for(const key19 in data39){
if(!((((((key19 === "resource") || (key19 === "revision")) || (key19 === "policy_revision")) || (key19 === "view")) || (key19 === "diagnostic")) || (key19 === "query_diagnostic"))){
const err69 = {instancePath:instancePath+"/refresh_status",schemaPath:"#/oneOf/8/properties/refresh_status/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key19},message:"must NOT have additional properties"};
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
if(_errs105 === errors){
if(data39.resource !== undefined){
const _errs106 = errors;
if(!(validate119(data39.resource, {instancePath:instancePath+"/refresh_status/resource",parentData:data39,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid23 = _errs106 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data39.revision !== undefined){
const _errs107 = errors;
if(!(validate119(data39.revision, {instancePath:instancePath+"/refresh_status/revision",parentData:data39,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid23 = _errs107 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data39.policy_revision !== undefined){
const _errs108 = errors;
if(!(validate119(data39.policy_revision, {instancePath:instancePath+"/refresh_status/policy_revision",parentData:data39,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid23 = _errs108 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data39.view !== undefined){
let data43 = data39.view;
const _errs109 = errors;
if(errors === _errs109){
if(data43 && typeof data43 == "object" && !Array.isArray(data43)){
let missing20;
if((((((((((data43.principal === undefined) && (missing20 = "principal")) || ((data43.session === undefined) && (missing20 = "session"))) || ((data43.generation === undefined) && (missing20 = "generation"))) || ((data43.source === undefined) && (missing20 = "source"))) || ((data43.template === undefined) && (missing20 = "template"))) || ((data43.namespace === undefined) && (missing20 = "namespace"))) || ((data43.dirty === undefined) && (missing20 = "dirty"))) || ((data43.covered === undefined) && (missing20 = "covered"))) || ((data43.limit === undefined) && (missing20 = "limit"))){
const err70 = {instancePath:instancePath+"/refresh_status/view",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/required",keyword:"required",params:{missingProperty: missing20},message:"must have required property '"+missing20+"'"};
if(vErrors === null){
vErrors = [err70];
}
else {
vErrors.push(err70);
}
errors++;
}
else {
const _errs111 = errors;
for(const key20 in data43){
if(!(func1.call(schema111.oneOf[8].properties.refresh_status.properties.view.properties, key20))){
const err71 = {instancePath:instancePath+"/refresh_status/view",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key20},message:"must NOT have additional properties"};
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
if(_errs111 === errors){
if(data43.principal !== undefined){
const _errs112 = errors;
if(!(validate119(data43.principal, {instancePath:instancePath+"/refresh_status/view/principal",parentData:data43,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid24 = _errs112 === errors;
}
else {
var valid24 = true;
}
if(valid24){
if(data43.session !== undefined){
const _errs113 = errors;
if(!(validate378(data43.session, {instancePath:instancePath+"/refresh_status/view/session",parentData:data43,parentDataProperty:"session",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate378.errors : vErrors.concat(validate378.errors);
errors = vErrors.length;
}
var valid24 = _errs113 === errors;
}
else {
var valid24 = true;
}
if(valid24){
if(data43.generation !== undefined){
const _errs114 = errors;
if(!(validate119(data43.generation, {instancePath:instancePath+"/refresh_status/view/generation",parentData:data43,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid24 = _errs114 === errors;
}
else {
var valid24 = true;
}
if(valid24){
if(data43.source !== undefined){
const _errs115 = errors;
if(!(validate249(data43.source, {instancePath:instancePath+"/refresh_status/view/source",parentData:data43,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate249.errors : vErrors.concat(validate249.errors);
errors = vErrors.length;
}
var valid24 = _errs115 === errors;
}
else {
var valid24 = true;
}
if(valid24){
if(data43.template !== undefined){
const _errs116 = errors;
if(!(validate254(data43.template, {instancePath:instancePath+"/refresh_status/view/template",parentData:data43,parentDataProperty:"template",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate254.errors : vErrors.concat(validate254.errors);
errors = vErrors.length;
}
var valid24 = _errs116 === errors;
}
else {
var valid24 = true;
}
if(valid24){
if(data43.namespace !== undefined){
const _errs117 = errors;
if(!(validate254(data43.namespace, {instancePath:instancePath+"/refresh_status/view/namespace",parentData:data43,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate254.errors : vErrors.concat(validate254.errors);
errors = vErrors.length;
}
var valid24 = _errs117 === errors;
}
else {
var valid24 = true;
}
if(valid24){
if(data43.dirty !== undefined){
const _errs118 = errors;
if(!(validate119(data43.dirty, {instancePath:instancePath+"/refresh_status/view/dirty",parentData:data43,parentDataProperty:"dirty",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid24 = _errs118 === errors;
}
else {
var valid24 = true;
}
if(valid24){
if(data43.covered !== undefined){
const _errs119 = errors;
if(!(validate119(data43.covered, {instancePath:instancePath+"/refresh_status/view/covered",parentData:data43,parentDataProperty:"covered",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid24 = _errs119 === errors;
}
else {
var valid24 = true;
}
if(valid24){
if(data43.starts !== undefined){
const _errs120 = errors;
if(!(validate108(data43.starts, {instancePath:instancePath+"/refresh_status/view/starts",parentData:data43,parentDataProperty:"starts",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate108.errors : vErrors.concat(validate108.errors);
errors = vErrors.length;
}
var valid24 = _errs120 === errors;
}
else {
var valid24 = true;
}
if(valid24){
if(data43.limit !== undefined){
const _errs121 = errors;
if(!(validate108(data43.limit, {instancePath:instancePath+"/refresh_status/view/limit",parentData:data43,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate108.errors : vErrors.concat(validate108.errors);
errors = vErrors.length;
}
var valid24 = _errs121 === errors;
}
else {
var valid24 = true;
}
if(valid24){
if(data43.next_start_ms !== undefined){
const _errs122 = errors;
if(!(validate119(data43.next_start_ms, {instancePath:instancePath+"/refresh_status/view/next_start_ms",parentData:data43,parentDataProperty:"next_start_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid24 = _errs122 === errors;
}
else {
var valid24 = true;
}
if(valid24){
if(data43.enabled !== undefined){
const _errs123 = errors;
if(typeof data43.enabled !== "boolean"){
const err72 = {instancePath:instancePath+"/refresh_status/view/enabled",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/enabled/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err72];
}
else {
vErrors.push(err72);
}
errors++;
}
var valid24 = _errs123 === errors;
}
else {
var valid24 = true;
}
if(valid24){
if(data43.phase !== undefined){
const _errs125 = errors;
if(!(validate517(data43.phase, {instancePath:instancePath+"/refresh_status/view/phase",parentData:data43,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate517.errors : vErrors.concat(validate517.errors);
errors = vErrors.length;
}
var valid24 = _errs125 === errors;
}
else {
var valid24 = true;
}
if(valid24){
if(data43.failure !== undefined){
let data57 = data43.failure;
const _errs126 = errors;
const _errs127 = errors;
let valid25 = false;
let passing2 = null;
const _errs128 = errors;
if(!(validate519(data57, {instancePath:instancePath+"/refresh_status/view/failure",parentData:data43,parentDataProperty:"failure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate519.errors : vErrors.concat(validate519.errors);
errors = vErrors.length;
}
var _valid4 = _errs128 === errors;
if(_valid4){
valid25 = true;
passing2 = 0;
var props9 = true;
}
const _errs129 = errors;
if(errors === _errs129){
if(data57 && typeof data57 == "object" && !Array.isArray(data57)){
let missing21;
if((data57.stopped === undefined) && (missing21 = "stopped")){
const err73 = {instancePath:instancePath+"/refresh_status/view/failure",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/required",keyword:"required",params:{missingProperty: missing21},message:"must have required property '"+missing21+"'"};
if(vErrors === null){
vErrors = [err73];
}
else {
vErrors.push(err73);
}
errors++;
}
else {
const _errs131 = errors;
for(const key21 in data57){
if(!(key21 === "stopped")){
const err74 = {instancePath:instancePath+"/refresh_status/view/failure",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key21},message:"must NOT have additional properties"};
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
if(_errs131 === errors){
if(data57.stopped !== undefined){
let data58 = data57.stopped;
const _errs132 = errors;
if(errors === _errs132){
if(data58 && typeof data58 == "object" && !Array.isArray(data58)){
let missing22;
if(((data58.reason === undefined) && (missing22 = "reason")) || ((data58.input === undefined) && (missing22 = "input"))){
const err75 = {instancePath:instancePath+"/refresh_status/view/failure/stopped",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/required",keyword:"required",params:{missingProperty: missing22},message:"must have required property '"+missing22+"'"};
if(vErrors === null){
vErrors = [err75];
}
else {
vErrors.push(err75);
}
errors++;
}
else {
const _errs134 = errors;
for(const key22 in data58){
if(!(((key22 === "reason") || (key22 === "input")) || (key22 === "witness"))){
const err76 = {instancePath:instancePath+"/refresh_status/view/failure/stopped",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key22},message:"must NOT have additional properties"};
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
if(_errs134 === errors){
if(data58.reason !== undefined){
let data59 = data58.reason;
const _errs135 = errors;
if(typeof data59 !== "string"){
const err77 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/reason",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/reason/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err77];
}
else {
vErrors.push(err77);
}
errors++;
}
if(!((((((((((((((((((((data59 === "paused") || (data59 === "budget_exhausted")) || (data59 === "session_closed")) || (data59 === "session_expired")) || (data59 === "source_changed")) || (data59 === "binding_unpublished")) || (data59 === "service_denied")) || (data59 === "native_denied")) || (data59 === "query_denied")) || (data59 === "catalog_denied")) || (data59 === "resource_unavailable")) || (data59 === "query_source_unavailable")) || (data59 === "result_unavailable")) || (data59 === "result_unpublished")) || (data59 === "template_invalid")) || (data59 === "upload_closed")) || (data59 === "namespace_occupied")) || (data59 === "query_rejected")) || (data59 === "query_cancelled")) || (data59 === "query_retired"))){
const err78 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/reason",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/reason/enum",keyword:"enum",params:{allowedValues: schema111.oneOf[8].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.reason.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err78];
}
else {
vErrors.push(err78);
}
errors++;
}
var valid27 = _errs135 === errors;
}
else {
var valid27 = true;
}
if(valid27){
if(data58.input !== undefined){
const _errs137 = errors;
if(!(validate119(data58.input, {instancePath:instancePath+"/refresh_status/view/failure/stopped/input",parentData:data58,parentDataProperty:"input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid27 = _errs137 === errors;
}
else {
var valid27 = true;
}
if(valid27){
if(data58.witness !== undefined){
let data61 = data58.witness;
const _errs138 = errors;
const _errs139 = errors;
let valid28 = false;
let passing3 = null;
const _errs140 = errors;
if(!(validate519(data61, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",parentData:data58,parentDataProperty:"witness",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate519.errors : vErrors.concat(validate519.errors);
errors = vErrors.length;
}
var _valid5 = _errs140 === errors;
if(_valid5){
valid28 = true;
passing3 = 0;
var props10 = true;
}
const _errs141 = errors;
if(errors === _errs141){
if(data61 && typeof data61 == "object" && !Array.isArray(data61)){
let missing23;
if((data61.revision === undefined) && (missing23 = "revision")){
const err79 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/1/required",keyword:"required",params:{missingProperty: missing23},message:"must have required property '"+missing23+"'"};
if(vErrors === null){
vErrors = [err79];
}
else {
vErrors.push(err79);
}
errors++;
}
else {
const _errs143 = errors;
for(const key23 in data61){
if(!(key23 === "revision")){
const err80 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key23},message:"must NOT have additional properties"};
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
if(_errs143 === errors){
if(data61.revision !== undefined){
let data62 = data61.revision;
const _errs144 = errors;
if(errors === _errs144){
if(data62 && typeof data62 == "object" && !Array.isArray(data62)){
let missing24;
if((((((data62.kind === undefined) && (missing24 = "kind")) || ((data62.expected === undefined) && (missing24 = "expected"))) || ((data62.actual === undefined) && (missing24 = "actual"))) || ((data62.proposed === undefined) && (missing24 = "proposed"))) || ((data62.present === undefined) && (missing24 = "present"))){
const err81 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/revision",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/1/properties/revision/required",keyword:"required",params:{missingProperty: missing24},message:"must have required property '"+missing24+"'"};
if(vErrors === null){
vErrors = [err81];
}
else {
vErrors.push(err81);
}
errors++;
}
else {
const _errs146 = errors;
for(const key24 in data62){
if(!(((((key24 === "kind") || (key24 === "expected")) || (key24 === "actual")) || (key24 === "proposed")) || (key24 === "present"))){
const err82 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/revision",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/1/properties/revision/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key24},message:"must NOT have additional properties"};
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
if(_errs146 === errors){
if(data62.kind !== undefined){
let data63 = data62.kind;
const _errs147 = errors;
if(typeof data63 !== "string"){
const err83 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/revision/kind",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/1/properties/revision/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err83];
}
else {
vErrors.push(err83);
}
errors++;
}
if(!((((data63 === "binding") || (data63 === "policy")) || (data63 === "watch")) || (data63 === "refresh"))){
const err84 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/revision/kind",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/1/properties/revision/properties/kind/enum",keyword:"enum",params:{allowedValues: schema111.oneOf[8].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[1].properties.revision.properties.kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err84];
}
else {
vErrors.push(err84);
}
errors++;
}
var valid30 = _errs147 === errors;
}
else {
var valid30 = true;
}
if(valid30){
if(data62.expected !== undefined){
const _errs149 = errors;
if(!(validate119(data62.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/revision/expected",parentData:data62,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid30 = _errs149 === errors;
}
else {
var valid30 = true;
}
if(valid30){
if(data62.actual !== undefined){
const _errs150 = errors;
if(!(validate119(data62.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/revision/actual",parentData:data62,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid30 = _errs150 === errors;
}
else {
var valid30 = true;
}
if(valid30){
if(data62.proposed !== undefined){
const _errs151 = errors;
if(!(validate119(data62.proposed, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/revision/proposed",parentData:data62,parentDataProperty:"proposed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid30 = _errs151 === errors;
}
else {
var valid30 = true;
}
if(valid30){
if(data62.present !== undefined){
const _errs152 = errors;
if(typeof data62.present !== "boolean"){
const err85 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/revision/present",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/1/properties/revision/properties/present/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err85];
}
else {
vErrors.push(err85);
}
errors++;
}
var valid30 = _errs152 === errors;
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
const err86 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/revision",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/1/properties/revision/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err86];
}
else {
vErrors.push(err86);
}
errors++;
}
}
}
}
}
}
else {
const err87 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err87];
}
else {
vErrors.push(err87);
}
errors++;
}
}
var _valid5 = _errs141 === errors;
if(_valid5 && valid28){
valid28 = false;
passing3 = [passing3, 1];
}
else {
if(_valid5){
valid28 = true;
passing3 = 1;
if(props10 !== true){
props10 = true;
}
}
const _errs154 = errors;
if(errors === _errs154){
if(data61 && typeof data61 == "object" && !Array.isArray(data61)){
let missing25;
if((data61.policy === undefined) && (missing25 = "policy")){
const err88 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/2/required",keyword:"required",params:{missingProperty: missing25},message:"must have required property '"+missing25+"'"};
if(vErrors === null){
vErrors = [err88];
}
else {
vErrors.push(err88);
}
errors++;
}
else {
const _errs156 = errors;
for(const key25 in data61){
if(!(key25 === "policy")){
const err89 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key25},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err89];
}
else {
vErrors.push(err89);
}
errors++;
break;
}
}
if(_errs156 === errors){
if(data61.policy !== undefined){
let data68 = data61.policy;
const _errs157 = errors;
if(errors === _errs157){
if(data68 && typeof data68 == "object" && !Array.isArray(data68)){
let missing26;
if((((((data68.principal === undefined) && (missing26 = "principal")) || ((data68.revision === undefined) && (missing26 = "revision"))) || ((data68.present === undefined) && (missing26 = "present"))) || ((data68.commands === undefined) && (missing26 = "commands"))) || ((data68.reads === undefined) && (missing26 = "reads"))){
const err90 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/policy",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/2/properties/policy/required",keyword:"required",params:{missingProperty: missing26},message:"must have required property '"+missing26+"'"};
if(vErrors === null){
vErrors = [err90];
}
else {
vErrors.push(err90);
}
errors++;
}
else {
const _errs159 = errors;
for(const key26 in data68){
if(!(((((key26 === "principal") || (key26 === "revision")) || (key26 === "present")) || (key26 === "commands")) || (key26 === "reads"))){
const err91 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/policy",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/2/properties/policy/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key26},message:"must NOT have additional properties"};
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
if(_errs159 === errors){
if(data68.principal !== undefined){
const _errs160 = errors;
if(!(validate119(data68.principal, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/policy/principal",parentData:data68,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid32 = _errs160 === errors;
}
else {
var valid32 = true;
}
if(valid32){
if(data68.revision !== undefined){
const _errs161 = errors;
if(!(validate119(data68.revision, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/policy/revision",parentData:data68,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid32 = _errs161 === errors;
}
else {
var valid32 = true;
}
if(valid32){
if(data68.present !== undefined){
const _errs162 = errors;
if(typeof data68.present !== "boolean"){
const err92 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/policy/present",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/2/properties/policy/properties/present/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err92];
}
else {
vErrors.push(err92);
}
errors++;
}
var valid32 = _errs162 === errors;
}
else {
var valid32 = true;
}
if(valid32){
if(data68.commands !== undefined){
const _errs164 = errors;
if(typeof data68.commands !== "boolean"){
const err93 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/policy/commands",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/2/properties/policy/properties/commands/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err93];
}
else {
vErrors.push(err93);
}
errors++;
}
var valid32 = _errs164 === errors;
}
else {
var valid32 = true;
}
if(valid32){
if(data68.reads !== undefined){
const _errs166 = errors;
if(typeof data68.reads !== "boolean"){
const err94 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/policy/reads",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/2/properties/policy/properties/reads/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err94];
}
else {
vErrors.push(err94);
}
errors++;
}
var valid32 = _errs166 === errors;
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
else {
const err95 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/policy",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/2/properties/policy/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err96 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err96];
}
else {
vErrors.push(err96);
}
errors++;
}
}
var _valid5 = _errs154 === errors;
if(_valid5 && valid28){
valid28 = false;
passing3 = [passing3, 2];
}
else {
if(_valid5){
valid28 = true;
passing3 = 2;
if(props10 !== true){
props10 = true;
}
}
const _errs168 = errors;
if(errors === _errs168){
if(data61 && typeof data61 == "object" && !Array.isArray(data61)){
let missing27;
if((data61.identity === undefined) && (missing27 = "identity")){
const err97 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/3/required",keyword:"required",params:{missingProperty: missing27},message:"must have required property '"+missing27+"'"};
if(vErrors === null){
vErrors = [err97];
}
else {
vErrors.push(err97);
}
errors++;
}
else {
const _errs170 = errors;
for(const key27 in data61){
if(!(key27 === "identity")){
const err98 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key27},message:"must NOT have additional properties"};
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
if(_errs170 === errors){
if(data61.identity !== undefined){
let data74 = data61.identity;
const _errs171 = errors;
if(errors === _errs171){
if(data74 && typeof data74 == "object" && !Array.isArray(data74)){
let missing28;
if(((data74.expected === undefined) && (missing28 = "expected")) || ((data74.actual === undefined) && (missing28 = "actual"))){
const err99 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/identity",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/3/properties/identity/required",keyword:"required",params:{missingProperty: missing28},message:"must have required property '"+missing28+"'"};
if(vErrors === null){
vErrors = [err99];
}
else {
vErrors.push(err99);
}
errors++;
}
else {
const _errs173 = errors;
for(const key28 in data74){
if(!((key28 === "expected") || (key28 === "actual"))){
const err100 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/identity",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/3/properties/identity/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key28},message:"must NOT have additional properties"};
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
if(_errs173 === errors){
if(data74.expected !== undefined){
const _errs174 = errors;
if(!(validate107(data74.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/identity/expected",parentData:data74,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate107.errors : vErrors.concat(validate107.errors);
errors = vErrors.length;
}
var valid34 = _errs174 === errors;
}
else {
var valid34 = true;
}
if(valid34){
if(data74.actual !== undefined){
const _errs175 = errors;
if(!(validate107(data74.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/identity/actual",parentData:data74,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate107.errors : vErrors.concat(validate107.errors);
errors = vErrors.length;
}
var valid34 = _errs175 === errors;
}
else {
var valid34 = true;
}
}
}
}
}
else {
const err101 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/identity",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/3/properties/identity/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err101];
}
else {
vErrors.push(err101);
}
errors++;
}
}
}
}
}
}
else {
const err102 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err102];
}
else {
vErrors.push(err102);
}
errors++;
}
}
var _valid5 = _errs168 === errors;
if(_valid5 && valid28){
valid28 = false;
passing3 = [passing3, 3];
}
else {
if(_valid5){
valid28 = true;
passing3 = 3;
if(props10 !== true){
props10 = true;
}
}
const _errs176 = errors;
if(errors === _errs176){
if(data61 && typeof data61 == "object" && !Array.isArray(data61)){
let missing29;
if((data61.capacity === undefined) && (missing29 = "capacity")){
const err103 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/4/required",keyword:"required",params:{missingProperty: missing29},message:"must have required property '"+missing29+"'"};
if(vErrors === null){
vErrors = [err103];
}
else {
vErrors.push(err103);
}
errors++;
}
else {
const _errs178 = errors;
for(const key29 in data61){
if(!(key29 === "capacity")){
const err104 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key29},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err104];
}
else {
vErrors.push(err104);
}
errors++;
break;
}
}
if(_errs178 === errors){
if(data61.capacity !== undefined){
let data77 = data61.capacity;
const _errs179 = errors;
if(errors === _errs179){
if(data77 && typeof data77 == "object" && !Array.isArray(data77)){
let missing30;
if((((data77.kind === undefined) && (missing30 = "kind")) || ((data77.actual === undefined) && (missing30 = "actual"))) || ((data77.limit === undefined) && (missing30 = "limit"))){
const err105 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/capacity",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/4/properties/capacity/required",keyword:"required",params:{missingProperty: missing30},message:"must have required property '"+missing30+"'"};
if(vErrors === null){
vErrors = [err105];
}
else {
vErrors.push(err105);
}
errors++;
}
else {
const _errs181 = errors;
for(const key30 in data77){
if(!(((key30 === "kind") || (key30 === "actual")) || (key30 === "limit"))){
const err106 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/capacity",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/4/properties/capacity/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key30},message:"must NOT have additional properties"};
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
if(_errs181 === errors){
if(data77.kind !== undefined){
let data78 = data77.kind;
const _errs182 = errors;
if(typeof data78 !== "string"){
const err107 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/capacity/kind",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/4/properties/capacity/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err107];
}
else {
vErrors.push(err107);
}
errors++;
}
if(!(((((data78 === "service") || (data78 === "caller")) || (data78 === "service_slots")) || (data78 === "sessions")) || (data78 === "caller_sessions"))){
const err108 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/capacity/kind",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/4/properties/capacity/properties/kind/enum",keyword:"enum",params:{allowedValues: schema111.oneOf[8].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[4].properties.capacity.properties.kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err108];
}
else {
vErrors.push(err108);
}
errors++;
}
var valid36 = _errs182 === errors;
}
else {
var valid36 = true;
}
if(valid36){
if(data77.actual !== undefined){
const _errs184 = errors;
if(!(validate108(data77.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/capacity/actual",parentData:data77,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate108.errors : vErrors.concat(validate108.errors);
errors = vErrors.length;
}
var valid36 = _errs184 === errors;
}
else {
var valid36 = true;
}
if(valid36){
if(data77.limit !== undefined){
const _errs185 = errors;
if(!(validate108(data77.limit, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/capacity/limit",parentData:data77,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate108.errors : vErrors.concat(validate108.errors);
errors = vErrors.length;
}
var valid36 = _errs185 === errors;
}
else {
var valid36 = true;
}
}
}
}
}
}
else {
const err109 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/capacity",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/4/properties/capacity/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err109];
}
else {
vErrors.push(err109);
}
errors++;
}
}
}
}
}
}
else {
const err110 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err110];
}
else {
vErrors.push(err110);
}
errors++;
}
}
var _valid5 = _errs176 === errors;
if(_valid5 && valid28){
valid28 = false;
passing3 = [passing3, 4];
}
else {
if(_valid5){
valid28 = true;
passing3 = 4;
if(props10 !== true){
props10 = true;
}
}
const _errs186 = errors;
if(errors === _errs186){
if(data61 && typeof data61 == "object" && !Array.isArray(data61)){
let missing31;
if((data61.generation === undefined) && (missing31 = "generation")){
const err111 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/5/required",keyword:"required",params:{missingProperty: missing31},message:"must have required property '"+missing31+"'"};
if(vErrors === null){
vErrors = [err111];
}
else {
vErrors.push(err111);
}
errors++;
}
else {
const _errs188 = errors;
for(const key31 in data61){
if(!(key31 === "generation")){
const err112 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key31},message:"must NOT have additional properties"};
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
if(_errs188 === errors){
if(data61.generation !== undefined){
if(!(validate532(data61.generation, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/generation",parentData:data61,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate532.errors : vErrors.concat(validate532.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err113 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err113];
}
else {
vErrors.push(err113);
}
errors++;
}
}
var _valid5 = _errs186 === errors;
if(_valid5 && valid28){
valid28 = false;
passing3 = [passing3, 5];
}
else {
if(_valid5){
valid28 = true;
passing3 = 5;
if(props10 !== true){
props10 = true;
}
}
const _errs190 = errors;
if(errors === _errs190){
if(data61 && typeof data61 == "object" && !Array.isArray(data61)){
let missing32;
if((data61.session === undefined) && (missing32 = "session")){
const err114 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/6/required",keyword:"required",params:{missingProperty: missing32},message:"must have required property '"+missing32+"'"};
if(vErrors === null){
vErrors = [err114];
}
else {
vErrors.push(err114);
}
errors++;
}
else {
const _errs192 = errors;
for(const key32 in data61){
if(!(key32 === "session")){
const err115 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key32},message:"must NOT have additional properties"};
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
if(_errs192 === errors){
if(data61.session !== undefined){
let data82 = data61.session;
const _errs193 = errors;
if(errors === _errs193){
if(data82 && typeof data82 == "object" && !Array.isArray(data82)){
let missing33;
if(((((data82.phase === undefined) && (missing33 = "phase")) || ((data82.deadline === undefined) && (missing33 = "deadline"))) || ((data82.observed === undefined) && (missing33 = "observed"))) || ((data82.clock_known === undefined) && (missing33 = "clock_known"))){
const err116 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/session",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/6/properties/session/required",keyword:"required",params:{missingProperty: missing33},message:"must have required property '"+missing33+"'"};
if(vErrors === null){
vErrors = [err116];
}
else {
vErrors.push(err116);
}
errors++;
}
else {
const _errs195 = errors;
for(const key33 in data82){
if(!((((key33 === "phase") || (key33 === "deadline")) || (key33 === "observed")) || (key33 === "clock_known"))){
const err117 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/session",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/6/properties/session/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key33},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err117];
}
else {
vErrors.push(err117);
}
errors++;
break;
}
}
if(_errs195 === errors){
if(data82.phase !== undefined){
const _errs196 = errors;
if(!(validate240(data82.phase, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/session/phase",parentData:data82,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate240.errors : vErrors.concat(validate240.errors);
errors = vErrors.length;
}
var valid39 = _errs196 === errors;
}
else {
var valid39 = true;
}
if(valid39){
if(data82.deadline !== undefined){
const _errs197 = errors;
if(!(validate119(data82.deadline, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/session/deadline",parentData:data82,parentDataProperty:"deadline",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid39 = _errs197 === errors;
}
else {
var valid39 = true;
}
if(valid39){
if(data82.observed !== undefined){
const _errs198 = errors;
if(!(validate119(data82.observed, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/session/observed",parentData:data82,parentDataProperty:"observed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid39 = _errs198 === errors;
}
else {
var valid39 = true;
}
if(valid39){
if(data82.clock_known !== undefined){
const _errs199 = errors;
if(typeof data82.clock_known !== "boolean"){
const err118 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/session/clock_known",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/6/properties/session/properties/clock_known/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err118];
}
else {
vErrors.push(err118);
}
errors++;
}
var valid39 = _errs199 === errors;
}
else {
var valid39 = true;
}
}
}
}
}
}
}
else {
const err119 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/session",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/6/properties/session/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err120 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/6/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err120];
}
else {
vErrors.push(err120);
}
errors++;
}
}
var _valid5 = _errs190 === errors;
if(_valid5 && valid28){
valid28 = false;
passing3 = [passing3, 6];
}
else {
if(_valid5){
valid28 = true;
passing3 = 6;
if(props10 !== true){
props10 = true;
}
}
const _errs201 = errors;
if(errors === _errs201){
if(data61 && typeof data61 == "object" && !Array.isArray(data61)){
let missing34;
if((data61.source === undefined) && (missing34 = "source")){
const err121 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/7/required",keyword:"required",params:{missingProperty: missing34},message:"must have required property '"+missing34+"'"};
if(vErrors === null){
vErrors = [err121];
}
else {
vErrors.push(err121);
}
errors++;
}
else {
const _errs203 = errors;
for(const key34 in data61){
if(!(key34 === "source")){
const err122 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key34},message:"must NOT have additional properties"};
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
if(_errs203 === errors){
if(data61.source !== undefined){
let data87 = data61.source;
const _errs204 = errors;
if(errors === _errs204){
if(data87 && typeof data87 == "object" && !Array.isArray(data87)){
let missing35;
if((((((((data87.expected === undefined) && (missing35 = "expected")) || ((data87.actual === undefined) && (missing35 = "actual"))) || ((data87.present === undefined) && (missing35 = "present"))) || ((data87.published === undefined) && (missing35 = "published"))) || ((data87.target === undefined) && (missing35 = "target"))) || ((data87.resource === undefined) && (missing35 = "resource"))) || ((data87.metadata === undefined) && (missing35 = "metadata"))){
const err123 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/7/properties/source/required",keyword:"required",params:{missingProperty: missing35},message:"must have required property '"+missing35+"'"};
if(vErrors === null){
vErrors = [err123];
}
else {
vErrors.push(err123);
}
errors++;
}
else {
const _errs206 = errors;
for(const key35 in data87){
if(!(((((((key35 === "expected") || (key35 === "actual")) || (key35 === "present")) || (key35 === "published")) || (key35 === "target")) || (key35 === "resource")) || (key35 === "metadata"))){
const err124 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/7/properties/source/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key35},message:"must NOT have additional properties"};
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
if(_errs206 === errors){
if(data87.expected !== undefined){
const _errs207 = errors;
if(!(validate119(data87.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source/expected",parentData:data87,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid41 = _errs207 === errors;
}
else {
var valid41 = true;
}
if(valid41){
if(data87.actual !== undefined){
const _errs208 = errors;
if(!(validate119(data87.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source/actual",parentData:data87,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid41 = _errs208 === errors;
}
else {
var valid41 = true;
}
if(valid41){
if(data87.present !== undefined){
const _errs209 = errors;
if(typeof data87.present !== "boolean"){
const err125 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source/present",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/7/properties/source/properties/present/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err125];
}
else {
vErrors.push(err125);
}
errors++;
}
var valid41 = _errs209 === errors;
}
else {
var valid41 = true;
}
if(valid41){
if(data87.published !== undefined){
const _errs211 = errors;
if(typeof data87.published !== "boolean"){
const err126 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source/published",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/7/properties/source/properties/published/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err126];
}
else {
vErrors.push(err126);
}
errors++;
}
var valid41 = _errs211 === errors;
}
else {
var valid41 = true;
}
if(valid41){
if(data87.target !== undefined){
const _errs213 = errors;
if(!(validate119(data87.target, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source/target",parentData:data87,parentDataProperty:"target",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid41 = _errs213 === errors;
}
else {
var valid41 = true;
}
if(valid41){
if(data87.resource !== undefined){
const _errs214 = errors;
if(!(validate119(data87.resource, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source/resource",parentData:data87,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid41 = _errs214 === errors;
}
else {
var valid41 = true;
}
if(valid41){
if(data87.metadata !== undefined){
const _errs215 = errors;
if(!(validate107(data87.metadata, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source/metadata",parentData:data87,parentDataProperty:"metadata",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate107.errors : vErrors.concat(validate107.errors);
errors = vErrors.length;
}
var valid41 = _errs215 === errors;
}
else {
var valid41 = true;
}
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
const err127 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/7/properties/source/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err127];
}
else {
vErrors.push(err127);
}
errors++;
}
}
}
}
}
}
else {
const err128 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/7/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err128];
}
else {
vErrors.push(err128);
}
errors++;
}
}
var _valid5 = _errs201 === errors;
if(_valid5 && valid28){
valid28 = false;
passing3 = [passing3, 7];
}
else {
if(_valid5){
valid28 = true;
passing3 = 7;
if(props10 !== true){
props10 = true;
}
}
const _errs216 = errors;
if(errors === _errs216){
if(data61 && typeof data61 == "object" && !Array.isArray(data61)){
let missing36;
if((data61.lease === undefined) && (missing36 = "lease")){
const err129 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/8/required",keyword:"required",params:{missingProperty: missing36},message:"must have required property '"+missing36+"'"};
if(vErrors === null){
vErrors = [err129];
}
else {
vErrors.push(err129);
}
errors++;
}
else {
const _errs218 = errors;
for(const key36 in data61){
if(!(key36 === "lease")){
const err130 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key36},message:"must NOT have additional properties"};
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
if(_errs218 === errors){
if(data61.lease !== undefined){
let data95 = data61.lease;
const _errs219 = errors;
if(errors === _errs219){
if(data95 && typeof data95 == "object" && !Array.isArray(data95)){
let missing37;
if(((((data95.kind === undefined) && (missing37 = "kind")) || ((data95.requested === undefined) && (missing37 = "requested"))) || ((data95.observed === undefined) && (missing37 = "observed"))) || ((data95.limit === undefined) && (missing37 = "limit"))){
const err131 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/lease",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/8/properties/lease/required",keyword:"required",params:{missingProperty: missing37},message:"must have required property '"+missing37+"'"};
if(vErrors === null){
vErrors = [err131];
}
else {
vErrors.push(err131);
}
errors++;
}
else {
const _errs221 = errors;
for(const key37 in data95){
if(!((((key37 === "kind") || (key37 === "requested")) || (key37 === "observed")) || (key37 === "limit"))){
const err132 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/lease",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/8/properties/lease/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key37},message:"must NOT have additional properties"};
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
if(_errs221 === errors){
if(data95.kind !== undefined){
let data96 = data95.kind;
const _errs222 = errors;
if(typeof data96 !== "string"){
const err133 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/lease/kind",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/8/properties/lease/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err133];
}
else {
vErrors.push(err133);
}
errors++;
}
if(!((((((data96 === "clock") || (data96 === "interval")) || (data96 === "binding")) || (data96 === "process")) || (data96 === "resource")) || (data96 === "observer"))){
const err134 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/lease/kind",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/8/properties/lease/properties/kind/enum",keyword:"enum",params:{allowedValues: schema111.oneOf[8].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[8].properties.lease.properties.kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err134];
}
else {
vErrors.push(err134);
}
errors++;
}
var valid43 = _errs222 === errors;
}
else {
var valid43 = true;
}
if(valid43){
if(data95.requested !== undefined){
const _errs224 = errors;
if(!(validate119(data95.requested, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/lease/requested",parentData:data95,parentDataProperty:"requested",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid43 = _errs224 === errors;
}
else {
var valid43 = true;
}
if(valid43){
if(data95.observed !== undefined){
const _errs225 = errors;
if(!(validate119(data95.observed, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/lease/observed",parentData:data95,parentDataProperty:"observed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid43 = _errs225 === errors;
}
else {
var valid43 = true;
}
if(valid43){
if(data95.limit !== undefined){
const _errs226 = errors;
if(!(validate119(data95.limit, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/lease/limit",parentData:data95,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid43 = _errs226 === errors;
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
else {
const err135 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/lease",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/8/properties/lease/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err136 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/8/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err136];
}
else {
vErrors.push(err136);
}
errors++;
}
}
var _valid5 = _errs216 === errors;
if(_valid5 && valid28){
valid28 = false;
passing3 = [passing3, 8];
}
else {
if(_valid5){
valid28 = true;
passing3 = 8;
if(props10 !== true){
props10 = true;
}
}
const _errs227 = errors;
if(errors === _errs227){
if(data61 && typeof data61 == "object" && !Array.isArray(data61)){
let missing38;
if((data61.attachment === undefined) && (missing38 = "attachment")){
const err137 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/9/required",keyword:"required",params:{missingProperty: missing38},message:"must have required property '"+missing38+"'"};
if(vErrors === null){
vErrors = [err137];
}
else {
vErrors.push(err137);
}
errors++;
}
else {
const _errs229 = errors;
for(const key38 in data61){
if(!(key38 === "attachment")){
const err138 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/9/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key38},message:"must NOT have additional properties"};
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
if(_errs229 === errors){
if(data61.attachment !== undefined){
if(!(validate532(data61.attachment, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/attachment",parentData:data61,parentDataProperty:"attachment",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate532.errors : vErrors.concat(validate532.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err139 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/9/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err139];
}
else {
vErrors.push(err139);
}
errors++;
}
}
var _valid5 = _errs227 === errors;
if(_valid5 && valid28){
valid28 = false;
passing3 = [passing3, 9];
}
else {
if(_valid5){
valid28 = true;
passing3 = 9;
if(props10 !== true){
props10 = true;
}
}
const _errs231 = errors;
if(errors === _errs231){
if(data61 && typeof data61 == "object" && !Array.isArray(data61)){
let missing39;
if((data61.subscription === undefined) && (missing39 = "subscription")){
const err140 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/10/required",keyword:"required",params:{missingProperty: missing39},message:"must have required property '"+missing39+"'"};
if(vErrors === null){
vErrors = [err140];
}
else {
vErrors.push(err140);
}
errors++;
}
else {
const _errs233 = errors;
for(const key39 in data61){
if(!(key39 === "subscription")){
const err141 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/10/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key39},message:"must NOT have additional properties"};
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
if(_errs233 === errors){
if(data61.subscription !== undefined){
let data101 = data61.subscription;
const _errs234 = errors;
if(errors === _errs234){
if(data101 && typeof data101 == "object" && !Array.isArray(data101)){
let missing40;
if(((((data101.expected === undefined) && (missing40 = "expected")) || ((data101.actual === undefined) && (missing40 = "actual"))) || ((data101.requested === undefined) && (missing40 = "requested"))) || ((data101.active === undefined) && (missing40 = "active"))){
const err142 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/subscription",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/10/properties/subscription/required",keyword:"required",params:{missingProperty: missing40},message:"must have required property '"+missing40+"'"};
if(vErrors === null){
vErrors = [err142];
}
else {
vErrors.push(err142);
}
errors++;
}
else {
const _errs236 = errors;
for(const key40 in data101){
if(!((((key40 === "expected") || (key40 === "actual")) || (key40 === "requested")) || (key40 === "active"))){
const err143 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/subscription",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/10/properties/subscription/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key40},message:"must NOT have additional properties"};
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
if(_errs236 === errors){
if(data101.expected !== undefined){
const _errs237 = errors;
if(!(validate119(data101.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/subscription/expected",parentData:data101,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid46 = _errs237 === errors;
}
else {
var valid46 = true;
}
if(valid46){
if(data101.actual !== undefined){
const _errs238 = errors;
if(!(validate119(data101.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/subscription/actual",parentData:data101,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid46 = _errs238 === errors;
}
else {
var valid46 = true;
}
if(valid46){
if(data101.requested !== undefined){
const _errs239 = errors;
if(!(validate119(data101.requested, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/subscription/requested",parentData:data101,parentDataProperty:"requested",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid46 = _errs239 === errors;
}
else {
var valid46 = true;
}
if(valid46){
if(data101.active !== undefined){
const _errs240 = errors;
if(!(validate119(data101.active, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/subscription/active",parentData:data101,parentDataProperty:"active",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid46 = _errs240 === errors;
}
else {
var valid46 = true;
}
}
}
}
}
}
}
else {
const err144 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/subscription",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/10/properties/subscription/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err145 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/10/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err145];
}
else {
vErrors.push(err145);
}
errors++;
}
}
var _valid5 = _errs231 === errors;
if(_valid5 && valid28){
valid28 = false;
passing3 = [passing3, 10];
}
else {
if(_valid5){
valid28 = true;
passing3 = 10;
if(props10 !== true){
props10 = true;
}
}
const _errs241 = errors;
if(errors === _errs241){
if(data61 && typeof data61 == "object" && !Array.isArray(data61)){
let missing41;
if((data61.renewal === undefined) && (missing41 = "renewal")){
const err146 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/11/required",keyword:"required",params:{missingProperty: missing41},message:"must have required property '"+missing41+"'"};
if(vErrors === null){
vErrors = [err146];
}
else {
vErrors.push(err146);
}
errors++;
}
else {
const _errs243 = errors;
for(const key41 in data61){
if(!(key41 === "renewal")){
const err147 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/11/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key41},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err147];
}
else {
vErrors.push(err147);
}
errors++;
break;
}
}
if(_errs243 === errors){
if(data61.renewal !== undefined){
let data106 = data61.renewal;
const _errs244 = errors;
if(errors === _errs244){
if(data106 && typeof data106 == "object" && !Array.isArray(data106)){
let missing42;
if((((data106.expected === undefined) && (missing42 = "expected")) || ((data106.actual === undefined) && (missing42 = "actual"))) || ((data106.proposed === undefined) && (missing42 = "proposed"))){
const err148 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/renewal",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/11/properties/renewal/required",keyword:"required",params:{missingProperty: missing42},message:"must have required property '"+missing42+"'"};
if(vErrors === null){
vErrors = [err148];
}
else {
vErrors.push(err148);
}
errors++;
}
else {
const _errs246 = errors;
for(const key42 in data106){
if(!(((key42 === "expected") || (key42 === "actual")) || (key42 === "proposed"))){
const err149 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/renewal",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/11/properties/renewal/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key42},message:"must NOT have additional properties"};
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
if(_errs246 === errors){
if(data106.expected !== undefined){
const _errs247 = errors;
if(!(validate119(data106.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/renewal/expected",parentData:data106,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid48 = _errs247 === errors;
}
else {
var valid48 = true;
}
if(valid48){
if(data106.actual !== undefined){
const _errs248 = errors;
if(!(validate119(data106.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/renewal/actual",parentData:data106,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid48 = _errs248 === errors;
}
else {
var valid48 = true;
}
if(valid48){
if(data106.proposed !== undefined){
const _errs249 = errors;
if(!(validate119(data106.proposed, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/renewal/proposed",parentData:data106,parentDataProperty:"proposed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid48 = _errs249 === errors;
}
else {
var valid48 = true;
}
}
}
}
}
}
else {
const err150 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/renewal",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/11/properties/renewal/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err151 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/11/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err151];
}
else {
vErrors.push(err151);
}
errors++;
}
}
var _valid5 = _errs241 === errors;
if(_valid5 && valid28){
valid28 = false;
passing3 = [passing3, 11];
}
else {
if(_valid5){
valid28 = true;
passing3 = 11;
if(props10 !== true){
props10 = true;
}
}
const _errs250 = errors;
if(errors === _errs250){
if(data61 && typeof data61 == "object" && !Array.isArray(data61)){
let missing43;
if((data61.binding === undefined) && (missing43 = "binding")){
const err152 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/12/required",keyword:"required",params:{missingProperty: missing43},message:"must have required property '"+missing43+"'"};
if(vErrors === null){
vErrors = [err152];
}
else {
vErrors.push(err152);
}
errors++;
}
else {
const _errs252 = errors;
for(const key43 in data61){
if(!(key43 === "binding")){
const err153 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/12/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key43},message:"must NOT have additional properties"};
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
if(_errs252 === errors){
if(data61.binding !== undefined){
let data110 = data61.binding;
const _errs253 = errors;
if(errors === _errs253){
if(data110 && typeof data110 == "object" && !Array.isArray(data110)){
let missing44;
if((((((((data110.expected === undefined) && (missing44 = "expected")) || ((data110.actual === undefined) && (missing44 = "actual"))) || ((data110.expected_codec === undefined) && (missing44 = "expected_codec"))) || ((data110.actual_codec === undefined) && (missing44 = "actual_codec"))) || ((data110.target === undefined) && (missing44 = "target"))) || ((data110.present === undefined) && (missing44 = "present"))) || ((data110.published === undefined) && (missing44 = "published"))){
const err154 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/binding",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/12/properties/binding/required",keyword:"required",params:{missingProperty: missing44},message:"must have required property '"+missing44+"'"};
if(vErrors === null){
vErrors = [err154];
}
else {
vErrors.push(err154);
}
errors++;
}
else {
const _errs255 = errors;
for(const key44 in data110){
if(!(((((((key44 === "expected") || (key44 === "actual")) || (key44 === "expected_codec")) || (key44 === "actual_codec")) || (key44 === "target")) || (key44 === "present")) || (key44 === "published"))){
const err155 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/binding",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/12/properties/binding/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key44},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err155];
}
else {
vErrors.push(err155);
}
errors++;
break;
}
}
if(_errs255 === errors){
if(data110.expected !== undefined){
const _errs256 = errors;
if(!(validate119(data110.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/binding/expected",parentData:data110,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid50 = _errs256 === errors;
}
else {
var valid50 = true;
}
if(valid50){
if(data110.actual !== undefined){
const _errs257 = errors;
if(!(validate119(data110.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/binding/actual",parentData:data110,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid50 = _errs257 === errors;
}
else {
var valid50 = true;
}
if(valid50){
if(data110.expected_codec !== undefined){
const _errs258 = errors;
if(!(validate162(data110.expected_codec, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/binding/expected_codec",parentData:data110,parentDataProperty:"expected_codec",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate162.errors : vErrors.concat(validate162.errors);
errors = vErrors.length;
}
var valid50 = _errs258 === errors;
}
else {
var valid50 = true;
}
if(valid50){
if(data110.actual_codec !== undefined){
const _errs259 = errors;
if(!(validate162(data110.actual_codec, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/binding/actual_codec",parentData:data110,parentDataProperty:"actual_codec",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate162.errors : vErrors.concat(validate162.errors);
errors = vErrors.length;
}
var valid50 = _errs259 === errors;
}
else {
var valid50 = true;
}
if(valid50){
if(data110.target !== undefined){
const _errs260 = errors;
if(!(validate119(data110.target, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/binding/target",parentData:data110,parentDataProperty:"target",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid50 = _errs260 === errors;
}
else {
var valid50 = true;
}
if(valid50){
if(data110.present !== undefined){
const _errs261 = errors;
if(typeof data110.present !== "boolean"){
const err156 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/binding/present",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/12/properties/binding/properties/present/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err156];
}
else {
vErrors.push(err156);
}
errors++;
}
var valid50 = _errs261 === errors;
}
else {
var valid50 = true;
}
if(valid50){
if(data110.published !== undefined){
const _errs263 = errors;
if(typeof data110.published !== "boolean"){
const err157 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/binding/published",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/12/properties/binding/properties/published/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err157];
}
else {
vErrors.push(err157);
}
errors++;
}
var valid50 = _errs263 === errors;
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
}
}
else {
const err158 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/binding",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/12/properties/binding/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err159 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/12/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err159];
}
else {
vErrors.push(err159);
}
errors++;
}
}
var _valid5 = _errs250 === errors;
if(_valid5 && valid28){
valid28 = false;
passing3 = [passing3, 12];
}
else {
if(_valid5){
valid28 = true;
passing3 = 12;
if(props10 !== true){
props10 = true;
}
}
const _errs265 = errors;
if(errors === _errs265){
if(data61 && typeof data61 == "object" && !Array.isArray(data61)){
let missing45;
if((data61.refresh === undefined) && (missing45 = "refresh")){
const err160 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/13/required",keyword:"required",params:{missingProperty: missing45},message:"must have required property '"+missing45+"'"};
if(vErrors === null){
vErrors = [err160];
}
else {
vErrors.push(err160);
}
errors++;
}
else {
const _errs267 = errors;
for(const key45 in data61){
if(!(key45 === "refresh")){
const err161 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/13/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key45},message:"must NOT have additional properties"};
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
if(_errs267 === errors){
if(data61.refresh !== undefined){
let data118 = data61.refresh;
const _errs268 = errors;
if(errors === _errs268){
if(data118 && typeof data118 == "object" && !Array.isArray(data118)){
let missing46;
if((((data118.expected === undefined) && (missing46 = "expected")) || ((data118.actual === undefined) && (missing46 = "actual"))) || ((data118.phase === undefined) && (missing46 = "phase"))){
const err162 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/refresh",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/13/properties/refresh/required",keyword:"required",params:{missingProperty: missing46},message:"must have required property '"+missing46+"'"};
if(vErrors === null){
vErrors = [err162];
}
else {
vErrors.push(err162);
}
errors++;
}
else {
const _errs270 = errors;
for(const key46 in data118){
if(!(((key46 === "expected") || (key46 === "actual")) || (key46 === "phase"))){
const err163 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/refresh",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/13/properties/refresh/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key46},message:"must NOT have additional properties"};
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
if(_errs270 === errors){
if(data118.expected !== undefined){
const _errs271 = errors;
if(!(validate254(data118.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/refresh/expected",parentData:data118,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate254.errors : vErrors.concat(validate254.errors);
errors = vErrors.length;
}
var valid52 = _errs271 === errors;
}
else {
var valid52 = true;
}
if(valid52){
if(data118.actual !== undefined){
const _errs272 = errors;
if(!(validate254(data118.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/refresh/actual",parentData:data118,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate254.errors : vErrors.concat(validate254.errors);
errors = vErrors.length;
}
var valid52 = _errs272 === errors;
}
else {
var valid52 = true;
}
if(valid52){
if(data118.phase !== undefined){
const _errs273 = errors;
if(!(validate517(data118.phase, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/refresh/phase",parentData:data118,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate517.errors : vErrors.concat(validate517.errors);
errors = vErrors.length;
}
var valid52 = _errs273 === errors;
}
else {
var valid52 = true;
}
}
}
}
}
}
else {
const err164 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/refresh",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/13/properties/refresh/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err164];
}
else {
vErrors.push(err164);
}
errors++;
}
}
}
}
}
}
else {
const err165 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/13/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err165];
}
else {
vErrors.push(err165);
}
errors++;
}
}
var _valid5 = _errs265 === errors;
if(_valid5 && valid28){
valid28 = false;
passing3 = [passing3, 13];
}
else {
if(_valid5){
valid28 = true;
passing3 = 13;
if(props10 !== true){
props10 = true;
}
}
const _errs274 = errors;
if(errors === _errs274){
if(data61 && typeof data61 == "object" && !Array.isArray(data61)){
let missing47;
if((data61.frame === undefined) && (missing47 = "frame")){
const err166 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/14/required",keyword:"required",params:{missingProperty: missing47},message:"must have required property '"+missing47+"'"};
if(vErrors === null){
vErrors = [err166];
}
else {
vErrors.push(err166);
}
errors++;
}
else {
const _errs276 = errors;
for(const key47 in data61){
if(!(key47 === "frame")){
const err167 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/14/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key47},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err167];
}
else {
vErrors.push(err167);
}
errors++;
break;
}
}
if(_errs276 === errors){
if(data61.frame !== undefined){
let data122 = data61.frame;
const _errs277 = errors;
if(errors === _errs277){
if(data122 && typeof data122 == "object" && !Array.isArray(data122)){
let missing48;
if(((((data122.correlation === undefined) && (missing48 = "correlation")) || ((data122.expected === undefined) && (missing48 = "expected"))) || ((data122.actual === undefined) && (missing48 = "actual"))) || ((data122.kind === undefined) && (missing48 = "kind"))){
const err168 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/frame",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/14/properties/frame/required",keyword:"required",params:{missingProperty: missing48},message:"must have required property '"+missing48+"'"};
if(vErrors === null){
vErrors = [err168];
}
else {
vErrors.push(err168);
}
errors++;
}
else {
const _errs279 = errors;
for(const key48 in data122){
if(!(((((key48 === "correlation") || (key48 === "expected")) || (key48 === "actual")) || (key48 === "kind")) || (key48 === "actual_known"))){
const err169 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/frame",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/14/properties/frame/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key48},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err169];
}
else {
vErrors.push(err169);
}
errors++;
break;
}
}
if(_errs279 === errors){
if(data122.correlation !== undefined){
const _errs280 = errors;
if(!(validate119(data122.correlation, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/frame/correlation",parentData:data122,parentDataProperty:"correlation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid54 = _errs280 === errors;
}
else {
var valid54 = true;
}
if(valid54){
if(data122.expected !== undefined){
const _errs281 = errors;
if(!(validate119(data122.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/frame/expected",parentData:data122,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid54 = _errs281 === errors;
}
else {
var valid54 = true;
}
if(valid54){
if(data122.actual !== undefined){
const _errs282 = errors;
if(!(validate119(data122.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/frame/actual",parentData:data122,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid54 = _errs282 === errors;
}
else {
var valid54 = true;
}
if(valid54){
if(data122.kind !== undefined){
let data126 = data122.kind;
const _errs283 = errors;
if(typeof data126 !== "string"){
const err170 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/frame/kind",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/14/properties/frame/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err170];
}
else {
vErrors.push(err170);
}
errors++;
}
if(!((((data126 === "reply_source") || (data126 === "observer")) || (data126 === "timer")) || (data126 === "administrator"))){
const err171 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/frame/kind",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/14/properties/frame/properties/kind/enum",keyword:"enum",params:{allowedValues: schema111.oneOf[8].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[14].properties.frame.properties.kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err171];
}
else {
vErrors.push(err171);
}
errors++;
}
var valid54 = _errs283 === errors;
}
else {
var valid54 = true;
}
if(valid54){
if(data122.actual_known !== undefined){
const _errs285 = errors;
if(typeof data122.actual_known !== "boolean"){
const err172 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/frame/actual_known",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/14/properties/frame/properties/actual_known/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err172];
}
else {
vErrors.push(err172);
}
errors++;
}
var valid54 = _errs285 === errors;
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
}
else {
const err173 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/frame",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/14/properties/frame/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err174 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/14/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err174];
}
else {
vErrors.push(err174);
}
errors++;
}
}
var _valid5 = _errs274 === errors;
if(_valid5 && valid28){
valid28 = false;
passing3 = [passing3, 14];
}
else {
if(_valid5){
valid28 = true;
passing3 = 14;
if(props10 !== true){
props10 = true;
}
}
const _errs287 = errors;
if(errors === _errs287){
if(data61 && typeof data61 == "object" && !Array.isArray(data61)){
let missing49;
if((data61.target === undefined) && (missing49 = "target")){
const err175 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/15/required",keyword:"required",params:{missingProperty: missing49},message:"must have required property '"+missing49+"'"};
if(vErrors === null){
vErrors = [err175];
}
else {
vErrors.push(err175);
}
errors++;
}
else {
const _errs289 = errors;
for(const key49 in data61){
if(!(key49 === "target")){
const err176 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/15/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key49},message:"must NOT have additional properties"};
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
if(_errs289 === errors){
if(data61.target !== undefined){
let data128 = data61.target;
const _errs290 = errors;
if(errors === _errs290){
if(data128 && typeof data128 == "object" && !Array.isArray(data128)){
let missing50;
if((((data128.expected === undefined) && (missing50 = "expected")) || ((data128.actual === undefined) && (missing50 = "actual"))) || ((data128.kind === undefined) && (missing50 = "kind"))){
const err177 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/target",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/15/properties/target/required",keyword:"required",params:{missingProperty: missing50},message:"must have required property '"+missing50+"'"};
if(vErrors === null){
vErrors = [err177];
}
else {
vErrors.push(err177);
}
errors++;
}
else {
const _errs292 = errors;
for(const key50 in data128){
if(!(((key50 === "expected") || (key50 === "actual")) || (key50 === "kind"))){
const err178 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/target",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/15/properties/target/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key50},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err178];
}
else {
vErrors.push(err178);
}
errors++;
break;
}
}
if(_errs292 === errors){
if(data128.expected !== undefined){
const _errs293 = errors;
if(!(validate119(data128.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/target/expected",parentData:data128,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid56 = _errs293 === errors;
}
else {
var valid56 = true;
}
if(valid56){
if(data128.actual !== undefined){
const _errs294 = errors;
if(!(validate119(data128.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/target/actual",parentData:data128,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid56 = _errs294 === errors;
}
else {
var valid56 = true;
}
if(valid56){
if(data128.kind !== undefined){
let data131 = data128.kind;
const _errs295 = errors;
if(typeof data131 !== "string"){
const err179 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/target/kind",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/15/properties/target/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err179];
}
else {
vErrors.push(err179);
}
errors++;
}
if(!((data131 === "source") || (data131 === "resource"))){
const err180 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/target/kind",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/15/properties/target/properties/kind/enum",keyword:"enum",params:{allowedValues: schema111.oneOf[8].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[15].properties.target.properties.kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err180];
}
else {
vErrors.push(err180);
}
errors++;
}
var valid56 = _errs295 === errors;
}
else {
var valid56 = true;
}
}
}
}
}
}
else {
const err181 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/target",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/15/properties/target/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err181];
}
else {
vErrors.push(err181);
}
errors++;
}
}
}
}
}
}
else {
const err182 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/15/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err182];
}
else {
vErrors.push(err182);
}
errors++;
}
}
var _valid5 = _errs287 === errors;
if(_valid5 && valid28){
valid28 = false;
passing3 = [passing3, 15];
}
else {
if(_valid5){
valid28 = true;
passing3 = 15;
if(props10 !== true){
props10 = true;
}
}
const _errs297 = errors;
if(errors === _errs297){
if(data61 && typeof data61 == "object" && !Array.isArray(data61)){
let missing51;
if((data61.basis === undefined) && (missing51 = "basis")){
const err183 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/16/required",keyword:"required",params:{missingProperty: missing51},message:"must have required property '"+missing51+"'"};
if(vErrors === null){
vErrors = [err183];
}
else {
vErrors.push(err183);
}
errors++;
}
else {
const _errs299 = errors;
for(const key51 in data61){
if(!(key51 === "basis")){
const err184 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/16/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key51},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err184];
}
else {
vErrors.push(err184);
}
errors++;
break;
}
}
if(_errs299 === errors){
if(data61.basis !== undefined){
let data132 = data61.basis;
const _errs300 = errors;
if(errors === _errs300){
if(data132 && typeof data132 == "object" && !Array.isArray(data132)){
let missing52;
if((((data132.expected === undefined) && (missing52 = "expected")) || ((data132.actual === undefined) && (missing52 = "actual"))) || ((data132.kind === undefined) && (missing52 = "kind"))){
const err185 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/basis",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/16/properties/basis/required",keyword:"required",params:{missingProperty: missing52},message:"must have required property '"+missing52+"'"};
if(vErrors === null){
vErrors = [err185];
}
else {
vErrors.push(err185);
}
errors++;
}
else {
const _errs302 = errors;
for(const key52 in data132){
if(!(((key52 === "expected") || (key52 === "actual")) || (key52 === "kind"))){
const err186 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/basis",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/16/properties/basis/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key52},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err186];
}
else {
vErrors.push(err186);
}
errors++;
break;
}
}
if(_errs302 === errors){
if(data132.expected !== undefined){
const _errs303 = errors;
if(!(validate107(data132.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/basis/expected",parentData:data132,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate107.errors : vErrors.concat(validate107.errors);
errors = vErrors.length;
}
var valid58 = _errs303 === errors;
}
else {
var valid58 = true;
}
if(valid58){
if(data132.actual !== undefined){
const _errs304 = errors;
if(!(validate107(data132.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/basis/actual",parentData:data132,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate107.errors : vErrors.concat(validate107.errors);
errors = vErrors.length;
}
var valid58 = _errs304 === errors;
}
else {
var valid58 = true;
}
if(valid58){
if(data132.kind !== undefined){
let data135 = data132.kind;
const _errs305 = errors;
if(typeof data135 !== "string"){
const err187 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/basis/kind",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/16/properties/basis/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err187];
}
else {
vErrors.push(err187);
}
errors++;
}
if(!(((data135 === "schema") || (data135 === "contract")) || (data135 === "metadata"))){
const err188 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/basis/kind",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/16/properties/basis/properties/kind/enum",keyword:"enum",params:{allowedValues: schema111.oneOf[8].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[16].properties.basis.properties.kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err188];
}
else {
vErrors.push(err188);
}
errors++;
}
var valid58 = _errs305 === errors;
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
const err189 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/basis",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/16/properties/basis/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err189];
}
else {
vErrors.push(err189);
}
errors++;
}
}
}
}
}
}
else {
const err190 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/16/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err190];
}
else {
vErrors.push(err190);
}
errors++;
}
}
var _valid5 = _errs297 === errors;
if(_valid5 && valid28){
valid28 = false;
passing3 = [passing3, 16];
}
else {
if(_valid5){
valid28 = true;
passing3 = 16;
if(props10 !== true){
props10 = true;
}
}
const _errs307 = errors;
if(errors === _errs307){
if(data61 && typeof data61 == "object" && !Array.isArray(data61)){
let missing53;
if((data61.source_kind === undefined) && (missing53 = "source_kind")){
const err191 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/17/required",keyword:"required",params:{missingProperty: missing53},message:"must have required property '"+missing53+"'"};
if(vErrors === null){
vErrors = [err191];
}
else {
vErrors.push(err191);
}
errors++;
}
else {
const _errs309 = errors;
for(const key53 in data61){
if(!(key53 === "source_kind")){
const err192 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/17/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key53},message:"must NOT have additional properties"};
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
if(_errs309 === errors){
if(data61.source_kind !== undefined){
let data136 = data61.source_kind;
const _errs310 = errors;
if(errors === _errs310){
if(data136 && typeof data136 == "object" && !Array.isArray(data136)){
let missing54;
if(((data136.expected === undefined) && (missing54 = "expected")) || ((data136.actual === undefined) && (missing54 = "actual"))){
const err193 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source_kind",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/17/properties/source_kind/required",keyword:"required",params:{missingProperty: missing54},message:"must have required property '"+missing54+"'"};
if(vErrors === null){
vErrors = [err193];
}
else {
vErrors.push(err193);
}
errors++;
}
else {
const _errs312 = errors;
for(const key54 in data136){
if(!((key54 === "expected") || (key54 === "actual"))){
const err194 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source_kind",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/17/properties/source_kind/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key54},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err194];
}
else {
vErrors.push(err194);
}
errors++;
break;
}
}
if(_errs312 === errors){
if(data136.expected !== undefined){
const _errs313 = errors;
if(!(validate269(data136.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source_kind/expected",parentData:data136,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate269.errors : vErrors.concat(validate269.errors);
errors = vErrors.length;
}
var valid60 = _errs313 === errors;
}
else {
var valid60 = true;
}
if(valid60){
if(data136.actual !== undefined){
const _errs314 = errors;
if(!(validate269(data136.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source_kind/actual",parentData:data136,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate269.errors : vErrors.concat(validate269.errors);
errors = vErrors.length;
}
var valid60 = _errs314 === errors;
}
else {
var valid60 = true;
}
}
}
}
}
else {
const err195 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source_kind",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/17/properties/source_kind/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err195];
}
else {
vErrors.push(err195);
}
errors++;
}
}
}
}
}
}
else {
const err196 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/17/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err196];
}
else {
vErrors.push(err196);
}
errors++;
}
}
var _valid5 = _errs307 === errors;
if(_valid5 && valid28){
valid28 = false;
passing3 = [passing3, 17];
}
else {
if(_valid5){
valid28 = true;
passing3 = 17;
if(props10 !== true){
props10 = true;
}
}
const _errs315 = errors;
if(errors === _errs315){
if(data61 && typeof data61 == "object" && !Array.isArray(data61)){
let missing55;
if((data61.table === undefined) && (missing55 = "table")){
const err197 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/18/required",keyword:"required",params:{missingProperty: missing55},message:"must have required property '"+missing55+"'"};
if(vErrors === null){
vErrors = [err197];
}
else {
vErrors.push(err197);
}
errors++;
}
else {
const _errs317 = errors;
for(const key55 in data61){
if(!(key55 === "table")){
const err198 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/18/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key55},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err198];
}
else {
vErrors.push(err198);
}
errors++;
break;
}
}
if(_errs317 === errors){
if(data61.table !== undefined){
if(!(validate254(data61.table, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/table",parentData:data61,parentDataProperty:"table",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate254.errors : vErrors.concat(validate254.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err199 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/18/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err199];
}
else {
vErrors.push(err199);
}
errors++;
}
}
var _valid5 = _errs315 === errors;
if(_valid5 && valid28){
valid28 = false;
passing3 = [passing3, 18];
}
else {
if(_valid5){
valid28 = true;
passing3 = 18;
if(props10 !== true){
props10 = true;
}
}
const _errs319 = errors;
if(errors === _errs319){
if(data61 && typeof data61 == "object" && !Array.isArray(data61)){
let missing56;
if((data61.watch_type === undefined) && (missing56 = "watch_type")){
const err200 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/19/required",keyword:"required",params:{missingProperty: missing56},message:"must have required property '"+missing56+"'"};
if(vErrors === null){
vErrors = [err200];
}
else {
vErrors.push(err200);
}
errors++;
}
else {
const _errs321 = errors;
for(const key56 in data61){
if(!(key56 === "watch_type")){
const err201 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/19/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key56},message:"must NOT have additional properties"};
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
if(_errs321 === errors){
if(data61.watch_type !== undefined){
let data140 = data61.watch_type;
const _errs322 = errors;
if(errors === _errs322){
if(data140 && typeof data140 == "object" && !Array.isArray(data140)){
let missing57;
if(((data140.expected === undefined) && (missing57 = "expected")) || ((data140.actual === undefined) && (missing57 = "actual"))){
const err202 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_type",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/19/properties/watch_type/required",keyword:"required",params:{missingProperty: missing57},message:"must have required property '"+missing57+"'"};
if(vErrors === null){
vErrors = [err202];
}
else {
vErrors.push(err202);
}
errors++;
}
else {
const _errs324 = errors;
for(const key57 in data140){
if(!(((key57 === "expected") || (key57 === "actual")) || (key57 === "column"))){
const err203 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_type",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/19/properties/watch_type/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key57},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err203];
}
else {
vErrors.push(err203);
}
errors++;
break;
}
}
if(_errs324 === errors){
if(data140.expected !== undefined){
const _errs325 = errors;
if(!(validate573(data140.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_type/expected",parentData:data140,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate573.errors : vErrors.concat(validate573.errors);
errors = vErrors.length;
}
var valid63 = _errs325 === errors;
}
else {
var valid63 = true;
}
if(valid63){
if(data140.actual !== undefined){
const _errs326 = errors;
if(!(validate573(data140.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_type/actual",parentData:data140,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate573.errors : vErrors.concat(validate573.errors);
errors = vErrors.length;
}
var valid63 = _errs326 === errors;
}
else {
var valid63 = true;
}
if(valid63){
if(data140.column !== undefined){
const _errs327 = errors;
if(!(validate108(data140.column, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_type/column",parentData:data140,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate108.errors : vErrors.concat(validate108.errors);
errors = vErrors.length;
}
var valid63 = _errs327 === errors;
}
else {
var valid63 = true;
}
}
}
}
}
}
else {
const err204 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_type",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/19/properties/watch_type/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err204];
}
else {
vErrors.push(err204);
}
errors++;
}
}
}
}
}
}
else {
const err205 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/19/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err205];
}
else {
vErrors.push(err205);
}
errors++;
}
}
var _valid5 = _errs319 === errors;
if(_valid5 && valid28){
valid28 = false;
passing3 = [passing3, 19];
}
else {
if(_valid5){
valid28 = true;
passing3 = 19;
if(props10 !== true){
props10 = true;
}
}
const _errs328 = errors;
if(errors === _errs328){
if(data61 && typeof data61 == "object" && !Array.isArray(data61)){
let missing58;
if((data61.progress === undefined) && (missing58 = "progress")){
const err206 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/20/required",keyword:"required",params:{missingProperty: missing58},message:"must have required property '"+missing58+"'"};
if(vErrors === null){
vErrors = [err206];
}
else {
vErrors.push(err206);
}
errors++;
}
else {
const _errs330 = errors;
for(const key58 in data61){
if(!(key58 === "progress")){
const err207 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/20/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key58},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err207];
}
else {
vErrors.push(err207);
}
errors++;
break;
}
}
if(_errs330 === errors){
if(data61.progress !== undefined){
let data144 = data61.progress;
const _errs331 = errors;
if(errors === _errs331){
if(data144 && typeof data144 == "object" && !Array.isArray(data144)){
let missing59;
if((((((data144.present === undefined) && (missing59 = "present")) || ((data144.actual === undefined) && (missing59 = "actual"))) || ((data144.limit === undefined) && (missing59 = "limit"))) || ((data144.key === undefined) && (missing59 = "key"))) || ((data144.length === undefined) && (missing59 = "length"))){
const err208 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/progress",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/20/properties/progress/required",keyword:"required",params:{missingProperty: missing59},message:"must have required property '"+missing59+"'"};
if(vErrors === null){
vErrors = [err208];
}
else {
vErrors.push(err208);
}
errors++;
}
else {
const _errs333 = errors;
for(const key59 in data144){
if(!(((((key59 === "present") || (key59 === "actual")) || (key59 === "limit")) || (key59 === "key")) || (key59 === "length"))){
const err209 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/progress",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/20/properties/progress/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key59},message:"must NOT have additional properties"};
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
if(_errs333 === errors){
if(data144.present !== undefined){
const _errs334 = errors;
if(typeof data144.present !== "boolean"){
const err210 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/progress/present",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/20/properties/progress/properties/present/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err210];
}
else {
vErrors.push(err210);
}
errors++;
}
var valid65 = _errs334 === errors;
}
else {
var valid65 = true;
}
if(valid65){
if(data144.actual !== undefined){
const _errs336 = errors;
if(!(validate119(data144.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/progress/actual",parentData:data144,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid65 = _errs336 === errors;
}
else {
var valid65 = true;
}
if(valid65){
if(data144.limit !== undefined){
const _errs337 = errors;
if(!(validate119(data144.limit, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/progress/limit",parentData:data144,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid65 = _errs337 === errors;
}
else {
var valid65 = true;
}
if(valid65){
if(data144.key !== undefined){
const _errs338 = errors;
if(!(validate107(data144.key, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/progress/key",parentData:data144,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate107.errors : vErrors.concat(validate107.errors);
errors = vErrors.length;
}
var valid65 = _errs338 === errors;
}
else {
var valid65 = true;
}
if(valid65){
if(data144.length !== undefined){
const _errs339 = errors;
if(!(validate108(data144.length, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/progress/length",parentData:data144,parentDataProperty:"length",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate108.errors : vErrors.concat(validate108.errors);
errors = vErrors.length;
}
var valid65 = _errs339 === errors;
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
else {
const err211 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/progress",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/20/properties/progress/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err211];
}
else {
vErrors.push(err211);
}
errors++;
}
}
}
}
}
}
else {
const err212 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/20/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err212];
}
else {
vErrors.push(err212);
}
errors++;
}
}
var _valid5 = _errs328 === errors;
if(_valid5 && valid28){
valid28 = false;
passing3 = [passing3, 20];
}
else {
if(_valid5){
valid28 = true;
passing3 = 20;
if(props10 !== true){
props10 = true;
}
}
const _errs340 = errors;
if(errors === _errs340){
if(data61 && typeof data61 == "object" && !Array.isArray(data61)){
let missing60;
if((data61.reader_identity === undefined) && (missing60 = "reader_identity")){
const err213 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/21/required",keyword:"required",params:{missingProperty: missing60},message:"must have required property '"+missing60+"'"};
if(vErrors === null){
vErrors = [err213];
}
else {
vErrors.push(err213);
}
errors++;
}
else {
const _errs342 = errors;
for(const key60 in data61){
if(!(key60 === "reader_identity")){
const err214 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/21/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key60},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err214];
}
else {
vErrors.push(err214);
}
errors++;
break;
}
}
if(_errs342 === errors){
if(data61.reader_identity !== undefined){
let data150 = data61.reader_identity;
const _errs343 = errors;
if(errors === _errs343){
if(data150 && typeof data150 == "object" && !Array.isArray(data150)){
let missing61;
if((((data150.field === undefined) && (missing61 = "field")) || ((data150.expected === undefined) && (missing61 = "expected"))) || ((data150.actual === undefined) && (missing61 = "actual"))){
const err215 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_identity",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/21/properties/reader_identity/required",keyword:"required",params:{missingProperty: missing61},message:"must have required property '"+missing61+"'"};
if(vErrors === null){
vErrors = [err215];
}
else {
vErrors.push(err215);
}
errors++;
}
else {
const _errs345 = errors;
for(const key61 in data150){
if(!((((((key61 === "field") || (key61 === "expected")) || (key61 === "actual")) || (key61 === "present")) || (key61 === "policy_revision")) || (key61 === "policy_known"))){
const err216 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_identity",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/21/properties/reader_identity/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key61},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err216];
}
else {
vErrors.push(err216);
}
errors++;
break;
}
}
if(_errs345 === errors){
if(data150.field !== undefined){
let data151 = data150.field;
const _errs346 = errors;
if(typeof data151 !== "string"){
const err217 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_identity/field",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/21/properties/reader_identity/properties/field/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err217];
}
else {
vErrors.push(err217);
}
errors++;
}
if(!((((data151 === "principal") || (data151 === "pid")) || (data151 === "permissions")) || (data151 === "turn_pid"))){
const err218 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_identity/field",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/21/properties/reader_identity/properties/field/enum",keyword:"enum",params:{allowedValues: schema111.oneOf[8].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[21].properties.reader_identity.properties.field.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err218];
}
else {
vErrors.push(err218);
}
errors++;
}
var valid67 = _errs346 === errors;
}
else {
var valid67 = true;
}
if(valid67){
if(data150.expected !== undefined){
const _errs348 = errors;
if(!(validate119(data150.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_identity/expected",parentData:data150,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid67 = _errs348 === errors;
}
else {
var valid67 = true;
}
if(valid67){
if(data150.actual !== undefined){
const _errs349 = errors;
if(!(validate119(data150.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_identity/actual",parentData:data150,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid67 = _errs349 === errors;
}
else {
var valid67 = true;
}
if(valid67){
if(data150.present !== undefined){
const _errs350 = errors;
if(typeof data150.present !== "boolean"){
const err219 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_identity/present",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/21/properties/reader_identity/properties/present/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err219];
}
else {
vErrors.push(err219);
}
errors++;
}
var valid67 = _errs350 === errors;
}
else {
var valid67 = true;
}
if(valid67){
if(data150.policy_revision !== undefined){
const _errs352 = errors;
if(!(validate119(data150.policy_revision, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_identity/policy_revision",parentData:data150,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid67 = _errs352 === errors;
}
else {
var valid67 = true;
}
if(valid67){
if(data150.policy_known !== undefined){
const _errs353 = errors;
if(typeof data150.policy_known !== "boolean"){
const err220 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_identity/policy_known",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/21/properties/reader_identity/properties/policy_known/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err220];
}
else {
vErrors.push(err220);
}
errors++;
}
var valid67 = _errs353 === errors;
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
}
else {
const err221 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_identity",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/21/properties/reader_identity/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err221];
}
else {
vErrors.push(err221);
}
errors++;
}
}
}
}
}
}
else {
const err222 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/21/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err222];
}
else {
vErrors.push(err222);
}
errors++;
}
}
var _valid5 = _errs340 === errors;
if(_valid5 && valid28){
valid28 = false;
passing3 = [passing3, 21];
}
else {
if(_valid5){
valid28 = true;
passing3 = 21;
if(props10 !== true){
props10 = true;
}
}
const _errs355 = errors;
if(errors === _errs355){
if(data61 && typeof data61 == "object" && !Array.isArray(data61)){
let missing62;
if((data61.reader_failure === undefined) && (missing62 = "reader_failure")){
const err223 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/22/required",keyword:"required",params:{missingProperty: missing62},message:"must have required property '"+missing62+"'"};
if(vErrors === null){
vErrors = [err223];
}
else {
vErrors.push(err223);
}
errors++;
}
else {
const _errs357 = errors;
for(const key62 in data61){
if(!(key62 === "reader_failure")){
const err224 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/22/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key62},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err224];
}
else {
vErrors.push(err224);
}
errors++;
break;
}
}
if(_errs357 === errors){
if(data61.reader_failure !== undefined){
let data157 = data61.reader_failure;
const _errs358 = errors;
if(errors === _errs358){
if(data157 && typeof data157 == "object" && !Array.isArray(data157)){
let missing63;
if(((((data157.operation === undefined) && (missing63 = "operation")) || ((data157.principal === undefined) && (missing63 = "principal"))) || ((data157.resource === undefined) && (missing63 = "resource"))) || ((data157.cause === undefined) && (missing63 = "cause"))){
const err225 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_failure",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/22/properties/reader_failure/required",keyword:"required",params:{missingProperty: missing63},message:"must have required property '"+missing63+"'"};
if(vErrors === null){
vErrors = [err225];
}
else {
vErrors.push(err225);
}
errors++;
}
else {
const _errs360 = errors;
for(const key63 in data157){
if(!(((((key63 === "operation") || (key63 === "principal")) || (key63 === "resource")) || (key63 === "namespace")) || (key63 === "cause"))){
const err226 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_failure",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/22/properties/reader_failure/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key63},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err226];
}
else {
vErrors.push(err226);
}
errors++;
break;
}
}
if(_errs360 === errors){
if(data157.operation !== undefined){
let data158 = data157.operation;
const _errs361 = errors;
if(typeof data158 !== "string"){
const err227 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_failure/operation",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/22/properties/reader_failure/properties/operation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err227];
}
else {
vErrors.push(err227);
}
errors++;
}
if(!((((data158 === "identity") || (data158 === "source")) || (data158 === "requester")) || (data158 === "result"))){
const err228 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_failure/operation",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/22/properties/reader_failure/properties/operation/enum",keyword:"enum",params:{allowedValues: schema111.oneOf[8].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[22].properties.reader_failure.properties.operation.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err228];
}
else {
vErrors.push(err228);
}
errors++;
}
var valid69 = _errs361 === errors;
}
else {
var valid69 = true;
}
if(valid69){
if(data157.principal !== undefined){
const _errs363 = errors;
if(!(validate119(data157.principal, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_failure/principal",parentData:data157,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid69 = _errs363 === errors;
}
else {
var valid69 = true;
}
if(valid69){
if(data157.resource !== undefined){
const _errs364 = errors;
if(!(validate119(data157.resource, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_failure/resource",parentData:data157,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid69 = _errs364 === errors;
}
else {
var valid69 = true;
}
if(valid69){
if(data157.namespace !== undefined){
const _errs365 = errors;
if(!(validate119(data157.namespace, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_failure/namespace",parentData:data157,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid69 = _errs365 === errors;
}
else {
var valid69 = true;
}
if(valid69){
if(data157.cause !== undefined){
let data162 = data157.cause;
const _errs366 = errors;
if(typeof data162 !== "string"){
const err229 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_failure/cause",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/22/properties/reader_failure/properties/cause/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err229];
}
else {
vErrors.push(err229);
}
errors++;
}
if(!(((((((((((data162 === "AccessDenied") || (data162 === "Forbidden")) || (data162 === "StateResourceExpired")) || (data162 === "UnknownStateResource")) || (data162 === "DeadlineExpired")) || (data162 === "RetiredProcess")) || (data162 === "CatalogDenied")) || (data162 === "QueryDenied")) || (data162 === "QuerySourceUnavailable")) || (data162 === "ResultUnavailable")) || (data162 === "PublicationNotPublished"))){
const err230 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_failure/cause",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/22/properties/reader_failure/properties/cause/enum",keyword:"enum",params:{allowedValues: schema111.oneOf[8].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[22].properties.reader_failure.properties.cause.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err230];
}
else {
vErrors.push(err230);
}
errors++;
}
var valid69 = _errs366 === errors;
}
else {
var valid69 = true;
}
}
}
}
}
}
}
}
else {
const err231 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_failure",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/22/properties/reader_failure/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err231];
}
else {
vErrors.push(err231);
}
errors++;
}
}
}
}
}
}
else {
const err232 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/22/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err232];
}
else {
vErrors.push(err232);
}
errors++;
}
}
var _valid5 = _errs355 === errors;
if(_valid5 && valid28){
valid28 = false;
passing3 = [passing3, 22];
}
else {
if(_valid5){
valid28 = true;
passing3 = 22;
if(props10 !== true){
props10 = true;
}
}
const _errs368 = errors;
if(errors === _errs368){
if(data61 && typeof data61 == "object" && !Array.isArray(data61)){
let missing64;
if((data61.reader_resource === undefined) && (missing64 = "reader_resource")){
const err233 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/required",keyword:"required",params:{missingProperty: missing64},message:"must have required property '"+missing64+"'"};
if(vErrors === null){
vErrors = [err233];
}
else {
vErrors.push(err233);
}
errors++;
}
else {
const _errs370 = errors;
for(const key64 in data61){
if(!(key64 === "reader_resource")){
const err234 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key64},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err234];
}
else {
vErrors.push(err234);
}
errors++;
break;
}
}
if(_errs370 === errors){
if(data61.reader_resource !== undefined){
let data163 = data61.reader_resource;
const _errs371 = errors;
if(errors === _errs371){
if(data163 && typeof data163 == "object" && !Array.isArray(data163)){
let missing65;
if((((((((data163.role === undefined) && (missing65 = "role")) || ((data163.resource === undefined) && (missing65 = "resource"))) || ((data163.expected_writer === undefined) && (missing65 = "expected_writer"))) || ((data163.actual_writer === undefined) && (missing65 = "actual_writer"))) || ((data163.phase === undefined) && (missing65 = "phase"))) || ((data163.writer_check === undefined) && (missing65 = "writer_check"))) || ((data163.revision === undefined) && (missing65 = "revision"))){
const err235 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/properties/reader_resource/required",keyword:"required",params:{missingProperty: missing65},message:"must have required property '"+missing65+"'"};
if(vErrors === null){
vErrors = [err235];
}
else {
vErrors.push(err235);
}
errors++;
}
else {
const _errs373 = errors;
for(const key65 in data163){
if(!(((((((key65 === "role") || (key65 === "resource")) || (key65 === "expected_writer")) || (key65 === "actual_writer")) || (key65 === "phase")) || (key65 === "writer_check")) || (key65 === "revision"))){
const err236 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/properties/reader_resource/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key65},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err236];
}
else {
vErrors.push(err236);
}
errors++;
break;
}
}
if(_errs373 === errors){
if(data163.role !== undefined){
let data164 = data163.role;
const _errs374 = errors;
if(typeof data164 !== "string"){
const err237 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource/role",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/properties/reader_resource/properties/role/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err237];
}
else {
vErrors.push(err237);
}
errors++;
}
if(!((data164 === "source") || (data164 === "requester"))){
const err238 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource/role",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/properties/reader_resource/properties/role/enum",keyword:"enum",params:{allowedValues: schema111.oneOf[8].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[23].properties.reader_resource.properties.role.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err238];
}
else {
vErrors.push(err238);
}
errors++;
}
var valid71 = _errs374 === errors;
}
else {
var valid71 = true;
}
if(valid71){
if(data163.resource !== undefined){
const _errs376 = errors;
if(!(validate119(data163.resource, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource/resource",parentData:data163,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid71 = _errs376 === errors;
}
else {
var valid71 = true;
}
if(valid71){
if(data163.expected_writer !== undefined){
const _errs377 = errors;
if(!(validate119(data163.expected_writer, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource/expected_writer",parentData:data163,parentDataProperty:"expected_writer",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid71 = _errs377 === errors;
}
else {
var valid71 = true;
}
if(valid71){
if(data163.actual_writer !== undefined){
const _errs378 = errors;
if(!(validate119(data163.actual_writer, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource/actual_writer",parentData:data163,parentDataProperty:"actual_writer",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid71 = _errs378 === errors;
}
else {
var valid71 = true;
}
if(valid71){
if(data163.phase !== undefined){
let data168 = data163.phase;
const _errs379 = errors;
if(typeof data168 !== "string"){
const err239 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource/phase",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/properties/reader_resource/properties/phase/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err239];
}
else {
vErrors.push(err239);
}
errors++;
}
if(!(((data168 === "active") || (data168 === "retired")) || (data168 === "reclaimed"))){
const err240 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource/phase",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/properties/reader_resource/properties/phase/enum",keyword:"enum",params:{allowedValues: schema111.oneOf[8].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[23].properties.reader_resource.properties.phase.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err240];
}
else {
vErrors.push(err240);
}
errors++;
}
var valid71 = _errs379 === errors;
}
else {
var valid71 = true;
}
if(valid71){
if(data163.writer_check !== undefined){
const _errs381 = errors;
if(typeof data163.writer_check !== "boolean"){
const err241 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource/writer_check",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/properties/reader_resource/properties/writer_check/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err241];
}
else {
vErrors.push(err241);
}
errors++;
}
var valid71 = _errs381 === errors;
}
else {
var valid71 = true;
}
if(valid71){
if(data163.revision !== undefined){
const _errs383 = errors;
if(!(validate119(data163.revision, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource/revision",parentData:data163,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid71 = _errs383 === errors;
}
else {
var valid71 = true;
}
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
const err242 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/properties/reader_resource/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err243 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err243];
}
else {
vErrors.push(err243);
}
errors++;
}
}
var _valid5 = _errs368 === errors;
if(_valid5 && valid28){
valid28 = false;
passing3 = [passing3, 23];
}
else {
if(_valid5){
valid28 = true;
passing3 = 23;
if(props10 !== true){
props10 = true;
}
}
const _errs384 = errors;
if(errors === _errs384){
if(data61 && typeof data61 == "object" && !Array.isArray(data61)){
let missing66;
if((data61.watch_shape === undefined) && (missing66 = "watch_shape")){
const err244 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/24/required",keyword:"required",params:{missingProperty: missing66},message:"must have required property '"+missing66+"'"};
if(vErrors === null){
vErrors = [err244];
}
else {
vErrors.push(err244);
}
errors++;
}
else {
const _errs386 = errors;
for(const key66 in data61){
if(!(key66 === "watch_shape")){
const err245 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/24/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key66},message:"must NOT have additional properties"};
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
if(_errs386 === errors){
if(data61.watch_shape !== undefined){
let data171 = data61.watch_shape;
const _errs387 = errors;
if(errors === _errs387){
if(data171 && typeof data171 == "object" && !Array.isArray(data171)){
let missing67;
if(((((data171.columns === undefined) && (missing67 = "columns")) || ((data171.first_nullable === undefined) && (missing67 = "first_nullable"))) || ((data171.primary_columns === undefined) && (missing67 = "primary_columns"))) || ((data171.primary_first === undefined) && (missing67 = "primary_first"))){
const err246 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_shape",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/24/properties/watch_shape/required",keyword:"required",params:{missingProperty: missing67},message:"must have required property '"+missing67+"'"};
if(vErrors === null){
vErrors = [err246];
}
else {
vErrors.push(err246);
}
errors++;
}
else {
const _errs389 = errors;
for(const key67 in data171){
if(!((((key67 === "columns") || (key67 === "first_nullable")) || (key67 === "primary_columns")) || (key67 === "primary_first"))){
const err247 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_shape",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/24/properties/watch_shape/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key67},message:"must NOT have additional properties"};
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
if(_errs389 === errors){
if(data171.columns !== undefined){
const _errs390 = errors;
if(!(validate108(data171.columns, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_shape/columns",parentData:data171,parentDataProperty:"columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate108.errors : vErrors.concat(validate108.errors);
errors = vErrors.length;
}
var valid73 = _errs390 === errors;
}
else {
var valid73 = true;
}
if(valid73){
if(data171.first_nullable !== undefined){
const _errs391 = errors;
if(typeof data171.first_nullable !== "boolean"){
const err248 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_shape/first_nullable",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/24/properties/watch_shape/properties/first_nullable/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err248];
}
else {
vErrors.push(err248);
}
errors++;
}
var valid73 = _errs391 === errors;
}
else {
var valid73 = true;
}
if(valid73){
if(data171.primary_columns !== undefined){
const _errs393 = errors;
if(!(validate108(data171.primary_columns, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_shape/primary_columns",parentData:data171,parentDataProperty:"primary_columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate108.errors : vErrors.concat(validate108.errors);
errors = vErrors.length;
}
var valid73 = _errs393 === errors;
}
else {
var valid73 = true;
}
if(valid73){
if(data171.primary_first !== undefined){
const _errs394 = errors;
if(typeof data171.primary_first !== "boolean"){
const err249 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_shape/primary_first",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/24/properties/watch_shape/properties/primary_first/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err249];
}
else {
vErrors.push(err249);
}
errors++;
}
var valid73 = _errs394 === errors;
}
else {
var valid73 = true;
}
}
}
}
}
}
}
else {
const err250 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_shape",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/24/properties/watch_shape/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err251 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/24/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err251];
}
else {
vErrors.push(err251);
}
errors++;
}
}
var _valid5 = _errs384 === errors;
if(_valid5 && valid28){
valid28 = false;
passing3 = [passing3, 24];
}
else {
if(_valid5){
valid28 = true;
passing3 = 24;
if(props10 !== true){
props10 = true;
}
}
const _errs396 = errors;
if(errors === _errs396){
if(data61 && typeof data61 == "object" && !Array.isArray(data61)){
let missing68;
if((data61.reader_template === undefined) && (missing68 = "reader_template")){
const err252 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/25/required",keyword:"required",params:{missingProperty: missing68},message:"must have required property '"+missing68+"'"};
if(vErrors === null){
vErrors = [err252];
}
else {
vErrors.push(err252);
}
errors++;
}
else {
const _errs398 = errors;
for(const key68 in data61){
if(!(key68 === "reader_template")){
const err253 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/25/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key68},message:"must NOT have additional properties"};
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
if(_errs398 === errors){
if(data61.reader_template !== undefined){
let data176 = data61.reader_template;
const _errs399 = errors;
if(errors === _errs399){
if(data176 && typeof data176 == "object" && !Array.isArray(data176)){
let missing69;
if(((data176.namespace === undefined) && (missing69 = "namespace")) || ((data176.present === undefined) && (missing69 = "present"))){
const err254 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_template",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/25/properties/reader_template/required",keyword:"required",params:{missingProperty: missing69},message:"must have required property '"+missing69+"'"};
if(vErrors === null){
vErrors = [err254];
}
else {
vErrors.push(err254);
}
errors++;
}
else {
const _errs401 = errors;
for(const key69 in data176){
if(!((((key69 === "namespace") || (key69 === "present")) || (key69 === "phase")) || (key69 === "manifest"))){
const err255 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_template",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/25/properties/reader_template/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key69},message:"must NOT have additional properties"};
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
if(_errs401 === errors){
if(data176.namespace !== undefined){
const _errs402 = errors;
if(!(validate119(data176.namespace, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_template/namespace",parentData:data176,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid75 = _errs402 === errors;
}
else {
var valid75 = true;
}
if(valid75){
if(data176.present !== undefined){
const _errs403 = errors;
if(typeof data176.present !== "boolean"){
const err256 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_template/present",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/25/properties/reader_template/properties/present/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err256];
}
else {
vErrors.push(err256);
}
errors++;
}
var valid75 = _errs403 === errors;
}
else {
var valid75 = true;
}
if(valid75){
if(data176.phase !== undefined){
let data179 = data176.phase;
const _errs405 = errors;
if(typeof data179 !== "string"){
const err257 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_template/phase",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/25/properties/reader_template/properties/phase/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err257];
}
else {
vErrors.push(err257);
}
errors++;
}
if(!((((((((data179 === "uploading") || (data179 === "sealed")) || (data179 === "admitted")) || (data179 === "complete")) || (data179 === "cancelled")) || (data179 === "denied")) || (data179 === "rejected")) || (data179 === "retired"))){
const err258 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_template/phase",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/25/properties/reader_template/properties/phase/enum",keyword:"enum",params:{allowedValues: schema111.oneOf[8].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[25].properties.reader_template.properties.phase.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err258];
}
else {
vErrors.push(err258);
}
errors++;
}
var valid75 = _errs405 === errors;
}
else {
var valid75 = true;
}
if(valid75){
if(data176.manifest !== undefined){
const _errs407 = errors;
if(typeof data176.manifest !== "boolean"){
const err259 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_template/manifest",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/25/properties/reader_template/properties/manifest/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err259];
}
else {
vErrors.push(err259);
}
errors++;
}
var valid75 = _errs407 === errors;
}
else {
var valid75 = true;
}
}
}
}
}
}
}
else {
const err260 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_template",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/25/properties/reader_template/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err261 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/25/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err261];
}
else {
vErrors.push(err261);
}
errors++;
}
}
var _valid5 = _errs396 === errors;
if(_valid5 && valid28){
valid28 = false;
passing3 = [passing3, 25];
}
else {
if(_valid5){
valid28 = true;
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
if(!valid28){
const err262 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf",keyword:"oneOf",params:{passingSchemas: passing3},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err262];
}
else {
vErrors.push(err262);
}
errors++;
}
else {
errors = _errs139;
if(vErrors !== null){
if(_errs139){
vErrors.length = _errs139;
}
else {
vErrors = null;
}
}
}
var valid27 = _errs138 === errors;
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
const err263 = {instancePath:instancePath+"/refresh_status/view/failure/stopped",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err264 = {instancePath:instancePath+"/refresh_status/view/failure",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err264];
}
else {
vErrors.push(err264);
}
errors++;
}
}
var _valid4 = _errs129 === errors;
if(_valid4 && valid25){
valid25 = false;
passing2 = [passing2, 1];
}
else {
if(_valid4){
valid25 = true;
passing2 = 1;
if(props9 !== true){
props9 = true;
}
}
}
if(!valid25){
const err265 = {instancePath:instancePath+"/refresh_status/view/failure",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/properties/failure/oneOf",keyword:"oneOf",params:{passingSchemas: passing2},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err265];
}
else {
vErrors.push(err265);
}
errors++;
}
else {
errors = _errs127;
if(vErrors !== null){
if(_errs127){
vErrors.length = _errs127;
}
else {
vErrors = null;
}
}
}
var valid24 = _errs126 === errors;
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
}
}
}
}
}
}
}
}
else {
const err266 = {instancePath:instancePath+"/refresh_status/view",schemaPath:"#/oneOf/8/properties/refresh_status/properties/view/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err266];
}
else {
vErrors.push(err266);
}
errors++;
}
}
var valid23 = _errs109 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data39.diagnostic !== undefined){
const _errs409 = errors;
if(!(validate437(data39.diagnostic, {instancePath:instancePath+"/refresh_status/diagnostic",parentData:data39,parentDataProperty:"diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate437.errors : vErrors.concat(validate437.errors);
errors = vErrors.length;
}
var valid23 = _errs409 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data39.query_diagnostic !== undefined){
const _errs410 = errors;
if(!(validate437(data39.query_diagnostic, {instancePath:instancePath+"/refresh_status/query_diagnostic",parentData:data39,parentDataProperty:"query_diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate437.errors : vErrors.concat(validate437.errors);
errors = vErrors.length;
}
var valid23 = _errs410 === errors;
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
else {
const err267 = {instancePath:instancePath+"/refresh_status",schemaPath:"#/oneOf/8/properties/refresh_status/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err267];
}
else {
vErrors.push(err267);
}
errors++;
}
}
}
}
}
}
else {
const err268 = {instancePath,schemaPath:"#/oneOf/8/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err268];
}
else {
vErrors.push(err268);
}
errors++;
}
}
var _valid0 = _errs100 === errors;
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
const err269 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err269];
}
else {
vErrors.push(err269);
}
errors++;
validate410.errors = vErrors;
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
validate410.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate410.evaluated = {"dynamicProps":true,"dynamicItems":false};
