// Generated; no runtime code generation or eval.
import lengthModule from "ajv/dist/runtime/ucs2length.js";
const ucs2length = lengthModule.default ?? lengthModule;
"use strict";
export const SubjectProof = validate52;
const schema19 = {"type":"object","additionalProperties":false,"properties":{"claim":{"$ref":"https://transit.invalid/generated-validator/5"},"signature":{"$ref":"https://transit.invalid/generated-validator/6"}},"required":["claim","signature"]};
const schema20 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"https://transit.invalid/generated-validator/0"},"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"principal":{"$ref":"https://transit.invalid/generated-validator/1"},"credential_epoch":{"$ref":"https://transit.invalid/generated-validator/1"},"role":{"$ref":"https://transit.invalid/generated-validator/2"},"audience":{"$ref":"https://transit.invalid/generated-validator/1"},"context":{"$ref":"https://transit.invalid/generated-validator/4"}},"required":["definition","realm","principal","credential_epoch","role","audience","context"]};
const schema21 = {"type":"string","enum":["342c874ab8c989576b91b8cde9c8d5f0023ac6a51f0435b04963203d38c41b3d"]};

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
validate54.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!(data === "342c874ab8c989576b91b8cde9c8d5f0023ac6a51f0435b04963203d38c41b3d")){
validate54.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema21.enum}}];
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
validate56.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"}}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 9007199254740991 || isNaN(data)){
validate56.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991}}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate56.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0}}];
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
const err0 = {instancePath,schemaPath:"#/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err1 = {instancePath,schemaPath:"#/anyOf",keyword:"anyOf",params:{}};
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
validate65.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"}}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate65.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255}}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate65.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0}}];
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
validate64.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 32}}];
return false;
}
else {
if(data.length < 32){
validate64.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 32}}];
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
validate64.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
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
validate53.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "definition") || (key0 === "realm")) || (key0 === "principal")) || (key0 === "credential_epoch")) || (key0 === "role")) || (key0 === "audience")) || (key0 === "context"))){
validate53.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate53.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate69.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 64}}];
return false;
}
else {
if(data.length < 64){
validate69.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 64}}];
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
validate69.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
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
validate52.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "claim") || (key0 === "signature"))){
validate52.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate52.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate74.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!(((((((((((data === "syntax") || (data === "binding")) || (data === "unsupported")) || (data === "constraint")) || (data === "access")) || (data === "conflict")) || (data === "limit")) || (data === "lifecycle")) || (data === "integrity")) || (data === "unavailable")) || (data === "internal"))){
validate74.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema28.enum}}];
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
validate76.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!((((((((((((((data === "input") || (data === "parse")) || (data === "compile")) || (data === "bind")) || (data === "prepare")) || (data === "submit")) || (data === "admission")) || (data === "execute")) || (data === "read")) || (data === "decode")) || (data === "output")) || (data === "reconcile")) || (data === "cleanup")) || (data === "control"))){
validate76.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema29.enum}}];
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
validate78.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!((((((((((((((data === "not_applicable") || (data === "not_submitted")) || (data === "not_dispatched")) || (data === "prepared")) || (data === "unknown")) || (data === "pending")) || (data === "input_rejected")) || (data === "rejected")) || (data === "applied")) || (data === "completed")) || (data === "failed")) || (data === "cancelled")) || (data === "retired")) || (data === "closed_unknown"))){
validate78.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema30.enum}}];
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
validate80.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!(((((data === "none") || (data === "local_before_dispatch")) || (data === "saved_intent")) || (data === "native_receipt")) || (data === "domain_status"))){
validate80.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema31.enum}}];
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
const err0 = {instancePath,schemaPath:"#/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 96}};
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
const err1 = {instancePath,schemaPath:"#/anyOf/0/type",keyword:"type",params:{type: "string"}};
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
const err2 = {instancePath,schemaPath:"#/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err3 = {instancePath,schemaPath:"#/anyOf",keyword:"anyOf",params:{}};
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
validate86.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!(((((((((((((data === "sql") || (data === "query")) || (data === "mutation")) || (data === "catalog")) || (data === "application")) || (data === "publication")) || (data === "migration")) || (data === "reactive")) || (data === "serving")) || (data === "effect")) || (data === "exchange")) || (data === "transport")) || (data === "internal"))){
validate86.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema35.enum}}];
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
validate88.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 20}}];
return false;
}
else {
if(!pattern3.test(data)){
validate88.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"}}];
return false;
}
}
}
else {
validate88.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
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
const err0 = {instancePath,schemaPath:"#/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err1 = {instancePath,schemaPath:"#/anyOf",keyword:"anyOf",params:{}};
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
validate85.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "domain") || (key0 === "id")) || (key0 === "realm")) || (key0 === "resource")) || (key0 === "sequence"))){
validate85.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate85.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
const err0 = {instancePath,schemaPath:"#/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err1 = {instancePath,schemaPath:"#/anyOf",keyword:"anyOf",params:{}};
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
const err0 = {instancePath,schemaPath:"#/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 512}};
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
const err1 = {instancePath,schemaPath:"#/anyOf/0/type",keyword:"type",params:{type: "string"}};
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
const err2 = {instancePath,schemaPath:"#/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err3 = {instancePath,schemaPath:"#/anyOf",keyword:"anyOf",params:{}};
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
validate100.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!((data === "utf8") || (data === "escaped_bytes"))){
validate100.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema40.enum}}];
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
validate97.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "source") || (key0 === "source_encoding")) || (key0 === "source_truncated")) || (key0 === "statement")) || (key0 === "offset")) || (key0 === "length")) || (key0 === "line")) || (key0 === "byte_column"))){
validate97.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate97.errors = [{instancePath:instancePath+"/source_truncated",schemaPath:"#/properties/source_truncated/type",keyword:"type",params:{type: "boolean"}}];
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
validate97.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate108.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((data === "object") || (data === "name")) || (data === "table")) || (data === "native_input")) || (data === "affected_rows")) || (data === "argument")) || (data === "option")) || (data === "permissions")) || (data === "scope")) || (data === "column")) || (data === "qualifier")) || (data === "constraint")) || (data === "key")) || (data === "input_row")) || (data === "first_occurrence")) || (data === "parameter")) || (data === "parameter_use")) || (data === "expected_count")) || (data === "actual_count")) || (data === "expected_type")) || (data === "actual_type")) || (data === "supplied_value")) || (data === "expected_value")) || (data === "expression")) || (data === "source_kind")) || (data === "source_basis")) || (data === "source_key")) || (data === "source_row")) || (data === "field_path")) || (data === "byte_offset")) || (data === "expected_resource")) || (data === "actual_resource")) || (data === "expected_source")) || (data === "actual_source")) || (data === "expected_revision")) || (data === "actual_revision")) || (data === "expected_schema")) || (data === "actual_schema")) || (data === "expected_policy")) || (data === "actual_policy")) || (data === "budget")) || (data === "limit")) || (data === "required")) || (data === "unit")) || (data === "completed_statements")) || (data === "emitted_rows")) || (data === "emitted_segments")) || (data === "completion")) || (data === "proposal")) || (data === "step")) || (data === "generation")) || (data === "attachment")) || (data === "lease")) || (data === "schema_origin")) || (data === "sampling_records")) || (data === "operation")) || (data === "native_cause")) || (data === "expected_bytes")) || (data === "presence")) || (data === "published")) || (data === "subscription")) || (data === "expected_codec")) || (data === "actual_codec")) || (data === "observed_clock")) || (data === "expected_namespace")) || (data === "actual_namespace")) || (data === "attempt")) || (data === "executor")) || (data === "resolution_reason")) || (data === "principal")) || (data === "deadline")) || (data === "authorization_policy")) || (data === "resolution_policy")) || (data === "protocol_status")) || (data === "native_effect")) || (data === "dependency")) || (data === "dependency_kind")) || (data === "dependency_owner"))){
validate108.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema41.enum}}];
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
validate110.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!(((((data === "caller") || (data === "execution")) || (data === "schema")) || (data === "authority")) || (data === "owner"))){
validate110.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema42.enum}}];
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
validate112.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!((((((data === "provided") || (data === "truncated")) || (data === "unrecorded")) || (data === "unavailable")) || (data === "withheld")) || (data === "inapplicable"))){
validate112.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema43.enum}}];
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
validate114.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "text")){
validate114.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate114.errors = [{instancePath:instancePath+"/text",schemaPath:"#/properties/text/maxLength",keyword:"maxLength",params:{limit: 256}}];
return false;
}
}
else {
validate114.errors = [{instancePath:instancePath+"/text",schemaPath:"#/properties/text/type",keyword:"type",params:{type: "string"}}];
return false;
}
}
}
}
}
}
else {
validate114.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate117.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 20}}];
return false;
}
else {
if(!pattern4.test(data)){
validate117.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(0|-?[1-9][0-9]*)$"}}];
return false;
}
}
}
else {
validate117.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
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
validate116.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "signed")){
validate116.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate116.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate120.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "unsigned")){
validate120.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate120.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate123.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "boolean")){
validate123.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.boolean !== undefined){
if(typeof data.boolean !== "boolean"){
validate123.errors = [{instancePath:instancePath+"/boolean",schemaPath:"#/properties/boolean/type",keyword:"type",params:{type: "boolean"}}];
return false;
}
}
}
}
}
else {
validate123.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate125.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "digest")){
validate125.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate125.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate129.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!(((((((((((data === "correct_input") || (data === "inspect_status")) || (data === "resume_exact")) || (data === "cancel_wait")) || (data === "cancel_mutation")) || (data === "refresh")) || (data === "recompile")) || (data === "retry_read")) || (data === "inspect_scope")) || (data === "reconcile_effect")) || (data === "contact_operator"))){
validate129.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema50.enum}}];
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
validate72.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema27.properties, key0))){
validate72.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate72.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1}}];
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
validate72.errors = [{instancePath:instancePath+"/code",schemaPath:"#/properties/code/maxLength",keyword:"maxLength",params:{limit: 96}}];
return false;
}
}
else {
validate72.errors = [{instancePath:instancePath+"/code",schemaPath:"#/properties/code/type",keyword:"type",params:{type: "string"}}];
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
validate72.errors = [{instancePath:instancePath+"/message",schemaPath:"#/properties/message/maxLength",keyword:"maxLength",params:{limit: 384}}];
return false;
}
}
else {
validate72.errors = [{instancePath:instancePath+"/message",schemaPath:"#/properties/message/type",keyword:"type",params:{type: "string"}}];
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
const err0 = {instancePath:instancePath+"/location",schemaPath:"#/properties/location/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err1 = {instancePath:instancePath+"/location",schemaPath:"#/properties/location/anyOf",keyword:"anyOf",params:{}};
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
validate72.errors = [{instancePath:instancePath+"/facts",schemaPath:"#/properties/facts/maxItems",keyword:"maxItems",params:{limit: 16}}];
return false;
}
else {
if(data11.length < 16){
validate72.errors = [{instancePath:instancePath+"/facts",schemaPath:"#/properties/facts/minItems",keyword:"minItems",params:{limit: 16}}];
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
const err2 = {instancePath:instancePath+"/facts/" + i0,schemaPath:"#/properties/facts/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing1}};
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
const err3 = {instancePath:instancePath+"/facts/" + i0,schemaPath:"#/properties/facts/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1}};
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
const err4 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/required",keyword:"required",params:{missingProperty: missing2}};
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
const err5 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2}};
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
const err6 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/type",keyword:"type",params:{type: "object"}};
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
const err7 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf",keyword:"oneOf",params:{passingSchemas: passing0}};
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
const err8 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err9 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf",keyword:"anyOf",params:{}};
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
const err10 = {instancePath:instancePath+"/facts/" + i0,schemaPath:"#/properties/facts/items/anyOf/0/type",keyword:"type",params:{type: "object"}};
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
const err11 = {instancePath:instancePath+"/facts/" + i0,schemaPath:"#/properties/facts/items/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err12 = {instancePath:instancePath+"/facts/" + i0,schemaPath:"#/properties/facts/items/anyOf",keyword:"anyOf",params:{}};
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
validate72.errors = [{instancePath:instancePath+"/facts",schemaPath:"#/properties/facts/type",keyword:"type",params:{type: "array"}}];
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
validate72.errors = [{instancePath:instancePath+"/actions",schemaPath:"#/properties/actions/maxItems",keyword:"maxItems",params:{limit: 4}}];
return false;
}
else {
if(data18.length < 4){
validate72.errors = [{instancePath:instancePath+"/actions",schemaPath:"#/properties/actions/minItems",keyword:"minItems",params:{limit: 4}}];
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
const err13 = {instancePath:instancePath+"/actions/" + i1,schemaPath:"#/properties/actions/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing3}};
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
const err14 = {instancePath:instancePath+"/actions/" + i1,schemaPath:"#/properties/actions/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3}};
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
const err15 = {instancePath:instancePath+"/actions/" + i1,schemaPath:"#/properties/actions/items/anyOf/0/type",keyword:"type",params:{type: "object"}};
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
const err16 = {instancePath:instancePath+"/actions/" + i1,schemaPath:"#/properties/actions/items/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err17 = {instancePath:instancePath+"/actions/" + i1,schemaPath:"#/properties/actions/items/anyOf",keyword:"anyOf",params:{}};
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
validate72.errors = [{instancePath:instancePath+"/actions",schemaPath:"#/properties/actions/type",keyword:"type",params:{type: "array"}}];
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
validate72.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate141.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 512}}];
return false;
}
else {
if(!pattern5.test(data)){
validate141.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"}}];
return false;
}
}
}
else {
validate141.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
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
validate139.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "pid") || (key0 === "value")) || (key0 === "role"))){
validate139.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate139.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate138.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "send")){
validate138.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate138.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate133.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "version") || (key0 === "definition")) || (key0 === "realm")) || (key0 === "principal")) || (key0 === "sequence")) || (key0 === "command"))){
validate133.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate133.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1}}];
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
validate133.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate132.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "request") || (key0 === "signature"))){
validate132.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate132.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate148.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "read") || (key0 === "proof"))){
validate148.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate148.errors = [{instancePath:instancePath+"/read",schemaPath:"#/properties/read/required",keyword:"required",params:{missingProperty: missing1}}];
return false;
}
else {
const _errs4 = errors;
for(const key1 in data0){
if(!((((((key1 === "realm") || (key1 === "principal")) || (key1 === "service")) || (key1 === "ingress")) || (key1 === "kind")) || (key1 === "operation"))){
validate148.errors = [{instancePath:instancePath+"/read",schemaPath:"#/properties/read/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1}}];
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
validate148.errors = [{instancePath:instancePath+"/read/kind",schemaPath:"#/properties/read/properties/kind/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!((((data5 === "discovery") || (data5 === "status")) || (data5 === "result")) || (data5 === "disposition"))){
validate148.errors = [{instancePath:instancePath+"/read/kind",schemaPath:"#/properties/read/properties/kind/enum",keyword:"enum",params:{allowedValues: schema56.properties.read.properties.kind.enum}}];
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
validate148.errors = [{instancePath:instancePath+"/read",schemaPath:"#/properties/read/type",keyword:"type",params:{type: "object"}}];
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
validate148.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate160.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!((((((((data === "ingress_accepted") || (data === "not_observed")) || (data === "service_admitted")) || (data === "completed")) || (data === "cancelled")) || (data === "timed_out")) || (data === "failed")) || (data === "rejected"))){
validate160.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema58.enum}}];
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
validate164.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"}}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 65535 || isNaN(data)){
validate164.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535}}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate164.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0}}];
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
validate177.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!(((((data === "admitted") || (data === "completed")) || (data === "cancelled")) || (data === "timed_out")) || (data === "failed"))){
validate177.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema60.enum}}];
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
validate184.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!((((((((((((((((((((((((((((((((((((((((((((((((data === "InvalidServingFrame") || (data === "ServingExternalOriginRequired")) || (data === "UnexpectedServingOrigin")) || (data === "InvalidServingCommand")) || (data === "InvalidServingIdentity")) || (data === "InvalidServiceBinding")) || (data === "InvalidServicePolicy")) || (data === "ServingDenied")) || (data === "ServiceRevisionConflict")) || (data === "ServingIdentityConflict")) || (data === "ServingCapacity")) || (data === "ServiceUnpublished")) || (data === "InvalidWaitLifetime")) || (data === "ServingOperationNotFound")) || (data === "UnknownServingCorrelation")) || (data === "UnexpectedServingReplySource")) || (data === "UnexpectedTimerObserver")) || (data === "InvalidTimerObservation")) || (data === "PrematureTimer")) || (data === "UnsupportedServingFrame")) || (data === "InvalidReactiveSource")) || (data === "ReactiveSessionNotFound")) || (data === "ReactiveGenerationConflict")) || (data === "ReactiveSessionClosed")) || (data === "ReactiveSessionExpired")) || (data === "ReactiveResetRequired")) || (data === "InvalidReactiveLease")) || (data === "ReactiveCapacity")) || (data === "InvalidReactiveAttachment")) || (data === "ReactiveAttachmentConflict")) || (data === "ReactiveSubscriptionConflict")) || (data === "ReactiveLeaseConflict")) || (data === "InvalidRefreshBudget")) || (data === "InvalidRefreshTemplate")) || (data === "RefreshGenerationConflict")) || (data === "RefreshNotFound")) || (data === "RefreshResultConflict")) || (data === "UnexpectedRefreshWake")) || (data === "AccessDenied")) || (data === "QueryDenied")) || (data === "CatalogDenied")) || (data === "ResourceUnavailable")) || (data === "QuerySourceUnavailable")) || (data === "ResultUnavailable")) || (data === "PublicationNotPublished")) || (data === "UnsupportedReactiveSource")) || (data === "InvalidReactiveProgress")) || (data === "TableNotFound"))){
validate184.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema62.enum}}];
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
validate187.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!(((data === "service") || (data === "reactive")) || (data === "refresh"))){
validate187.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema63.enum}}];
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
validate183.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "reason") || (key0 === "input")) || (key0 === "kind")) || (key0 === "subject")) || (key0 === "generation")) || (key0 === "payload")) || (key0 === "cause"))){
validate183.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate183.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate155.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema57.properties, key0))){
validate155.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
const err0 = {instancePath:instancePath+"/binding",schemaPath:"#/properties/binding/anyOf/0/required",keyword:"required",params:{missingProperty: missing1}};
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
const err1 = {instancePath:instancePath+"/binding",schemaPath:"#/properties/binding/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1}};
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
const err2 = {instancePath:instancePath+"/binding/published",schemaPath:"#/properties/binding/anyOf/0/properties/published/type",keyword:"type",params:{type: "boolean"}};
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
const err3 = {instancePath:instancePath+"/binding",schemaPath:"#/properties/binding/anyOf/0/type",keyword:"type",params:{type: "object"}};
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
const err4 = {instancePath:instancePath+"/binding",schemaPath:"#/properties/binding/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err5 = {instancePath:instancePath+"/binding",schemaPath:"#/properties/binding/anyOf",keyword:"anyOf",params:{}};
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
const err6 = {instancePath:instancePath+"/operation",schemaPath:"#/properties/operation/anyOf/0/required",keyword:"required",params:{missingProperty: missing2}};
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
const err7 = {instancePath:instancePath+"/operation",schemaPath:"#/properties/operation/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2}};
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
const err8 = {instancePath:instancePath+"/operation",schemaPath:"#/properties/operation/anyOf/0/type",keyword:"type",params:{type: "object"}};
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
const err9 = {instancePath:instancePath+"/operation",schemaPath:"#/properties/operation/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err10 = {instancePath:instancePath+"/operation",schemaPath:"#/properties/operation/anyOf",keyword:"anyOf",params:{}};
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
const err11 = {instancePath:instancePath+"/diagnostic",schemaPath:"#/properties/diagnostic/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err12 = {instancePath:instancePath+"/diagnostic",schemaPath:"#/properties/diagnostic/anyOf",keyword:"anyOf",params:{}};
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
const err13 = {instancePath:instancePath+"/disposition",schemaPath:"#/properties/disposition/anyOf/0/required",keyword:"required",params:{missingProperty: missing3}};
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
const err14 = {instancePath:instancePath+"/disposition",schemaPath:"#/properties/disposition/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3}};
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
const err15 = {instancePath:instancePath+"/disposition/diagnostic",schemaPath:"#/properties/disposition/anyOf/0/properties/diagnostic/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err16 = {instancePath:instancePath+"/disposition/diagnostic",schemaPath:"#/properties/disposition/anyOf/0/properties/diagnostic/anyOf",keyword:"anyOf",params:{}};
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
const err17 = {instancePath:instancePath+"/disposition",schemaPath:"#/properties/disposition/anyOf/0/type",keyword:"type",params:{type: "object"}};
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
const err18 = {instancePath:instancePath+"/disposition",schemaPath:"#/properties/disposition/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err19 = {instancePath:instancePath+"/disposition",schemaPath:"#/properties/disposition/anyOf",keyword:"anyOf",params:{}};
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
validate155.errors = [{instancePath:instancePath+"/capabilities",schemaPath:"#/properties/capabilities/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4}}];
return false;
break;
}
}
if(_errs61 === errors){
if(data30.http !== undefined){
const _errs62 = errors;
if(typeof data30.http !== "boolean"){
validate155.errors = [{instancePath:instancePath+"/capabilities/http",schemaPath:"#/properties/capabilities/properties/http/type",keyword:"type",params:{type: "boolean"}}];
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
validate155.errors = [{instancePath:instancePath+"/capabilities/sse",schemaPath:"#/properties/capabilities/properties/sse/type",keyword:"type",params:{type: "boolean"}}];
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
validate155.errors = [{instancePath:instancePath+"/capabilities/websocket",schemaPath:"#/properties/capabilities/properties/websocket/type",keyword:"type",params:{type: "boolean"}}];
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
validate155.errors = [{instancePath:instancePath+"/capabilities/grpc",schemaPath:"#/properties/capabilities/properties/grpc/type",keyword:"type",params:{type: "boolean"}}];
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
validate155.errors = [{instancePath:instancePath+"/capabilities/flight",schemaPath:"#/properties/capabilities/properties/flight/type",keyword:"type",params:{type: "boolean"}}];
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
validate155.errors = [{instancePath:instancePath+"/capabilities",schemaPath:"#/properties/capabilities/type",keyword:"type",params:{type: "object"}}];
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
validate155.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate197.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "position")){
validate197.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate197.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate195.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "stage") || (key0 === "receipt"))){
validate195.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate195.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate202.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "realm") || (key0 === "principal")) || (key0 === "service")) || (key0 === "ingress")) || (key0 === "session")) || (key0 === "generation")) || (key0 === "subscription")) || (key0 === "subscription_generation"))){
validate202.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate202.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate212.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!(((data === "session") || (data === "snapshot")) || (data === "events"))){
validate212.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema69.enum}}];
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
validate215.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 16}}];
return false;
}
else {
if(data.length < 16){
validate215.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 16}}];
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
validate215.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
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
validate225.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 20}}];
return false;
}
else {
if(!pattern3.test(data)){
validate225.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"}}];
return false;
}
}
}
else {
validate225.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
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
validate220.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "version") || (key0 === "scope")) || (key0 === "watch_revision")) || (key0 === "resource")) || (key0 === "schema")) || (key0 === "data_revision")) || (key0 === "outcome_position"))){
validate220.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate220.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1}}];
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
validate220.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate219.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "position") || (key0 === "signature"))){
validate219.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate219.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
const err0 = {instancePath,schemaPath:"#/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err1 = {instancePath,schemaPath:"#/anyOf",keyword:"anyOf",params:{}};
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
validate201.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "scope") || (key0 === "kind")) || (key0 === "attachment")) || (key0 === "nonce")) || (key0 === "cursor"))){
validate201.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate201.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate200.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "read") || (key0 === "proof"))){
validate200.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate200.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate242.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!(((data === "open") || (data === "closed")) || (data === "expired"))){
validate242.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema77.enum}}];
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
validate235.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema76.properties, key0))){
validate235.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate235.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate251.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema79.properties, key0))){
validate251.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate251.errors = [{instancePath:instancePath+"/published",schemaPath:"#/properties/published/type",keyword:"type",params:{type: "boolean"}}];
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
validate251.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
const err0 = {instancePath,schemaPath:"#/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err1 = {instancePath,schemaPath:"#/anyOf",keyword:"anyOf",params:{}};
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
validate268.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "resource") || (key0 === "partition")) || (key0 === "accepted")) || (key0 === "contract")) || (key0 === "schema"))){
validate268.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate268.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate279.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 255}}];
return false;
}
else {
if(data.length < 255){
validate279.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 255}}];
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
validate279.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
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
validate277.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "len") || (key0 === "data"))){
validate277.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate277.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate276.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 2}}];
return false;
}
else {
if(data.length < 2){
validate276.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 2}}];
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
validate276.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
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
validate275.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "names") || (key0 === "value_type"))){
validate275.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate275.errors = [{instancePath:instancePath+"/value_type",schemaPath:"#/properties/value_type/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!(data1 === "int64")){
validate275.errors = [{instancePath:instancePath+"/value_type",schemaPath:"#/properties/value_type/enum",keyword:"enum",params:{allowedValues: schema84.properties.value_type.enum}}];
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
validate275.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate266.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "data_revision") || (key0 === "basis")) || (key0 === "schema"))){
validate266.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate266.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate289.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 20}}];
return false;
}
else {
if(!pattern7.test(data)){
validate289.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(0|-[1-9][0-9]*|[1-9][0-9]*)$"}}];
return false;
}
}
}
else {
validate289.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
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
const err0 = {instancePath,schemaPath:"#/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err1 = {instancePath,schemaPath:"#/anyOf",keyword:"anyOf",params:{}};
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
validate288.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "key") || (key0 === "value"))){
validate288.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate288.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
const err0 = {instancePath,schemaPath:"#/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err1 = {instancePath,schemaPath:"#/anyOf",keyword:"anyOf",params:{}};
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
validate286.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 8}}];
return false;
}
else {
if(data.length < 8){
validate286.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 8}}];
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
validate286.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
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
validate265.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "observation") || (key0 === "rows")) || (key0 === "more"))){
validate265.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate265.errors = [{instancePath:instancePath+"/more",schemaPath:"#/properties/more/type",keyword:"type",params:{type: "boolean"}}];
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
validate265.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
const err0 = {instancePath,schemaPath:"#/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err1 = {instancePath,schemaPath:"#/anyOf",keyword:"anyOf",params:{}};
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
validate234.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "version") || (key0 === "session")) || (key0 === "source")) || (key0 === "snapshot")) || (key0 === "event")) || (key0 === "cursor"))){
validate234.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate234.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1}}];
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
const err0 = {instancePath:instancePath+"/event",schemaPath:"#/properties/event/anyOf/0/required",keyword:"required",params:{missingProperty: missing1}};
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
const err1 = {instancePath:instancePath+"/event",schemaPath:"#/properties/event/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1}};
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
const err2 = {instancePath:instancePath+"/event/source_changed",schemaPath:"#/properties/event/anyOf/0/properties/source_changed/type",keyword:"type",params:{type: "boolean"}};
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
const err3 = {instancePath:instancePath+"/event/outcome",schemaPath:"#/properties/event/anyOf/0/properties/outcome/anyOf/0/required",keyword:"required",params:{missingProperty: missing2}};
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
const err4 = {instancePath:instancePath+"/event/outcome",schemaPath:"#/properties/event/anyOf/0/properties/outcome/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2}};
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
const err5 = {instancePath:instancePath+"/event/outcome/diagnostic",schemaPath:"#/properties/event/anyOf/0/properties/outcome/anyOf/0/properties/diagnostic/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err6 = {instancePath:instancePath+"/event/outcome/diagnostic",schemaPath:"#/properties/event/anyOf/0/properties/outcome/anyOf/0/properties/diagnostic/anyOf",keyword:"anyOf",params:{}};
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
const err7 = {instancePath:instancePath+"/event/outcome",schemaPath:"#/properties/event/anyOf/0/properties/outcome/anyOf/0/type",keyword:"type",params:{type: "object"}};
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
const err8 = {instancePath:instancePath+"/event/outcome",schemaPath:"#/properties/event/anyOf/0/properties/outcome/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err9 = {instancePath:instancePath+"/event/outcome",schemaPath:"#/properties/event/anyOf/0/properties/outcome/anyOf",keyword:"anyOf",params:{}};
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
const err10 = {instancePath:instancePath+"/event",schemaPath:"#/properties/event/anyOf/0/type",keyword:"type",params:{type: "object"}};
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
const err11 = {instancePath:instancePath+"/event",schemaPath:"#/properties/event/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err12 = {instancePath:instancePath+"/event",schemaPath:"#/properties/event/anyOf",keyword:"anyOf",params:{}};
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
validate234.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate308.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "request") || (key0 === "signature"))){
validate308.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate308.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate307.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "version") || (key0 === "attach")) || (key0 === "read"))){
validate307.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate307.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1}}];
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
validate307.errors = [{instancePath:instancePath+"/read",schemaPath:"#/properties/read/required",keyword:"required",params:{missingProperty: missing1}}];
return false;
}
else {
const _errs6 = errors;
for(const key1 in data2){
if(!((key1 === "read") || (key1 === "proof"))){
validate307.errors = [{instancePath:instancePath+"/read",schemaPath:"#/properties/read/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1}}];
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
validate307.errors = [{instancePath:instancePath+"/read",schemaPath:"#/properties/read/type",keyword:"type",params:{type: "object"}}];
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
validate307.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
const err0 = {instancePath,schemaPath:"#/oneOf/0/required",keyword:"required",params:{missingProperty: missing0}};
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
const err1 = {instancePath,schemaPath:"#/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}};
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
const err2 = {instancePath:instancePath+"/attach",schemaPath:"#/oneOf/0/properties/attach/required",keyword:"required",params:{missingProperty: missing1}};
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
const err3 = {instancePath:instancePath+"/attach",schemaPath:"#/oneOf/0/properties/attach/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1}};
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
const err4 = {instancePath:instancePath+"/attach/version",schemaPath:"#/oneOf/0/properties/attach/properties/version/const",keyword:"const",params:{allowedValue: 1}};
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
const err5 = {instancePath:instancePath+"/attach/read",schemaPath:"#/oneOf/0/properties/attach/properties/read/required",keyword:"required",params:{missingProperty: missing2}};
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
const err6 = {instancePath:instancePath+"/attach/read",schemaPath:"#/oneOf/0/properties/attach/properties/read/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2}};
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
const err7 = {instancePath:instancePath+"/attach/read",schemaPath:"#/oneOf/0/properties/attach/properties/read/type",keyword:"type",params:{type: "object"}};
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
const err8 = {instancePath:instancePath+"/attach",schemaPath:"#/oneOf/0/properties/attach/type",keyword:"type",params:{type: "object"}};
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
const err9 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"}};
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
const err10 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing3}};
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
const err11 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3}};
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
const err12 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"}};
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
const err13 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing4}};
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
const err14 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4}};
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
const err15 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"}};
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
const err16 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing5}};
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
const err17 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5}};
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
const err18 = {instancePath:instancePath+"/read",schemaPath:"#/oneOf/3/properties/read/required",keyword:"required",params:{missingProperty: missing6}};
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
const err19 = {instancePath:instancePath+"/read",schemaPath:"#/oneOf/3/properties/read/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6}};
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
const err20 = {instancePath:instancePath+"/read",schemaPath:"#/oneOf/3/properties/read/type",keyword:"type",params:{type: "object"}};
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
const err21 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"}};
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
const err22 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0}};
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
validate324.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"}}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 4294967295 || isNaN(data)){
validate324.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295}}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate324.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0}}];
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
validate330.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "stage") || (key0 === "receipt"))){
validate330.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate330.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate329.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "receipt")){
validate329.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate329.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
const err0 = {instancePath,schemaPath:"#/oneOf/0/required",keyword:"required",params:{missingProperty: missing0}};
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
const err1 = {instancePath,schemaPath:"#/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}};
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
const err2 = {instancePath:instancePath+"/challenge",schemaPath:"#/oneOf/0/properties/challenge/required",keyword:"required",params:{missingProperty: missing1}};
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
const err3 = {instancePath:instancePath+"/challenge",schemaPath:"#/oneOf/0/properties/challenge/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1}};
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
const err4 = {instancePath:instancePath+"/challenge/version",schemaPath:"#/oneOf/0/properties/challenge/properties/version/const",keyword:"const",params:{allowedValue: 1}};
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
const err5 = {instancePath:instancePath+"/challenge",schemaPath:"#/oneOf/0/properties/challenge/type",keyword:"type",params:{type: "object"}};
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
const err6 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"}};
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
const err7 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing2}};
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
const err8 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2}};
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
const err9 = {instancePath:instancePath+"/attached",schemaPath:"#/oneOf/1/properties/attached/required",keyword:"required",params:{missingProperty: missing3}};
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
const err10 = {instancePath:instancePath+"/attached",schemaPath:"#/oneOf/1/properties/attached/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3}};
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
const err11 = {instancePath:instancePath+"/attached",schemaPath:"#/oneOf/1/properties/attached/type",keyword:"type",params:{type: "object"}};
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
const err12 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"}};
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
const err13 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing4}};
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
const err14 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4}};
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
const err15 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/3/properties/observation/required",keyword:"required",params:{missingProperty: missing5}};
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
const err16 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/3/properties/observation/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5}};
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
const err17 = {instancePath:instancePath+"/observation/version",schemaPath:"#/oneOf/3/properties/observation/properties/version/const",keyword:"const",params:{allowedValue: 1}};
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
const err18 = {instancePath:instancePath+"/observation/event",schemaPath:"#/oneOf/3/properties/observation/properties/event/anyOf/0/required",keyword:"required",params:{missingProperty: missing6}};
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
const err19 = {instancePath:instancePath+"/observation/event",schemaPath:"#/oneOf/3/properties/observation/properties/event/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6}};
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
const err20 = {instancePath:instancePath+"/observation/event/source_changed",schemaPath:"#/oneOf/3/properties/observation/properties/event/anyOf/0/properties/source_changed/type",keyword:"type",params:{type: "boolean"}};
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
const err21 = {instancePath:instancePath+"/observation/event/outcome",schemaPath:"#/oneOf/3/properties/observation/properties/event/anyOf/0/properties/outcome/anyOf/0/required",keyword:"required",params:{missingProperty: missing7}};
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
const err22 = {instancePath:instancePath+"/observation/event/outcome",schemaPath:"#/oneOf/3/properties/observation/properties/event/anyOf/0/properties/outcome/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7}};
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
const err23 = {instancePath:instancePath+"/observation/event/outcome/diagnostic",schemaPath:"#/oneOf/3/properties/observation/properties/event/anyOf/0/properties/outcome/anyOf/0/properties/diagnostic/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err24 = {instancePath:instancePath+"/observation/event/outcome/diagnostic",schemaPath:"#/oneOf/3/properties/observation/properties/event/anyOf/0/properties/outcome/anyOf/0/properties/diagnostic/anyOf",keyword:"anyOf",params:{}};
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
const err25 = {instancePath:instancePath+"/observation/event/outcome",schemaPath:"#/oneOf/3/properties/observation/properties/event/anyOf/0/properties/outcome/anyOf/0/type",keyword:"type",params:{type: "object"}};
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
const err26 = {instancePath:instancePath+"/observation/event/outcome",schemaPath:"#/oneOf/3/properties/observation/properties/event/anyOf/0/properties/outcome/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err27 = {instancePath:instancePath+"/observation/event/outcome",schemaPath:"#/oneOf/3/properties/observation/properties/event/anyOf/0/properties/outcome/anyOf",keyword:"anyOf",params:{}};
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
const err28 = {instancePath:instancePath+"/observation/event",schemaPath:"#/oneOf/3/properties/observation/properties/event/anyOf/0/type",keyword:"type",params:{type: "object"}};
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
const err29 = {instancePath:instancePath+"/observation/event",schemaPath:"#/oneOf/3/properties/observation/properties/event/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err30 = {instancePath:instancePath+"/observation/event",schemaPath:"#/oneOf/3/properties/observation/properties/event/anyOf",keyword:"anyOf",params:{}};
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
const err31 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/3/properties/observation/type",keyword:"type",params:{type: "object"}};
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
const err32 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"}};
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
const err33 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing8}};
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
const err34 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8}};
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
const err35 = {instancePath:instancePath+"/event",schemaPath:"#/oneOf/4/properties/event/required",keyword:"required",params:{missingProperty: missing9}};
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
const err36 = {instancePath:instancePath+"/event",schemaPath:"#/oneOf/4/properties/event/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9}};
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
const err37 = {instancePath:instancePath+"/event/event",schemaPath:"#/oneOf/4/properties/event/properties/event/required",keyword:"required",params:{missingProperty: missing10}};
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
const err38 = {instancePath:instancePath+"/event/event",schemaPath:"#/oneOf/4/properties/event/properties/event/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10}};
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
const err39 = {instancePath:instancePath+"/event/event/source_changed",schemaPath:"#/oneOf/4/properties/event/properties/event/properties/source_changed/type",keyword:"type",params:{type: "boolean"}};
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
const err40 = {instancePath:instancePath+"/event/event/outcome",schemaPath:"#/oneOf/4/properties/event/properties/event/properties/outcome/anyOf/0/required",keyword:"required",params:{missingProperty: missing11}};
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
const err41 = {instancePath:instancePath+"/event/event/outcome",schemaPath:"#/oneOf/4/properties/event/properties/event/properties/outcome/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11}};
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
const err42 = {instancePath:instancePath+"/event/event/outcome/diagnostic",schemaPath:"#/oneOf/4/properties/event/properties/event/properties/outcome/anyOf/0/properties/diagnostic/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err43 = {instancePath:instancePath+"/event/event/outcome/diagnostic",schemaPath:"#/oneOf/4/properties/event/properties/event/properties/outcome/anyOf/0/properties/diagnostic/anyOf",keyword:"anyOf",params:{}};
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
const err44 = {instancePath:instancePath+"/event/event/outcome",schemaPath:"#/oneOf/4/properties/event/properties/event/properties/outcome/anyOf/0/type",keyword:"type",params:{type: "object"}};
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
const err45 = {instancePath:instancePath+"/event/event/outcome",schemaPath:"#/oneOf/4/properties/event/properties/event/properties/outcome/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err46 = {instancePath:instancePath+"/event/event/outcome",schemaPath:"#/oneOf/4/properties/event/properties/event/properties/outcome/anyOf",keyword:"anyOf",params:{}};
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
const err47 = {instancePath:instancePath+"/event/event",schemaPath:"#/oneOf/4/properties/event/properties/event/type",keyword:"type",params:{type: "object"}};
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
const err48 = {instancePath:instancePath+"/event",schemaPath:"#/oneOf/4/properties/event/type",keyword:"type",params:{type: "object"}};
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
const err49 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"}};
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
const err50 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing12}};
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
const err51 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key12}};
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
const err52 = {instancePath:instancePath+"/heartbeat",schemaPath:"#/oneOf/5/properties/heartbeat/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key13}};
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
const err53 = {instancePath:instancePath+"/heartbeat/version",schemaPath:"#/oneOf/5/properties/heartbeat/properties/version/const",keyword:"const",params:{allowedValue: 1}};
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
const err54 = {instancePath:instancePath+"/heartbeat",schemaPath:"#/oneOf/5/properties/heartbeat/type",keyword:"type",params:{type: "object"}};
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
const err55 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"}};
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
const err56 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing13}};
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
const err57 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key14}};
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
const err58 = {instancePath:instancePath+"/terminal",schemaPath:"#/oneOf/6/properties/terminal/required",keyword:"required",params:{missingProperty: missing14}};
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
const err59 = {instancePath:instancePath+"/terminal",schemaPath:"#/oneOf/6/properties/terminal/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key15}};
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
const err60 = {instancePath:instancePath+"/terminal/reason",schemaPath:"#/oneOf/6/properties/terminal/properties/reason/type",keyword:"type",params:{type: "string"}};
if(vErrors === null){
vErrors = [err60];
}
else {
vErrors.push(err60);
}
errors++;
}
if(!((((((((data39 === "denied") || (data39 === "closed")) || (data39 === "expired")) || (data39 === "fenced")) || (data39 === "reset_required")) || (data39 === "interrupted")) || (data39 === "invalid_message")) || (data39 === "capacity"))){
const err61 = {instancePath:instancePath+"/terminal/reason",schemaPath:"#/oneOf/6/properties/terminal/properties/reason/enum",keyword:"enum",params:{allowedValues: schema96.oneOf[6].properties.terminal.properties.reason.enum}};
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
const err62 = {instancePath:instancePath+"/terminal/diagnostic",schemaPath:"#/oneOf/6/properties/terminal/properties/diagnostic/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err63 = {instancePath:instancePath+"/terminal/diagnostic",schemaPath:"#/oneOf/6/properties/terminal/properties/diagnostic/anyOf",keyword:"anyOf",params:{}};
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
const err64 = {instancePath:instancePath+"/terminal",schemaPath:"#/oneOf/6/properties/terminal/type",keyword:"type",params:{type: "object"}};
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
const err65 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"}};
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
const err66 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0}};
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
validate355.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema100.properties, key0))){
validate355.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate355.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1}}];
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
validate355.errors = [{instancePath:instancePath+"/sse",schemaPath:"#/properties/sse/type",keyword:"type",params:{type: "boolean"}}];
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
validate355.errors = [{instancePath:instancePath+"/websocket",schemaPath:"#/properties/websocket/type",keyword:"type",params:{type: "boolean"}}];
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
validate355.errors = [{instancePath:instancePath+"/subprotocol",schemaPath:"#/properties/subprotocol/maxLength",keyword:"maxLength",params:{limit: 256}}];
return false;
}
}
else {
validate355.errors = [{instancePath:instancePath+"/subprotocol",schemaPath:"#/properties/subprotocol/type",keyword:"type",params:{type: "string"}}];
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
validate355.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate363.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "err") || (key0 === "reason")) || (key0 === "diagnostic"))){
validate363.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.err !== undefined){
let data0 = data.err;
const _errs2 = errors;
if(typeof data0 !== "string"){
validate363.errors = [{instancePath:instancePath+"/err",schemaPath:"#/properties/err/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!(((data0 === "ServingRequestFailed") || (data0 === "HttpCapacity")) || (data0 === "InvalidHttpRequest"))){
validate363.errors = [{instancePath:instancePath+"/err",schemaPath:"#/properties/err/enum",keyword:"enum",params:{allowedValues: schema101.properties.err.enum}}];
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
const err0 = {instancePath:instancePath+"/reason",schemaPath:"#/properties/reason/anyOf/0/type",keyword:"type",params:{type: "string"}};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
}
if(!((((((((((((data1 === "denied") || (data1 === "closed")) || (data1 === "expired")) || (data1 === "fenced")) || (data1 === "reset_required")) || (data1 === "not_found")) || (data1 === "conflict")) || (data1 === "result_not_completed")) || (data1 === "unavailable")) || (data1 === "capacity")) || (data1 === "invalid_request")) || (data1 === "internal_failure"))){
const err1 = {instancePath:instancePath+"/reason",schemaPath:"#/properties/reason/anyOf/0/enum",keyword:"enum",params:{allowedValues: schema101.properties.reason.anyOf[0].enum}};
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
const err2 = {instancePath:instancePath+"/reason",schemaPath:"#/properties/reason/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err3 = {instancePath:instancePath+"/reason",schemaPath:"#/properties/reason/anyOf",keyword:"anyOf",params:{}};
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
const err4 = {instancePath:instancePath+"/diagnostic",schemaPath:"#/properties/diagnostic/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err5 = {instancePath:instancePath+"/diagnostic",schemaPath:"#/properties/diagnostic/anyOf",keyword:"anyOf",params:{}};
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
validate363.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
validate365.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "event") || (key0 === "data")) || (key0 === "id"))){
validate365.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.event !== undefined){
let data0 = data.event;
const _errs2 = errors;
if(typeof data0 !== "string"){
validate365.errors = [{instancePath:instancePath+"/event",schemaPath:"#/properties/event/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!((((data0 === "attached") || (data0 === "event")) || (data0 === "heartbeat")) || (data0 === "terminal"))){
validate365.errors = [{instancePath:instancePath+"/event",schemaPath:"#/properties/event/enum",keyword:"enum",params:{allowedValues: schema102.properties.event.enum}}];
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
validate365.errors = [{instancePath:instancePath+"/data",schemaPath:"#/properties/data/maxLength",keyword:"maxLength",params:{limit: 8192}}];
return false;
}
}
else {
validate365.errors = [{instancePath:instancePath+"/data",schemaPath:"#/properties/data/type",keyword:"type",params:{type: "string"}}];
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
validate365.errors = [{instancePath:instancePath+"/id",schemaPath:"#/properties/id/maxLength",keyword:"maxLength",params:{limit: 512}}];
return false;
}
else {
if(!pattern8.test(data2)){
validate365.errors = [{instancePath:instancePath+"/id",schemaPath:"#/properties/id/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})+$"}}];
return false;
}
}
}
else {
validate365.errors = [{instancePath:instancePath+"/id",schemaPath:"#/properties/id/type",keyword:"type",params:{type: "string"}}];
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
validate365.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate365.errors = vErrors;
return errors === 0;
}
validate365.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const HostRequest = validate366;
const schema103 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["describe"],"properties":{"describe":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["clock"],"properties":{"clock":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["inspect"],"properties":{"inspect":{"$ref":"https://transit.invalid/generated-validator/48"}}},{"type":"object","additionalProperties":false,"required":["covered"],"properties":{"covered":{"type":"object","additionalProperties":false,"properties":{"observation":{"$ref":"https://transit.invalid/generated-validator/58"},"captured":{"$ref":"https://transit.invalid/generated-validator/53"}},"required":["observation","captured"]}}},{"type":"object","additionalProperties":false,"required":["prepare"],"properties":{"prepare":{"$ref":"https://transit.invalid/generated-validator/82"}}},{"type":"object","additionalProperties":false,"required":["submit"],"properties":{"submit":{"$ref":"https://transit.invalid/generated-validator/66"}}},{"type":"object","additionalProperties":false,"required":["observe"],"properties":{"observe":{"$ref":"https://transit.invalid/generated-validator/66"}}},{"type":"object","additionalProperties":false,"required":["recover_control"],"properties":{"recover_control":{"$ref":"https://transit.invalid/generated-validator/66"}}},{"type":"object","additionalProperties":false,"required":["sign_read"],"properties":{"sign_read":{"$ref":"https://transit.invalid/generated-validator/48"}}},{"type":"object","additionalProperties":false,"required":["refresh_prepare"],"properties":{"refresh_prepare":{"$ref":"https://transit.invalid/generated-validator/91"}}},{"type":"object","additionalProperties":false,"required":["refresh_status"],"properties":{"refresh_status":{"$ref":"https://transit.invalid/generated-validator/86"}}}]};
const schema104 = {"oneOf":[{"$ref":"https://transit.invalid/generated-validator/71"},{"$ref":"https://transit.invalid/generated-validator/74"},{"$ref":"https://transit.invalid/generated-validator/76"},{"$ref":"https://transit.invalid/generated-validator/78"},{"$ref":"https://transit.invalid/generated-validator/80"},{"$ref":"https://transit.invalid/generated-validator/81"}]};
const schema105 = {"type":"object","additionalProperties":false,"required":["open"],"properties":{"open":{"$ref":"https://transit.invalid/generated-validator/70"}}};
const schema106 = {"type":"object","additionalProperties":false,"properties":{"session":{"$ref":"https://transit.invalid/generated-validator/1"},"source_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"lease_before_ms":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["session","source_revision","lease_before_ms"]};

function validate372(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate372.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.session === undefined) && (missing0 = "session")) || ((data.source_revision === undefined) && (missing0 = "source_revision"))) || ((data.lease_before_ms === undefined) && (missing0 = "lease_before_ms"))){
validate372.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "session") || (key0 === "source_revision")) || (key0 === "lease_before_ms"))){
validate372.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
if(data.source_revision !== undefined){
const _errs3 = errors;
if(!(validate56(data.source_revision, {instancePath:instancePath+"/source_revision",parentData:data,parentDataProperty:"source_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.lease_before_ms !== undefined){
const _errs4 = errors;
if(!(validate56(data.lease_before_ms, {instancePath:instancePath+"/lease_before_ms",parentData:data,parentDataProperty:"lease_before_ms",rootData,dynamicAnchors}))){
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
}
else {
validate372.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate372.errors = vErrors;
return errors === 0;
}
validate372.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if((data.open === undefined) && (missing0 = "open")){
validate371.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "open")){
validate371.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.open !== undefined){
if(!(validate372(data.open, {instancePath:instancePath+"/open",parentData:data,parentDataProperty:"open",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate372.errors : vErrors.concat(validate372.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate371.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate371.errors = vErrors;
return errors === 0;
}
validate371.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema107 = {"type":"object","additionalProperties":false,"required":["attach"],"properties":{"attach":{"$ref":"https://transit.invalid/generated-validator/73"}}};
const schema108 = {"type":"object","additionalProperties":false,"properties":{"identity":{"$ref":"https://transit.invalid/generated-validator/72"},"expected":{"$ref":"https://transit.invalid/generated-validator/1"},"nonce":{"$ref":"https://transit.invalid/generated-validator/43"}},"required":["identity","expected","nonce"]};
const schema109 = {"type":"object","additionalProperties":false,"properties":{"session":{"$ref":"https://transit.invalid/generated-validator/1"},"generation":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["session","generation"]};

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
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.session === undefined) && (missing0 = "session")) || ((data.generation === undefined) && (missing0 = "generation"))){
validate380.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "session") || (key0 === "generation"))){
validate380.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate380.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate380.errors = vErrors;
return errors === 0;
}
validate380.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if((((data.identity === undefined) && (missing0 = "identity")) || ((data.expected === undefined) && (missing0 = "expected"))) || ((data.nonce === undefined) && (missing0 = "nonce"))){
validate379.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "identity") || (key0 === "expected")) || (key0 === "nonce"))){
validate379.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.identity !== undefined){
const _errs2 = errors;
if(!(validate380(data.identity, {instancePath:instancePath+"/identity",parentData:data,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate380.errors : vErrors.concat(validate380.errors);
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
if(!(validate56(data.expected, {instancePath:instancePath+"/expected",parentData:data,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.nonce !== undefined){
const _errs4 = errors;
if(!(validate215(data.nonce, {instancePath:instancePath+"/nonce",parentData:data,parentDataProperty:"nonce",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate215.errors : vErrors.concat(validate215.errors);
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
validate379.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
if((data.attach === undefined) && (missing0 = "attach")){
validate378.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "attach")){
validate378.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.attach !== undefined){
if(!(validate379(data.attach, {instancePath:instancePath+"/attach",parentData:data,parentDataProperty:"attach",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate379.errors : vErrors.concat(validate379.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate378.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate378.errors = vErrors;
return errors === 0;
}
validate378.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema110 = {"type":"object","additionalProperties":false,"required":["subscribe"],"properties":{"subscribe":{"$ref":"https://transit.invalid/generated-validator/75"}}};
const schema111 = {"type":"object","additionalProperties":false,"properties":{"identity":{"$ref":"https://transit.invalid/generated-validator/72"},"expected":{"$ref":"https://transit.invalid/generated-validator/1"},"subscription":{"$ref":"https://transit.invalid/generated-validator/1"},"operation":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["identity","expected","subscription"]};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.identity === undefined) && (missing0 = "identity")) || ((data.expected === undefined) && (missing0 = "expected"))) || ((data.subscription === undefined) && (missing0 = "subscription"))){
validate389.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "identity") || (key0 === "expected")) || (key0 === "subscription")) || (key0 === "operation"))){
validate389.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.identity !== undefined){
const _errs2 = errors;
if(!(validate380(data.identity, {instancePath:instancePath+"/identity",parentData:data,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate380.errors : vErrors.concat(validate380.errors);
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
if(!(validate56(data.expected, {instancePath:instancePath+"/expected",parentData:data,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.subscription !== undefined){
const _errs4 = errors;
if(!(validate56(data.subscription, {instancePath:instancePath+"/subscription",parentData:data,parentDataProperty:"subscription",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.operation !== undefined){
const _errs5 = errors;
if(!(validate56(data.operation, {instancePath:instancePath+"/operation",parentData:data,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
validate389.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate389.errors = vErrors;
return errors === 0;
}
validate389.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if((data.subscribe === undefined) && (missing0 = "subscribe")){
validate388.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "subscribe")){
validate388.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.subscribe !== undefined){
if(!(validate389(data.subscribe, {instancePath:instancePath+"/subscribe",parentData:data,parentDataProperty:"subscribe",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate389.errors : vErrors.concat(validate389.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate388.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate388.errors = vErrors;
return errors === 0;
}
validate388.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema112 = {"type":"object","additionalProperties":false,"required":["renew"],"properties":{"renew":{"$ref":"https://transit.invalid/generated-validator/77"}}};
const schema113 = {"type":"object","additionalProperties":false,"properties":{"identity":{"$ref":"https://transit.invalid/generated-validator/72"},"expected":{"$ref":"https://transit.invalid/generated-validator/1"},"lease_before_ms":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["identity","expected","lease_before_ms"]};

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
if((((data.identity === undefined) && (missing0 = "identity")) || ((data.expected === undefined) && (missing0 = "expected"))) || ((data.lease_before_ms === undefined) && (missing0 = "lease_before_ms"))){
validate397.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "identity") || (key0 === "expected")) || (key0 === "lease_before_ms"))){
validate397.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.identity !== undefined){
const _errs2 = errors;
if(!(validate380(data.identity, {instancePath:instancePath+"/identity",parentData:data,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate380.errors : vErrors.concat(validate380.errors);
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
if(!(validate56(data.expected, {instancePath:instancePath+"/expected",parentData:data,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.lease_before_ms !== undefined){
const _errs4 = errors;
if(!(validate56(data.lease_before_ms, {instancePath:instancePath+"/lease_before_ms",parentData:data,parentDataProperty:"lease_before_ms",rootData,dynamicAnchors}))){
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
}
else {
validate397.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.renew === undefined) && (missing0 = "renew")){
validate396.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "renew")){
validate396.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.renew !== undefined){
if(!(validate397(data.renew, {instancePath:instancePath+"/renew",parentData:data,parentDataProperty:"renew",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate397.errors : vErrors.concat(validate397.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate396.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate396.errors = vErrors;
return errors === 0;
}
validate396.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema114 = {"type":"object","additionalProperties":false,"required":["unsubscribe"],"properties":{"unsubscribe":{"$ref":"https://transit.invalid/generated-validator/79"}}};
const schema115 = {"type":"object","additionalProperties":false,"properties":{"identity":{"$ref":"https://transit.invalid/generated-validator/72"},"subscription":{"$ref":"https://transit.invalid/generated-validator/1"},"generation":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["identity","subscription","generation"]};

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
if((((data.identity === undefined) && (missing0 = "identity")) || ((data.subscription === undefined) && (missing0 = "subscription"))) || ((data.generation === undefined) && (missing0 = "generation"))){
validate404.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "identity") || (key0 === "subscription")) || (key0 === "generation"))){
validate404.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.identity !== undefined){
const _errs2 = errors;
if(!(validate380(data.identity, {instancePath:instancePath+"/identity",parentData:data,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate380.errors : vErrors.concat(validate380.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.subscription !== undefined){
const _errs3 = errors;
if(!(validate56(data.subscription, {instancePath:instancePath+"/subscription",parentData:data,parentDataProperty:"subscription",rootData,dynamicAnchors}))){
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
}
}
}
}
}
else {
validate404.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
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
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.unsubscribe === undefined) && (missing0 = "unsubscribe")){
validate403.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "unsubscribe")){
validate403.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.unsubscribe !== undefined){
if(!(validate404(data.unsubscribe, {instancePath:instancePath+"/unsubscribe",parentData:data,parentDataProperty:"unsubscribe",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate404.errors : vErrors.concat(validate404.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate403.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate403.errors = vErrors;
return errors === 0;
}
validate403.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema116 = {"type":"object","additionalProperties":false,"required":["close"],"properties":{"close":{"$ref":"https://transit.invalid/generated-validator/72"}}};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.close === undefined) && (missing0 = "close")){
validate410.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "close")){
validate410.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.close !== undefined){
if(!(validate380(data.close, {instancePath:instancePath+"/close",parentData:data,parentDataProperty:"close",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate380.errors : vErrors.concat(validate380.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate410.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate410.errors = vErrors;
return errors === 0;
}
validate410.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
let passing0 = null;
const _errs1 = errors;
if(!(validate371(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate371.errors : vErrors.concat(validate371.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs2 = errors;
if(!(validate378(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate378.errors : vErrors.concat(validate378.errors);
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
if(!(validate388(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate388.errors : vErrors.concat(validate388.errors);
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
if(!(validate396(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate396.errors : vErrors.concat(validate396.errors);
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
if(!(validate403(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate403.errors : vErrors.concat(validate403.errors);
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
if(!(validate410(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate410.errors : vErrors.concat(validate410.errors);
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
const err0 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0}};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
validate370.errors = vErrors;
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
validate370.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate370.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema117 = {"oneOf":[{"$ref":"https://transit.invalid/generated-validator/85"},{"$ref":"https://transit.invalid/generated-validator/87"},{"$ref":"https://transit.invalid/generated-validator/89"},{"$ref":"https://transit.invalid/generated-validator/90"}]};
const schema118 = {"type":"object","additionalProperties":false,"required":["follow"],"properties":{"follow":{"$ref":"https://transit.invalid/generated-validator/84"}}};
const schema119 = {"type":"object","additionalProperties":false,"properties":{"session":{"$ref":"https://transit.invalid/generated-validator/72"},"expected":{"$ref":"https://transit.invalid/generated-validator/1"},"template":{"$ref":"https://transit.invalid/generated-validator/44"},"captures":{"$ref":"https://transit.invalid/generated-validator/83"},"limit":{"$ref":"https://transit.invalid/generated-validator/3"}},"required":["session","expected","template","captures","limit"]};
const schema120 = {"type":"array","minItems":8,"maxItems":8,"items":{"$ref":"https://transit.invalid/generated-validator/44"}};

function validate424(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate424.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 8){
validate424.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 8}}];
return false;
}
else {
if(data.length < 8){
validate424.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 8}}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate225(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
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
validate424.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
return false;
}
}
validate424.errors = vErrors;
return errors === 0;
}
validate424.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.session === undefined) && (missing0 = "session")) || ((data.expected === undefined) && (missing0 = "expected"))) || ((data.template === undefined) && (missing0 = "template"))) || ((data.captures === undefined) && (missing0 = "captures"))) || ((data.limit === undefined) && (missing0 = "limit"))){
validate420.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "session") || (key0 === "expected")) || (key0 === "template")) || (key0 === "captures")) || (key0 === "limit"))){
validate420.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.session !== undefined){
const _errs2 = errors;
if(!(validate380(data.session, {instancePath:instancePath+"/session",parentData:data,parentDataProperty:"session",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate380.errors : vErrors.concat(validate380.errors);
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
if(!(validate56(data.expected, {instancePath:instancePath+"/expected",parentData:data,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.template !== undefined){
const _errs4 = errors;
if(!(validate225(data.template, {instancePath:instancePath+"/template",parentData:data,parentDataProperty:"template",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.captures !== undefined){
const _errs5 = errors;
if(!(validate424(data.captures, {instancePath:instancePath+"/captures",parentData:data,parentDataProperty:"captures",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate424.errors : vErrors.concat(validate424.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.limit !== undefined){
const _errs6 = errors;
if(!(validate65(data.limit, {instancePath:instancePath+"/limit",parentData:data,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
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
validate420.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate420.errors = vErrors;
return errors === 0;
}
validate420.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate419(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate419.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.follow === undefined) && (missing0 = "follow")){
validate419.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "follow")){
validate419.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.follow !== undefined){
if(!(validate420(data.follow, {instancePath:instancePath+"/follow",parentData:data,parentDataProperty:"follow",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate420.errors : vErrors.concat(validate420.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate419.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate419.errors = vErrors;
return errors === 0;
}
validate419.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema121 = {"type":"object","additionalProperties":false,"required":["invalidate"],"properties":{"invalidate":{"$ref":"https://transit.invalid/generated-validator/86"}}};
const schema122 = {"type":"object","additionalProperties":false,"properties":{"session":{"$ref":"https://transit.invalid/generated-validator/72"},"generation":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["session","generation"]};

function validate431(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate431.evaluated;
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
validate431.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "session") || (key0 === "generation"))){
validate431.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.session !== undefined){
const _errs2 = errors;
if(!(validate380(data.session, {instancePath:instancePath+"/session",parentData:data,parentDataProperty:"session",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate380.errors : vErrors.concat(validate380.errors);
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
validate431.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate431.errors = vErrors;
return errors === 0;
}
validate431.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if((data.invalidate === undefined) && (missing0 = "invalidate")){
validate430.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "invalidate")){
validate430.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.invalidate !== undefined){
if(!(validate431(data.invalidate, {instancePath:instancePath+"/invalidate",parentData:data,parentDataProperty:"invalidate",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate431.errors : vErrors.concat(validate431.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate430.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate430.errors = vErrors;
return errors === 0;
}
validate430.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema123 = {"type":"object","additionalProperties":false,"required":["acknowledged"],"properties":{"acknowledged":{"$ref":"https://transit.invalid/generated-validator/88"}}};
const schema124 = {"type":"object","additionalProperties":false,"properties":{"selection":{"$ref":"https://transit.invalid/generated-validator/86"},"namespace":{"$ref":"https://transit.invalid/generated-validator/44"}},"required":["selection","namespace"]};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.selection === undefined) && (missing0 = "selection")) || ((data.namespace === undefined) && (missing0 = "namespace"))){
validate437.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "selection") || (key0 === "namespace"))){
validate437.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.selection !== undefined){
const _errs2 = errors;
if(!(validate431(data.selection, {instancePath:instancePath+"/selection",parentData:data,parentDataProperty:"selection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate431.errors : vErrors.concat(validate431.errors);
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
if(!(validate225(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
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
validate437.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate437.errors = vErrors;
return errors === 0;
}
validate437.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if((data.acknowledged === undefined) && (missing0 = "acknowledged")){
validate436.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "acknowledged")){
validate436.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.acknowledged !== undefined){
if(!(validate437(data.acknowledged, {instancePath:instancePath+"/acknowledged",parentData:data,parentDataProperty:"acknowledged",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate437.errors : vErrors.concat(validate437.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate436.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate436.errors = vErrors;
return errors === 0;
}
validate436.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema125 = {"type":"object","additionalProperties":false,"required":["pause"],"properties":{"pause":{"$ref":"https://transit.invalid/generated-validator/86"}}};

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
if((data.pause === undefined) && (missing0 = "pause")){
validate442.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "pause")){
validate442.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.pause !== undefined){
if(!(validate431(data.pause, {instancePath:instancePath+"/pause",parentData:data,parentDataProperty:"pause",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate431.errors : vErrors.concat(validate431.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate442.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate442.errors = vErrors;
return errors === 0;
}
validate442.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate418(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate418.evaluated;
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
if(!(validate419(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate419.errors : vErrors.concat(validate419.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs2 = errors;
if(!(validate430(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate430.errors : vErrors.concat(validate430.errors);
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
if(!(validate436(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate436.errors : vErrors.concat(validate436.errors);
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
if(!(validate442(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate442.errors : vErrors.concat(validate442.errors);
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
}
}
}
if(!valid0){
const err0 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0}};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
validate418.errors = vErrors;
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
validate418.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate418.evaluated = {"dynamicProps":true,"dynamicItems":false};


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
const err0 = {instancePath,schemaPath:"#/oneOf/0/required",keyword:"required",params:{missingProperty: missing0}};
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
const err1 = {instancePath,schemaPath:"#/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}};
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
const err2 = {instancePath:instancePath+"/describe",schemaPath:"#/oneOf/0/properties/describe/maxProperties",keyword:"maxProperties",params:{limit: 0}};
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
const err3 = {instancePath:instancePath+"/describe",schemaPath:"#/oneOf/0/properties/describe/type",keyword:"type",params:{type: "object"}};
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
const err4 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"}};
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
const err5 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1}};
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
const err6 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1}};
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
const err7 = {instancePath:instancePath+"/clock",schemaPath:"#/oneOf/1/properties/clock/maxProperties",keyword:"maxProperties",params:{limit: 0}};
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
const err8 = {instancePath:instancePath+"/clock",schemaPath:"#/oneOf/1/properties/clock/type",keyword:"type",params:{type: "object"}};
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
const err9 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"}};
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
const err10 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2}};
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
const err11 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2}};
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
const err12 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"}};
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
const err13 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3}};
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
const err14 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3}};
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
const err15 = {instancePath:instancePath+"/covered",schemaPath:"#/oneOf/3/properties/covered/required",keyword:"required",params:{missingProperty: missing4}};
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
const err16 = {instancePath:instancePath+"/covered",schemaPath:"#/oneOf/3/properties/covered/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4}};
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
const err17 = {instancePath:instancePath+"/covered",schemaPath:"#/oneOf/3/properties/covered/type",keyword:"type",params:{type: "object"}};
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
const err18 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"}};
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
const err19 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing5}};
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
const err20 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5}};
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
if(!(validate370(data.prepare, {instancePath:instancePath+"/prepare",parentData:data,parentDataProperty:"prepare",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate370.errors : vErrors.concat(validate370.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err21 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
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
const _errs27 = errors;
if(errors === _errs27){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing6;
if((data.submit === undefined) && (missing6 = "submit")){
const err22 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing6}};
if(vErrors === null){
vErrors = [err22];
}
else {
vErrors.push(err22);
}
errors++;
}
else {
const _errs29 = errors;
for(const key6 in data){
if(!(key6 === "submit")){
const err23 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6}};
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
if(_errs29 === errors){
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
const err24 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
}
errors++;
}
}
var _valid0 = _errs27 === errors;
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
const _errs31 = errors;
if(errors === _errs31){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing7;
if((data.observe === undefined) && (missing7 = "observe")){
const err25 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing7}};
if(vErrors === null){
vErrors = [err25];
}
else {
vErrors.push(err25);
}
errors++;
}
else {
const _errs33 = errors;
for(const key7 in data){
if(!(key7 === "observe")){
const err26 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7}};
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
if(_errs33 === errors){
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
const err27 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err27];
}
else {
vErrors.push(err27);
}
errors++;
}
}
var _valid0 = _errs31 === errors;
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
const _errs35 = errors;
if(errors === _errs35){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing8;
if((data.recover_control === undefined) && (missing8 = "recover_control")){
const err28 = {instancePath,schemaPath:"#/oneOf/7/required",keyword:"required",params:{missingProperty: missing8}};
if(vErrors === null){
vErrors = [err28];
}
else {
vErrors.push(err28);
}
errors++;
}
else {
const _errs37 = errors;
for(const key8 in data){
if(!(key8 === "recover_control")){
const err29 = {instancePath,schemaPath:"#/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8}};
if(vErrors === null){
vErrors = [err29];
}
else {
vErrors.push(err29);
}
errors++;
break;
}
}
if(_errs37 === errors){
if(data.recover_control !== undefined){
if(!(validate308(data.recover_control, {instancePath:instancePath+"/recover_control",parentData:data,parentDataProperty:"recover_control",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate308.errors : vErrors.concat(validate308.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err30 = {instancePath,schemaPath:"#/oneOf/7/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
}
errors++;
}
}
var _valid0 = _errs35 === errors;
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
const _errs39 = errors;
if(errors === _errs39){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing9;
if((data.sign_read === undefined) && (missing9 = "sign_read")){
const err31 = {instancePath,schemaPath:"#/oneOf/8/required",keyword:"required",params:{missingProperty: missing9}};
if(vErrors === null){
vErrors = [err31];
}
else {
vErrors.push(err31);
}
errors++;
}
else {
const _errs41 = errors;
for(const key9 in data){
if(!(key9 === "sign_read")){
const err32 = {instancePath,schemaPath:"#/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9}};
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
if(_errs41 === errors){
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
const err33 = {instancePath,schemaPath:"#/oneOf/8/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
}
var _valid0 = _errs39 === errors;
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
const _errs43 = errors;
if(errors === _errs43){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing10;
if((data.refresh_prepare === undefined) && (missing10 = "refresh_prepare")){
const err34 = {instancePath,schemaPath:"#/oneOf/9/required",keyword:"required",params:{missingProperty: missing10}};
if(vErrors === null){
vErrors = [err34];
}
else {
vErrors.push(err34);
}
errors++;
}
else {
const _errs45 = errors;
for(const key10 in data){
if(!(key10 === "refresh_prepare")){
const err35 = {instancePath,schemaPath:"#/oneOf/9/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10}};
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
if(_errs45 === errors){
if(data.refresh_prepare !== undefined){
if(!(validate418(data.refresh_prepare, {instancePath:instancePath+"/refresh_prepare",parentData:data,parentDataProperty:"refresh_prepare",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate418.errors : vErrors.concat(validate418.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err36 = {instancePath,schemaPath:"#/oneOf/9/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
}
}
var _valid0 = _errs43 === errors;
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
const _errs47 = errors;
if(errors === _errs47){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing11;
if((data.refresh_status === undefined) && (missing11 = "refresh_status")){
const err37 = {instancePath,schemaPath:"#/oneOf/10/required",keyword:"required",params:{missingProperty: missing11}};
if(vErrors === null){
vErrors = [err37];
}
else {
vErrors.push(err37);
}
errors++;
}
else {
const _errs49 = errors;
for(const key11 in data){
if(!(key11 === "refresh_status")){
const err38 = {instancePath,schemaPath:"#/oneOf/10/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11}};
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
if(_errs49 === errors){
if(data.refresh_status !== undefined){
if(!(validate431(data.refresh_status, {instancePath:instancePath+"/refresh_status",parentData:data,parentDataProperty:"refresh_status",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate431.errors : vErrors.concat(validate431.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err39 = {instancePath,schemaPath:"#/oneOf/10/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err39];
}
else {
vErrors.push(err39);
}
errors++;
}
}
var _valid0 = _errs47 === errors;
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
}
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
const err40 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0}};
if(vErrors === null){
vErrors = [err40];
}
else {
vErrors.push(err40);
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

export const HostResponse = validate447;
const schema126 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["description"],"properties":{"description":{"type":"object","additionalProperties":false,"properties":{"connection":{"$ref":"https://transit.invalid/generated-validator/92"},"discovery":{"$ref":"https://transit.invalid/generated-validator/93"},"observed_ms":{"$ref":"https://transit.invalid/generated-validator/1"},"max_lease_ms":{"$ref":"https://transit.invalid/generated-validator/67"}},"required":["connection","discovery","observed_ms"]}}},{"type":"object","additionalProperties":false,"required":["clock"],"properties":{"clock":{"type":"object","additionalProperties":false,"properties":{"observed_ms":{"$ref":"https://transit.invalid/generated-validator/1"},"max_lease_ms":{"$ref":"https://transit.invalid/generated-validator/67"}},"required":["observed_ms"]}}},{"type":"object","additionalProperties":false,"required":["inspection"],"properties":{"inspection":{"type":"object","additionalProperties":false,"properties":{"response":{"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"session":{"$ref":"https://transit.invalid/generated-validator/50"},"source":{"$ref":"https://transit.invalid/generated-validator/52"},"snapshot":{"$ref":"https://transit.invalid/generated-validator/65"},"event":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"source_changed":{"type":"boolean"},"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"data_revision":{"$ref":"https://transit.invalid/generated-validator/44"},"outcome":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"operation":{"$ref":"https://transit.invalid/generated-validator/1"},"phase":{"$ref":"https://transit.invalid/generated-validator/36"},"resolution_input":{"$ref":"https://transit.invalid/generated-validator/1"},"diagnostic":{"$ref":"https://transit.invalid/generated-validator/108"}},"required":["resource","operation","phase","resolution_input"]},{"type":"null"}]}},"required":["source_changed","resource","data_revision"]},{"type":"null"}]},"cursor":{"$ref":"https://transit.invalid/generated-validator/47"}},"required":["session"]},"observation":{"$ref":"https://transit.invalid/generated-validator/58"}},"required":["response","observation"]}}},{"type":"object","additionalProperties":false,"required":["covered"],"properties":{"covered":{"type":"boolean"}}},{"type":"object","additionalProperties":false,"required":["prepared"],"properties":{"prepared":{"$ref":"https://transit.invalid/generated-validator/66"}}},{"$ref":"https://transit.invalid/generated-validator/69"},{"type":"object","additionalProperties":false,"required":["observation"],"properties":{"observation":{"oneOf":[{"type":"object","additionalProperties":false,"required":["pending"],"properties":{"pending":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["committed"],"properties":{"committed":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["rejected"],"properties":{"rejected":{"type":"object","additionalProperties":false,"properties":{"record":{"$ref":"https://transit.invalid/generated-validator/39"},"diagnostic":{"$ref":"https://transit.invalid/generated-validator/108"}},"required":["record","diagnostic"]}}}]}}},{"type":"object","additionalProperties":false,"required":["recovered_control"],"properties":{"recovered_control":{"type":"object","additionalProperties":false,"properties":{"connection":{"$ref":"https://transit.invalid/generated-validator/92"},"control":{"oneOf":[{"type":"object","additionalProperties":false,"required":["reactive"],"properties":{"reactive":{"$ref":"https://transit.invalid/generated-validator/82"}}},{"type":"object","additionalProperties":false,"required":["refresh"],"properties":{"refresh":{"$ref":"https://transit.invalid/generated-validator/91"}}}]},"input":{"$ref":"https://transit.invalid/generated-validator/2"}},"required":["connection","control","input"]}}},{"type":"object","additionalProperties":false,"required":["signed_read"],"properties":{"signed_read":{"type":"object","additionalProperties":false,"properties":{"read":{"$ref":"https://transit.invalid/generated-validator/48"},"proof":{"$ref":"https://transit.invalid/generated-validator/109"}},"required":["read","proof"]}}},{"type":"object","additionalProperties":false,"required":["refresh_status"],"properties":{"refresh_status":{"type":"object","additionalProperties":false,"properties":{"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"revision":{"$ref":"https://transit.invalid/generated-validator/1"},"policy_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"view":{"type":"object","additionalProperties":false,"properties":{"principal":{"$ref":"https://transit.invalid/generated-validator/1"},"session":{"$ref":"https://transit.invalid/generated-validator/72"},"generation":{"$ref":"https://transit.invalid/generated-validator/1"},"source":{"$ref":"https://transit.invalid/generated-validator/51"},"template":{"$ref":"https://transit.invalid/generated-validator/44"},"namespace":{"$ref":"https://transit.invalid/generated-validator/44"},"dirty":{"$ref":"https://transit.invalid/generated-validator/44"},"covered":{"$ref":"https://transit.invalid/generated-validator/44"},"starts":{"$ref":"https://transit.invalid/generated-validator/3"},"limit":{"$ref":"https://transit.invalid/generated-validator/3"},"next_start_ms":{"$ref":"https://transit.invalid/generated-validator/1"},"enabled":{"type":"boolean"},"phase":{"$ref":"https://transit.invalid/generated-validator/110"},"failure":{"oneOf":[{"$ref":"https://transit.invalid/generated-validator/111"},{"type":"object","additionalProperties":false,"required":["stopped"],"properties":{"stopped":{"type":"object","additionalProperties":false,"properties":{"reason":{"type":"string","enum":["paused","budget_exhausted","session_closed","session_expired","source_changed","binding_unpublished","service_denied","native_denied","query_denied","catalog_denied","resource_unavailable","query_source_unavailable","result_unavailable","result_unpublished","template_invalid","upload_closed","namespace_occupied","query_rejected","query_cancelled","query_retired"]},"input":{"$ref":"https://transit.invalid/generated-validator/1"},"witness":{"oneOf":[{"$ref":"https://transit.invalid/generated-validator/111"},{"type":"object","additionalProperties":false,"required":["revision"],"properties":{"revision":{"type":"object","additionalProperties":false,"properties":{"kind":{"type":"string","enum":["binding","policy","watch","refresh"]},"expected":{"$ref":"https://transit.invalid/generated-validator/1"},"actual":{"$ref":"https://transit.invalid/generated-validator/1"},"proposed":{"$ref":"https://transit.invalid/generated-validator/1"},"present":{"type":"boolean"}},"required":["kind","expected","actual","proposed","present"]}}},{"type":"object","additionalProperties":false,"required":["policy"],"properties":{"policy":{"type":"object","additionalProperties":false,"properties":{"principal":{"$ref":"https://transit.invalid/generated-validator/1"},"revision":{"$ref":"https://transit.invalid/generated-validator/1"},"present":{"type":"boolean"},"commands":{"type":"boolean"},"reads":{"type":"boolean"}},"required":["principal","revision","present","commands","reads"]}}},{"type":"object","additionalProperties":false,"required":["identity"],"properties":{"identity":{"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/4"},"actual":{"$ref":"https://transit.invalid/generated-validator/4"}},"required":["expected","actual"]}}},{"type":"object","additionalProperties":false,"required":["capacity"],"properties":{"capacity":{"type":"object","additionalProperties":false,"properties":{"kind":{"type":"string","enum":["service","caller","service_slots","sessions","caller_sessions"]},"actual":{"$ref":"https://transit.invalid/generated-validator/3"},"limit":{"$ref":"https://transit.invalid/generated-validator/3"}},"required":["kind","actual","limit"]}}},{"type":"object","additionalProperties":false,"required":["generation"],"properties":{"generation":{"$ref":"https://transit.invalid/generated-validator/112"}}},{"type":"object","additionalProperties":false,"required":["session"],"properties":{"session":{"type":"object","additionalProperties":false,"properties":{"phase":{"$ref":"https://transit.invalid/generated-validator/49"},"deadline":{"$ref":"https://transit.invalid/generated-validator/1"},"observed":{"$ref":"https://transit.invalid/generated-validator/1"},"clock_known":{"type":"boolean"}},"required":["phase","deadline","observed","clock_known"]}}},{"type":"object","additionalProperties":false,"required":["source"],"properties":{"source":{"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/1"},"actual":{"$ref":"https://transit.invalid/generated-validator/1"},"present":{"type":"boolean"},"published":{"type":"boolean"},"target":{"$ref":"https://transit.invalid/generated-validator/1"},"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"metadata":{"$ref":"https://transit.invalid/generated-validator/4"}},"required":["expected","actual","present","published","target","resource","metadata"]}}},{"type":"object","additionalProperties":false,"required":["lease"],"properties":{"lease":{"type":"object","additionalProperties":false,"properties":{"kind":{"type":"string","enum":["clock","interval","binding","process","resource","observer"]},"requested":{"$ref":"https://transit.invalid/generated-validator/1"},"observed":{"$ref":"https://transit.invalid/generated-validator/1"},"limit":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["kind","requested","observed","limit"]}}},{"type":"object","additionalProperties":false,"required":["attachment"],"properties":{"attachment":{"$ref":"https://transit.invalid/generated-validator/112"}}},{"type":"object","additionalProperties":false,"required":["subscription"],"properties":{"subscription":{"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/1"},"actual":{"$ref":"https://transit.invalid/generated-validator/1"},"requested":{"$ref":"https://transit.invalid/generated-validator/1"},"active":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["expected","actual","requested","active"]}}},{"type":"object","additionalProperties":false,"required":["renewal"],"properties":{"renewal":{"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/1"},"actual":{"$ref":"https://transit.invalid/generated-validator/1"},"proposed":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["expected","actual","proposed"]}}},{"type":"object","additionalProperties":false,"required":["binding"],"properties":{"binding":{"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/1"},"actual":{"$ref":"https://transit.invalid/generated-validator/1"},"expected_codec":{"$ref":"https://transit.invalid/generated-validator/35"},"actual_codec":{"$ref":"https://transit.invalid/generated-validator/35"},"target":{"$ref":"https://transit.invalid/generated-validator/1"},"present":{"type":"boolean"},"published":{"type":"boolean"}},"required":["expected","actual","expected_codec","actual_codec","target","present","published"]}}},{"type":"object","additionalProperties":false,"required":["refresh"],"properties":{"refresh":{"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/44"},"actual":{"$ref":"https://transit.invalid/generated-validator/44"},"phase":{"$ref":"https://transit.invalid/generated-validator/110"}},"required":["expected","actual","phase"]}}},{"type":"object","additionalProperties":false,"required":["frame"],"properties":{"frame":{"type":"object","additionalProperties":false,"properties":{"correlation":{"$ref":"https://transit.invalid/generated-validator/1"},"expected":{"$ref":"https://transit.invalid/generated-validator/1"},"actual":{"$ref":"https://transit.invalid/generated-validator/1"},"kind":{"type":"string","enum":["reply_source","observer","timer","administrator"]},"actual_known":{"type":"boolean"}},"required":["correlation","expected","actual","kind"]}}},{"type":"object","additionalProperties":false,"required":["target"],"properties":{"target":{"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/1"},"actual":{"$ref":"https://transit.invalid/generated-validator/1"},"kind":{"type":"string","enum":["source","resource","partition"]}},"required":["expected","actual","kind"]}}},{"type":"object","additionalProperties":false,"required":["basis"],"properties":{"basis":{"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/4"},"actual":{"$ref":"https://transit.invalid/generated-validator/4"},"kind":{"type":"string","enum":["schema","contract","metadata"]}},"required":["expected","actual","kind"]}}},{"type":"object","additionalProperties":false,"required":["source_kind"],"properties":{"source_kind":{"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/113"},"actual":{"$ref":"https://transit.invalid/generated-validator/113"}},"required":["expected","actual"]}}},{"type":"object","additionalProperties":false,"required":["table"],"properties":{"table":{"$ref":"https://transit.invalid/generated-validator/44"}}},{"type":"object","additionalProperties":false,"required":["watch_type"],"properties":{"watch_type":{"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/114"},"actual":{"$ref":"https://transit.invalid/generated-validator/114"},"column":{"$ref":"https://transit.invalid/generated-validator/3"}},"required":["expected","actual"]}}},{"type":"object","additionalProperties":false,"required":["progress"],"properties":{"progress":{"type":"object","additionalProperties":false,"properties":{"present":{"type":"boolean"},"actual":{"$ref":"https://transit.invalid/generated-validator/1"},"limit":{"$ref":"https://transit.invalid/generated-validator/1"},"key":{"$ref":"https://transit.invalid/generated-validator/4"},"length":{"$ref":"https://transit.invalid/generated-validator/3"}},"required":["present","actual","limit","key","length"]}}},{"type":"object","additionalProperties":false,"required":["reader_identity"],"properties":{"reader_identity":{"type":"object","additionalProperties":false,"properties":{"field":{"type":"string","enum":["principal","pid","permissions","turn_pid"]},"expected":{"$ref":"https://transit.invalid/generated-validator/1"},"actual":{"$ref":"https://transit.invalid/generated-validator/1"},"present":{"type":"boolean"},"policy_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"policy_known":{"type":"boolean"}},"required":["field","expected","actual"]}}},{"type":"object","additionalProperties":false,"required":["reader_failure"],"properties":{"reader_failure":{"type":"object","additionalProperties":false,"properties":{"operation":{"type":"string","enum":["identity","source","requester","result"]},"principal":{"$ref":"https://transit.invalid/generated-validator/1"},"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"namespace":{"$ref":"https://transit.invalid/generated-validator/1"},"cause":{"type":"string","enum":["AccessDenied","Forbidden","StateResourceExpired","UnknownStateResource","DeadlineExpired","RetiredProcess","CatalogDenied","QueryDenied","QuerySourceUnavailable","ResultUnavailable","PublicationNotPublished"]}},"required":["operation","principal","resource","cause"]}}},{"type":"object","additionalProperties":false,"required":["reader_resource"],"properties":{"reader_resource":{"type":"object","additionalProperties":false,"properties":{"role":{"type":"string","enum":["source","requester"]},"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"expected_writer":{"$ref":"https://transit.invalid/generated-validator/1"},"actual_writer":{"$ref":"https://transit.invalid/generated-validator/1"},"phase":{"type":"string","enum":["active","retired","reclaimed"]},"writer_check":{"type":"boolean"},"revision":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["role","resource","expected_writer","actual_writer","phase","writer_check","revision"]}}},{"type":"object","additionalProperties":false,"required":["watch_shape"],"properties":{"watch_shape":{"type":"object","additionalProperties":false,"properties":{"columns":{"$ref":"https://transit.invalid/generated-validator/3"},"first_nullable":{"type":"boolean"},"primary_columns":{"$ref":"https://transit.invalid/generated-validator/3"},"primary_first":{"type":"boolean"}},"required":["columns","first_nullable","primary_columns","primary_first"]}}},{"type":"object","additionalProperties":false,"required":["reader_template"],"properties":{"reader_template":{"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"https://transit.invalid/generated-validator/1"},"present":{"type":"boolean"},"phase":{"type":"string","enum":["uploading","sealed","admitted","complete","cancelled","denied","rejected","retired","prepared"]},"manifest":{"type":"boolean"}},"required":["namespace","present"]}}}]}},"required":["reason","input"]}}}]}},"required":["principal","session","generation","source","template","namespace","dirty","covered","limit"]},"diagnostic":{"$ref":"https://transit.invalid/generated-validator/108"},"query_diagnostic":{"$ref":"https://transit.invalid/generated-validator/108"}},"required":["resource","revision","policy_revision","view"]}}}]};
const schema127 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"principal":{"$ref":"https://transit.invalid/generated-validator/1"},"service":{"$ref":"https://transit.invalid/generated-validator/1"},"ingress":{"$ref":"https://transit.invalid/generated-validator/1"},"role":{"$ref":"https://transit.invalid/generated-validator/2"}},"required":["realm","principal","service","ingress"]};

function validate448(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate448.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.realm === undefined) && (missing0 = "realm")) || ((data.principal === undefined) && (missing0 = "principal"))) || ((data.service === undefined) && (missing0 = "service"))) || ((data.ingress === undefined) && (missing0 = "ingress"))){
validate448.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "realm") || (key0 === "principal")) || (key0 === "service")) || (key0 === "ingress")) || (key0 === "role"))){
validate448.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
}
}
}
}
}
}
}
else {
validate448.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate448.errors = vErrors;
return errors === 0;
}
validate448.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema128 = {"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"service":{"$ref":"https://transit.invalid/generated-validator/1"},"ingress":{"$ref":"https://transit.invalid/generated-validator/1"},"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"binding_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"watch_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"sse":{"type":"boolean"},"websocket":{"type":"boolean"},"subprotocol":{"type":"string","maxLength":256},"openapi_sha256":{"$ref":"https://transit.invalid/generated-validator/4"},"asyncapi_sha256":{"$ref":"https://transit.invalid/generated-validator/4"}},"required":["service","ingress","resource","binding_revision","watch_revision","openapi_sha256","asyncapi_sha256"]};

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
if((((((((data.service === undefined) && (missing0 = "service")) || ((data.ingress === undefined) && (missing0 = "ingress"))) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.binding_revision === undefined) && (missing0 = "binding_revision"))) || ((data.watch_revision === undefined) && (missing0 = "watch_revision"))) || ((data.openapi_sha256 === undefined) && (missing0 = "openapi_sha256"))) || ((data.asyncapi_sha256 === undefined) && (missing0 = "asyncapi_sha256"))){
validate455.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema128.properties, key0))){
validate455.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate455.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1}}];
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
validate455.errors = [{instancePath:instancePath+"/sse",schemaPath:"#/properties/sse/type",keyword:"type",params:{type: "boolean"}}];
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
validate455.errors = [{instancePath:instancePath+"/websocket",schemaPath:"#/properties/websocket/type",keyword:"type",params:{type: "boolean"}}];
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
validate455.errors = [{instancePath:instancePath+"/subprotocol",schemaPath:"#/properties/subprotocol/maxLength",keyword:"maxLength",params:{limit: 256}}];
return false;
}
}
else {
validate455.errors = [{instancePath:instancePath+"/subprotocol",schemaPath:"#/properties/subprotocol/type",keyword:"type",params:{type: "string"}}];
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
validate455.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate455.errors = vErrors;
return errors === 0;
}
validate455.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema129 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/107"},{"type":"null"}]};
const schema130 = {"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"definition":{"$ref":"https://transit.invalid/generated-validator/0"},"code":{"type":"string","maxLength":96},"category":{"$ref":"https://transit.invalid/generated-validator/7"},"stage":{"$ref":"https://transit.invalid/generated-validator/8"},"outcome":{"$ref":"https://transit.invalid/generated-validator/9"},"evidence":{"$ref":"https://transit.invalid/generated-validator/10"},"message":{"type":"string","maxLength":384},"cause":{"$ref":"https://transit.invalid/generated-validator/11"},"identity":{"$ref":"https://transit.invalid/generated-validator/95"},"location":{"$ref":"https://transit.invalid/generated-validator/97"},"facts":{"$ref":"https://transit.invalid/generated-validator/103"},"actions":{"$ref":"https://transit.invalid/generated-validator/106"}},"required":["version","definition","code","category","stage","outcome","evidence","message"]};
const schema131 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/94"},{"type":"null"}]};
const schema132 = {"type":"object","additionalProperties":false,"properties":{"domain":{"$ref":"https://transit.invalid/generated-validator/12"},"id":{"$ref":"https://transit.invalid/generated-validator/13"},"realm":{"$ref":"https://transit.invalid/generated-validator/14"},"resource":{"$ref":"https://transit.invalid/generated-validator/14"},"sequence":{"$ref":"https://transit.invalid/generated-validator/14"}},"required":["domain","id"]};

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
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.domain === undefined) && (missing0 = "domain")) || ((data.id === undefined) && (missing0 = "id"))){
validate486.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "domain") || (key0 === "id")) || (key0 === "realm")) || (key0 === "resource")) || (key0 === "sequence"))){
validate486.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate486.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate486.errors = vErrors;
return errors === 0;
}
validate486.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate486(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate486.errors : vErrors.concat(validate486.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
if(_valid0){
var props0 = true;
}
const _errs2 = errors;
if(data !== null){
const err0 = {instancePath,schemaPath:"#/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err1 = {instancePath,schemaPath:"#/anyOf",keyword:"anyOf",params:{}};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate485.errors = vErrors;
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
validate485.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate485.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema133 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/96"},{"type":"null"}]};
const schema134 = {"type":"object","additionalProperties":false,"properties":{"source":{"$ref":"https://transit.invalid/generated-validator/17"},"source_encoding":{"$ref":"https://transit.invalid/generated-validator/18"},"source_truncated":{"type":"boolean"},"statement":{"$ref":"https://transit.invalid/generated-validator/14"},"offset":{"$ref":"https://transit.invalid/generated-validator/13"},"length":{"$ref":"https://transit.invalid/generated-validator/13"},"line":{"$ref":"https://transit.invalid/generated-validator/13"},"byte_column":{"$ref":"https://transit.invalid/generated-validator/13"}},"required":["offset","length","line","byte_column"]};

function validate495(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate495.evaluated;
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
validate495.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "source") || (key0 === "source_encoding")) || (key0 === "source_truncated")) || (key0 === "statement")) || (key0 === "offset")) || (key0 === "length")) || (key0 === "line")) || (key0 === "byte_column"))){
validate495.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate495.errors = [{instancePath:instancePath+"/source_truncated",schemaPath:"#/properties/source_truncated/type",keyword:"type",params:{type: "boolean"}}];
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
validate495.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate495.errors = vErrors;
return errors === 0;
}
validate495.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate494(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate494.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate495(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate495.errors : vErrors.concat(validate495.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
if(_valid0){
var props0 = true;
}
const _errs2 = errors;
if(data !== null){
const err0 = {instancePath,schemaPath:"#/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err1 = {instancePath,schemaPath:"#/anyOf",keyword:"anyOf",params:{}};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate494.errors = vErrors;
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
validate494.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate494.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema135 = {"type":"array","minItems":16,"maxItems":16,"items":{"$ref":"https://transit.invalid/generated-validator/102"}};
const schema136 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/101"},{"type":"null"}]};
const schema137 = {"type":"object","additionalProperties":false,"properties":{"field":{"$ref":"https://transit.invalid/generated-validator/20"},"origin":{"$ref":"https://transit.invalid/generated-validator/21"},"availability":{"$ref":"https://transit.invalid/generated-validator/22"},"value":{"$ref":"https://transit.invalid/generated-validator/100"}},"required":["field","origin","availability","value"]};
const schema138 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/99"},{"type":"null"}]};
const schema139 = {"oneOf":[{"$ref":"https://transit.invalid/generated-validator/23"},{"$ref":"https://transit.invalid/generated-validator/25"},{"$ref":"https://transit.invalid/generated-validator/26"},{"$ref":"https://transit.invalid/generated-validator/27"},{"$ref":"https://transit.invalid/generated-validator/28"},{"$ref":"https://transit.invalid/generated-validator/98"}]};
const schema140 = {"type":"object","additionalProperties":false,"required":["location"],"properties":{"location":{"$ref":"https://transit.invalid/generated-validator/96"}}};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.location === undefined) && (missing0 = "location")){
validate518.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "location")){
validate518.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.location !== undefined){
if(!(validate495(data.location, {instancePath:instancePath+"/location",parentData:data,parentDataProperty:"location",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate495.errors : vErrors.concat(validate495.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate518.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate518.errors = vErrors;
return errors === 0;
}
validate518.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate512(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate512.evaluated;
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
if(!(validate518(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate518.errors : vErrors.concat(validate518.errors);
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
const err0 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0}};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
validate512.errors = vErrors;
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
validate512.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate512.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate511(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate511.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate512(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate512.errors : vErrors.concat(validate512.errors);
errors = vErrors.length;
}
else {
var props0 = validate512.evaluated.props;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
const _errs2 = errors;
if(data !== null){
const err0 = {instancePath,schemaPath:"#/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err1 = {instancePath,schemaPath:"#/anyOf",keyword:"anyOf",params:{}};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate511.errors = vErrors;
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
validate511.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate511.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate507(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate507.evaluated;
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
validate507.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "field") || (key0 === "origin")) || (key0 === "availability")) || (key0 === "value"))){
validate507.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
if(!(validate511(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate511.errors : vErrors.concat(validate511.errors);
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
validate507.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate507.errors = vErrors;
return errors === 0;
}
validate507.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate506(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate506.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate507(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate507.errors : vErrors.concat(validate507.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
if(_valid0){
var props0 = true;
}
const _errs2 = errors;
if(data !== null){
const err0 = {instancePath,schemaPath:"#/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err1 = {instancePath,schemaPath:"#/anyOf",keyword:"anyOf",params:{}};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate506.errors = vErrors;
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
validate506.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate506.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate505(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate505.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 16){
validate505.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 16}}];
return false;
}
else {
if(data.length < 16){
validate505.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 16}}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate506(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate506.errors : vErrors.concat(validate506.errors);
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
validate505.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
return false;
}
}
validate505.errors = vErrors;
return errors === 0;
}
validate505.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema141 = {"type":"array","minItems":4,"maxItems":4,"items":{"$ref":"https://transit.invalid/generated-validator/105"}};
const schema142 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/104"},{"type":"null"}]};
const schema143 = {"type":"object","additionalProperties":false,"properties":{"kind":{"$ref":"https://transit.invalid/generated-validator/29"},"target":{"$ref":"https://transit.invalid/generated-validator/95"}},"required":["kind"]};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.kind === undefined) && (missing0 = "kind")){
validate528.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "kind") || (key0 === "target"))){
validate528.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
if(!(validate485(data.target, {instancePath:instancePath+"/target",parentData:data,parentDataProperty:"target",rootData,dynamicAnchors}))){
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
validate528.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate528.errors = vErrors;
return errors === 0;
}
validate528.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate527(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate527.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate528(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate528.errors : vErrors.concat(validate528.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
if(_valid0){
var props0 = true;
}
const _errs2 = errors;
if(data !== null){
const err0 = {instancePath,schemaPath:"#/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err1 = {instancePath,schemaPath:"#/anyOf",keyword:"anyOf",params:{}};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate527.errors = vErrors;
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
validate527.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate527.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate526(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate526.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 4){
validate526.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 4}}];
return false;
}
else {
if(data.length < 4){
validate526.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 4}}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate527(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate527.errors : vErrors.concat(validate527.errors);
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
validate526.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
return false;
}
}
validate526.errors = vErrors;
return errors === 0;
}
validate526.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


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
if(((((((((data.version === undefined) && (missing0 = "version")) || ((data.definition === undefined) && (missing0 = "definition"))) || ((data.code === undefined) && (missing0 = "code"))) || ((data.category === undefined) && (missing0 = "category"))) || ((data.stage === undefined) && (missing0 = "stage"))) || ((data.outcome === undefined) && (missing0 = "outcome"))) || ((data.evidence === undefined) && (missing0 = "evidence"))) || ((data.message === undefined) && (missing0 = "message"))){
validate478.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema130.properties, key0))){
validate478.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate478.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1}}];
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
validate478.errors = [{instancePath:instancePath+"/code",schemaPath:"#/properties/code/maxLength",keyword:"maxLength",params:{limit: 96}}];
return false;
}
}
else {
validate478.errors = [{instancePath:instancePath+"/code",schemaPath:"#/properties/code/type",keyword:"type",params:{type: "string"}}];
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
validate478.errors = [{instancePath:instancePath+"/message",schemaPath:"#/properties/message/maxLength",keyword:"maxLength",params:{limit: 384}}];
return false;
}
}
else {
validate478.errors = [{instancePath:instancePath+"/message",schemaPath:"#/properties/message/type",keyword:"type",params:{type: "string"}}];
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
if(!(validate485(data.identity, {instancePath:instancePath+"/identity",parentData:data,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate485.errors : vErrors.concat(validate485.errors);
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
if(!(validate494(data.location, {instancePath:instancePath+"/location",parentData:data,parentDataProperty:"location",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate494.errors : vErrors.concat(validate494.errors);
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
if(!(validate505(data.facts, {instancePath:instancePath+"/facts",parentData:data,parentDataProperty:"facts",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate505.errors : vErrors.concat(validate505.errors);
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
if(!(validate526(data.actions, {instancePath:instancePath+"/actions",parentData:data,parentDataProperty:"actions",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate526.errors : vErrors.concat(validate526.errors);
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
validate478.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate478.errors = vErrors;
return errors === 0;
}
validate478.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs1 = errors;
if(!(validate478(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate478.errors : vErrors.concat(validate478.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
if(_valid0){
var props0 = true;
}
const _errs2 = errors;
if(data !== null){
const err0 = {instancePath,schemaPath:"#/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err1 = {instancePath,schemaPath:"#/anyOf",keyword:"anyOf",params:{}};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
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

const schema144 = {"type":"object","additionalProperties":false,"properties":{"claim":{"$ref":"https://transit.invalid/generated-validator/5"},"signature":{"$ref":"https://transit.invalid/generated-validator/6"}},"required":["claim","signature"]};

function validate547(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate547.evaluated;
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
validate547.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "claim") || (key0 === "signature"))){
validate547.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate547.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate547.errors = vErrors;
return errors === 0;
}
validate547.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema145 = {"type":"string","enum":["idle","preparing","admitted","ready","paused","denied","exhausted","failed"]};

function validate565(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate565.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate565.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!((((((((data === "idle") || (data === "preparing")) || (data === "admitted")) || (data === "ready")) || (data === "paused")) || (data === "denied")) || (data === "exhausted")) || (data === "failed"))){
validate565.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema145.enum}}];
return false;
}
validate565.errors = vErrors;
return errors === 0;
}
validate565.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema146 = {"type":"object","additionalProperties":false,"required":["none"],"properties":{"none":{"type":"object","maxProperties":0}}};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.none === undefined) && (missing0 = "none")){
validate567.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "none")){
validate567.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate567.errors = [{instancePath:instancePath+"/none",schemaPath:"#/properties/none/maxProperties",keyword:"maxProperties",params:{limit: 0}}];
return false;
}
}
else {
validate567.errors = [{instancePath:instancePath+"/none",schemaPath:"#/properties/none/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
}
}
}
}
else {
validate567.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate567.errors = vErrors;
return errors === 0;
}
validate567.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema147 = {"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"https://transit.invalid/generated-validator/1"},"actual":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["expected","actual"]};

function validate580(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate580.evaluated;
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
validate580.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "expected") || (key0 === "actual"))){
validate580.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
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
validate580.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate580.errors = vErrors;
return errors === 0;
}
validate580.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema148 = {"type":"string","enum":["kv","table","document"]};

function validate618(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate618.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate618.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!(((data === "kv") || (data === "table")) || (data === "document"))){
validate618.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema148.enum}}];
return false;
}
validate618.errors = vErrors;
return errors === 0;
}
validate618.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema149 = {"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary","int8","int16","int32","int128","uint8","uint16","uint32","uint128","float32","decimal","date","time","timestamp","interval","uuid","structure","list","array","map","tagged_union","json"]};

function validate622(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate622.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate622.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!(((((((((((((((((((((((((((data === "int64") || (data === "uint64")) || (data === "float64")) || (data === "boolean")) || (data === "utf8")) || (data === "binary")) || (data === "int8")) || (data === "int16")) || (data === "int32")) || (data === "int128")) || (data === "uint8")) || (data === "uint16")) || (data === "uint32")) || (data === "uint128")) || (data === "float32")) || (data === "decimal")) || (data === "date")) || (data === "time")) || (data === "timestamp")) || (data === "interval")) || (data === "uuid")) || (data === "structure")) || (data === "list")) || (data === "array")) || (data === "map")) || (data === "tagged_union")) || (data === "json"))){
validate622.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema149.enum}}];
return false;
}
validate622.errors = vErrors;
return errors === 0;
}
validate622.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
let passing0 = null;
const _errs1 = errors;
if(errors === _errs1){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.description === undefined) && (missing0 = "description")){
const err0 = {instancePath,schemaPath:"#/oneOf/0/required",keyword:"required",params:{missingProperty: missing0}};
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
const err1 = {instancePath,schemaPath:"#/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}};
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
const err2 = {instancePath:instancePath+"/description",schemaPath:"#/oneOf/0/properties/description/required",keyword:"required",params:{missingProperty: missing1}};
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
const err3 = {instancePath:instancePath+"/description",schemaPath:"#/oneOf/0/properties/description/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1}};
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
const _errs7 = errors;
if(!(validate448(data0.connection, {instancePath:instancePath+"/description/connection",parentData:data0,parentDataProperty:"connection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate448.errors : vErrors.concat(validate448.errors);
errors = vErrors.length;
}
var valid2 = _errs7 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data0.discovery !== undefined){
const _errs8 = errors;
if(!(validate455(data0.discovery, {instancePath:instancePath+"/description/discovery",parentData:data0,parentDataProperty:"discovery",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate455.errors : vErrors.concat(validate455.errors);
errors = vErrors.length;
}
var valid2 = _errs8 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data0.observed_ms !== undefined){
const _errs9 = errors;
if(!(validate56(data0.observed_ms, {instancePath:instancePath+"/description/observed_ms",parentData:data0,parentDataProperty:"observed_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid2 = _errs9 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data0.max_lease_ms !== undefined){
const _errs10 = errors;
if(!(validate324(data0.max_lease_ms, {instancePath:instancePath+"/description/max_lease_ms",parentData:data0,parentDataProperty:"max_lease_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate324.errors : vErrors.concat(validate324.errors);
errors = vErrors.length;
}
var valid2 = _errs10 === errors;
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
const err4 = {instancePath:instancePath+"/description",schemaPath:"#/oneOf/0/properties/description/type",keyword:"type",params:{type: "object"}};
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
const err5 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"}};
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
const _errs11 = errors;
if(errors === _errs11){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing2;
if((data.clock === undefined) && (missing2 = "clock")){
const err6 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing2}};
if(vErrors === null){
vErrors = [err6];
}
else {
vErrors.push(err6);
}
errors++;
}
else {
const _errs13 = errors;
for(const key2 in data){
if(!(key2 === "clock")){
const err7 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2}};
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
if(_errs13 === errors){
if(data.clock !== undefined){
let data5 = data.clock;
const _errs14 = errors;
if(errors === _errs14){
if(data5 && typeof data5 == "object" && !Array.isArray(data5)){
let missing3;
if((data5.observed_ms === undefined) && (missing3 = "observed_ms")){
const err8 = {instancePath:instancePath+"/clock",schemaPath:"#/oneOf/1/properties/clock/required",keyword:"required",params:{missingProperty: missing3}};
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
for(const key3 in data5){
if(!((key3 === "observed_ms") || (key3 === "max_lease_ms"))){
const err9 = {instancePath:instancePath+"/clock",schemaPath:"#/oneOf/1/properties/clock/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3}};
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
if(data5.observed_ms !== undefined){
const _errs17 = errors;
if(!(validate56(data5.observed_ms, {instancePath:instancePath+"/clock/observed_ms",parentData:data5,parentDataProperty:"observed_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid4 = _errs17 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data5.max_lease_ms !== undefined){
const _errs18 = errors;
if(!(validate324(data5.max_lease_ms, {instancePath:instancePath+"/clock/max_lease_ms",parentData:data5,parentDataProperty:"max_lease_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate324.errors : vErrors.concat(validate324.errors);
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
else {
const err10 = {instancePath:instancePath+"/clock",schemaPath:"#/oneOf/1/properties/clock/type",keyword:"type",params:{type: "object"}};
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
const err11 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err11];
}
else {
vErrors.push(err11);
}
errors++;
}
}
var _valid0 = _errs11 === errors;
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
if(errors === _errs19){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing4;
if((data.inspection === undefined) && (missing4 = "inspection")){
const err12 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing4}};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
}
else {
const _errs21 = errors;
for(const key4 in data){
if(!(key4 === "inspection")){
const err13 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4}};
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
if(_errs21 === errors){
if(data.inspection !== undefined){
let data8 = data.inspection;
const _errs22 = errors;
if(errors === _errs22){
if(data8 && typeof data8 == "object" && !Array.isArray(data8)){
let missing5;
if(((data8.response === undefined) && (missing5 = "response")) || ((data8.observation === undefined) && (missing5 = "observation"))){
const err14 = {instancePath:instancePath+"/inspection",schemaPath:"#/oneOf/2/properties/inspection/required",keyword:"required",params:{missingProperty: missing5}};
if(vErrors === null){
vErrors = [err14];
}
else {
vErrors.push(err14);
}
errors++;
}
else {
const _errs24 = errors;
for(const key5 in data8){
if(!((key5 === "response") || (key5 === "observation"))){
const err15 = {instancePath:instancePath+"/inspection",schemaPath:"#/oneOf/2/properties/inspection/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5}};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
break;
}
}
if(_errs24 === errors){
if(data8.response !== undefined){
let data9 = data8.response;
const _errs25 = errors;
if(errors === _errs25){
if(data9 && typeof data9 == "object" && !Array.isArray(data9)){
let missing6;
if((data9.session === undefined) && (missing6 = "session")){
const err16 = {instancePath:instancePath+"/inspection/response",schemaPath:"#/oneOf/2/properties/inspection/properties/response/required",keyword:"required",params:{missingProperty: missing6}};
if(vErrors === null){
vErrors = [err16];
}
else {
vErrors.push(err16);
}
errors++;
}
else {
const _errs27 = errors;
for(const key6 in data9){
if(!((((((key6 === "version") || (key6 === "session")) || (key6 === "source")) || (key6 === "snapshot")) || (key6 === "event")) || (key6 === "cursor"))){
const err17 = {instancePath:instancePath+"/inspection/response",schemaPath:"#/oneOf/2/properties/inspection/properties/response/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6}};
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
if(_errs27 === errors){
if(data9.version !== undefined){
const _errs28 = errors;
if(1 !== data9.version){
const err18 = {instancePath:instancePath+"/inspection/response/version",schemaPath:"#/oneOf/2/properties/inspection/properties/response/properties/version/const",keyword:"const",params:{allowedValue: 1}};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
}
var valid7 = _errs28 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data9.session !== undefined){
const _errs29 = errors;
if(!(validate235(data9.session, {instancePath:instancePath+"/inspection/response/session",parentData:data9,parentDataProperty:"session",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate235.errors : vErrors.concat(validate235.errors);
errors = vErrors.length;
}
var valid7 = _errs29 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data9.source !== undefined){
const _errs30 = errors;
if(!(validate250(data9.source, {instancePath:instancePath+"/inspection/response/source",parentData:data9,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate250.errors : vErrors.concat(validate250.errors);
errors = vErrors.length;
}
var valid7 = _errs30 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data9.snapshot !== undefined){
const _errs31 = errors;
if(!(validate264(data9.snapshot, {instancePath:instancePath+"/inspection/response/snapshot",parentData:data9,parentDataProperty:"snapshot",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate264.errors : vErrors.concat(validate264.errors);
errors = vErrors.length;
}
var valid7 = _errs31 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data9.event !== undefined){
let data14 = data9.event;
const _errs32 = errors;
const _errs33 = errors;
let valid8 = false;
const _errs34 = errors;
if(errors === _errs34){
if(data14 && typeof data14 == "object" && !Array.isArray(data14)){
let missing7;
if((((data14.source_changed === undefined) && (missing7 = "source_changed")) || ((data14.resource === undefined) && (missing7 = "resource"))) || ((data14.data_revision === undefined) && (missing7 = "data_revision"))){
const err19 = {instancePath:instancePath+"/inspection/response/event",schemaPath:"#/oneOf/2/properties/inspection/properties/response/properties/event/anyOf/0/required",keyword:"required",params:{missingProperty: missing7}};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
}
else {
const _errs36 = errors;
for(const key7 in data14){
if(!((((key7 === "source_changed") || (key7 === "resource")) || (key7 === "data_revision")) || (key7 === "outcome"))){
const err20 = {instancePath:instancePath+"/inspection/response/event",schemaPath:"#/oneOf/2/properties/inspection/properties/response/properties/event/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7}};
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
if(_errs36 === errors){
if(data14.source_changed !== undefined){
const _errs37 = errors;
if(typeof data14.source_changed !== "boolean"){
const err21 = {instancePath:instancePath+"/inspection/response/event/source_changed",schemaPath:"#/oneOf/2/properties/inspection/properties/response/properties/event/anyOf/0/properties/source_changed/type",keyword:"type",params:{type: "boolean"}};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
}
errors++;
}
var valid9 = _errs37 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data14.resource !== undefined){
const _errs39 = errors;
if(!(validate56(data14.resource, {instancePath:instancePath+"/inspection/response/event/resource",parentData:data14,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid9 = _errs39 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data14.data_revision !== undefined){
const _errs40 = errors;
if(!(validate225(data14.data_revision, {instancePath:instancePath+"/inspection/response/event/data_revision",parentData:data14,parentDataProperty:"data_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
errors = vErrors.length;
}
var valid9 = _errs40 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data14.outcome !== undefined){
let data18 = data14.outcome;
const _errs41 = errors;
const _errs42 = errors;
let valid10 = false;
const _errs43 = errors;
if(errors === _errs43){
if(data18 && typeof data18 == "object" && !Array.isArray(data18)){
let missing8;
if(((((data18.resource === undefined) && (missing8 = "resource")) || ((data18.operation === undefined) && (missing8 = "operation"))) || ((data18.phase === undefined) && (missing8 = "phase"))) || ((data18.resolution_input === undefined) && (missing8 = "resolution_input"))){
const err22 = {instancePath:instancePath+"/inspection/response/event/outcome",schemaPath:"#/oneOf/2/properties/inspection/properties/response/properties/event/anyOf/0/properties/outcome/anyOf/0/required",keyword:"required",params:{missingProperty: missing8}};
if(vErrors === null){
vErrors = [err22];
}
else {
vErrors.push(err22);
}
errors++;
}
else {
const _errs45 = errors;
for(const key8 in data18){
if(!(((((key8 === "resource") || (key8 === "operation")) || (key8 === "phase")) || (key8 === "resolution_input")) || (key8 === "diagnostic"))){
const err23 = {instancePath:instancePath+"/inspection/response/event/outcome",schemaPath:"#/oneOf/2/properties/inspection/properties/response/properties/event/anyOf/0/properties/outcome/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8}};
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
if(_errs45 === errors){
if(data18.resource !== undefined){
const _errs46 = errors;
if(!(validate56(data18.resource, {instancePath:instancePath+"/inspection/response/event/outcome/resource",parentData:data18,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid11 = _errs46 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data18.operation !== undefined){
const _errs47 = errors;
if(!(validate56(data18.operation, {instancePath:instancePath+"/inspection/response/event/outcome/operation",parentData:data18,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid11 = _errs47 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data18.phase !== undefined){
const _errs48 = errors;
if(!(validate177(data18.phase, {instancePath:instancePath+"/inspection/response/event/outcome/phase",parentData:data18,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate177.errors : vErrors.concat(validate177.errors);
errors = vErrors.length;
}
var valid11 = _errs48 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data18.resolution_input !== undefined){
const _errs49 = errors;
if(!(validate56(data18.resolution_input, {instancePath:instancePath+"/inspection/response/event/outcome/resolution_input",parentData:data18,parentDataProperty:"resolution_input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid11 = _errs49 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data18.diagnostic !== undefined){
const _errs50 = errors;
if(!(validate477(data18.diagnostic, {instancePath:instancePath+"/inspection/response/event/outcome/diagnostic",parentData:data18,parentDataProperty:"diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate477.errors : vErrors.concat(validate477.errors);
errors = vErrors.length;
}
var valid11 = _errs50 === errors;
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
else {
const err24 = {instancePath:instancePath+"/inspection/response/event/outcome",schemaPath:"#/oneOf/2/properties/inspection/properties/response/properties/event/anyOf/0/properties/outcome/anyOf/0/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
}
errors++;
}
}
var _valid2 = _errs43 === errors;
valid10 = valid10 || _valid2;
const _errs51 = errors;
if(data18 !== null){
const err25 = {instancePath:instancePath+"/inspection/response/event/outcome",schemaPath:"#/oneOf/2/properties/inspection/properties/response/properties/event/anyOf/0/properties/outcome/anyOf/1/type",keyword:"type",params:{type: "null"}};
if(vErrors === null){
vErrors = [err25];
}
else {
vErrors.push(err25);
}
errors++;
}
var _valid2 = _errs51 === errors;
valid10 = valid10 || _valid2;
if(!valid10){
const err26 = {instancePath:instancePath+"/inspection/response/event/outcome",schemaPath:"#/oneOf/2/properties/inspection/properties/response/properties/event/anyOf/0/properties/outcome/anyOf",keyword:"anyOf",params:{}};
if(vErrors === null){
vErrors = [err26];
}
else {
vErrors.push(err26);
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
var valid9 = _errs41 === errors;
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
const err27 = {instancePath:instancePath+"/inspection/response/event",schemaPath:"#/oneOf/2/properties/inspection/properties/response/properties/event/anyOf/0/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err27];
}
else {
vErrors.push(err27);
}
errors++;
}
}
var _valid1 = _errs34 === errors;
valid8 = valid8 || _valid1;
const _errs53 = errors;
if(data14 !== null){
const err28 = {instancePath:instancePath+"/inspection/response/event",schemaPath:"#/oneOf/2/properties/inspection/properties/response/properties/event/anyOf/1/type",keyword:"type",params:{type: "null"}};
if(vErrors === null){
vErrors = [err28];
}
else {
vErrors.push(err28);
}
errors++;
}
var _valid1 = _errs53 === errors;
valid8 = valid8 || _valid1;
if(!valid8){
const err29 = {instancePath:instancePath+"/inspection/response/event",schemaPath:"#/oneOf/2/properties/inspection/properties/response/properties/event/anyOf",keyword:"anyOf",params:{}};
if(vErrors === null){
vErrors = [err29];
}
else {
vErrors.push(err29);
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
var valid7 = _errs32 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data9.cursor !== undefined){
const _errs55 = errors;
if(!(validate218(data9.cursor, {instancePath:instancePath+"/inspection/response/cursor",parentData:data9,parentDataProperty:"cursor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate218.errors : vErrors.concat(validate218.errors);
errors = vErrors.length;
}
var valid7 = _errs55 === errors;
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
}
}
else {
const err30 = {instancePath:instancePath+"/inspection/response",schemaPath:"#/oneOf/2/properties/inspection/properties/response/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
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
if(data8.observation !== undefined){
const _errs56 = errors;
if(!(validate266(data8.observation, {instancePath:instancePath+"/inspection/observation",parentData:data8,parentDataProperty:"observation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate266.errors : vErrors.concat(validate266.errors);
errors = vErrors.length;
}
var valid6 = _errs56 === errors;
}
else {
var valid6 = true;
}
}
}
}
}
else {
const err31 = {instancePath:instancePath+"/inspection",schemaPath:"#/oneOf/2/properties/inspection/type",keyword:"type",params:{type: "object"}};
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
const err32 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err32];
}
else {
vErrors.push(err32);
}
errors++;
}
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
const _errs57 = errors;
if(errors === _errs57){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing9;
if((data.covered === undefined) && (missing9 = "covered")){
const err33 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing9}};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
else {
const _errs59 = errors;
for(const key9 in data){
if(!(key9 === "covered")){
const err34 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9}};
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
if(_errs59 === errors){
if(data.covered !== undefined){
if(typeof data.covered !== "boolean"){
const err35 = {instancePath:instancePath+"/covered",schemaPath:"#/oneOf/3/properties/covered/type",keyword:"type",params:{type: "boolean"}};
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
else {
const err36 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
}
}
var _valid0 = _errs57 === errors;
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
const _errs62 = errors;
if(errors === _errs62){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing10;
if((data.prepared === undefined) && (missing10 = "prepared")){
const err37 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing10}};
if(vErrors === null){
vErrors = [err37];
}
else {
vErrors.push(err37);
}
errors++;
}
else {
const _errs64 = errors;
for(const key10 in data){
if(!(key10 === "prepared")){
const err38 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10}};
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
if(_errs64 === errors){
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
const err39 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err39];
}
else {
vErrors.push(err39);
}
errors++;
}
}
var _valid0 = _errs62 === errors;
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
const _errs66 = errors;
if(!(validate329(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate329.errors : vErrors.concat(validate329.errors);
errors = vErrors.length;
}
var _valid0 = _errs66 === errors;
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
if((data.observation === undefined) && (missing11 = "observation")){
const err40 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing11}};
if(vErrors === null){
vErrors = [err40];
}
else {
vErrors.push(err40);
}
errors++;
}
else {
const _errs69 = errors;
for(const key11 in data){
if(!(key11 === "observation")){
const err41 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11}};
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
if(_errs69 === errors){
if(data.observation !== undefined){
let data28 = data.observation;
const _errs71 = errors;
let valid15 = false;
let passing1 = null;
const _errs72 = errors;
if(errors === _errs72){
if(data28 && typeof data28 == "object" && !Array.isArray(data28)){
let missing12;
if((data28.pending === undefined) && (missing12 = "pending")){
const err42 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/6/properties/observation/oneOf/0/required",keyword:"required",params:{missingProperty: missing12}};
if(vErrors === null){
vErrors = [err42];
}
else {
vErrors.push(err42);
}
errors++;
}
else {
const _errs74 = errors;
for(const key12 in data28){
if(!(key12 === "pending")){
const err43 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/6/properties/observation/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key12}};
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
if(_errs74 === errors){
if(data28.pending !== undefined){
let data29 = data28.pending;
const _errs75 = errors;
if(errors === _errs75){
if(data29 && typeof data29 == "object" && !Array.isArray(data29)){
if(Object.keys(data29).length > 0){
const err44 = {instancePath:instancePath+"/observation/pending",schemaPath:"#/oneOf/6/properties/observation/oneOf/0/properties/pending/maxProperties",keyword:"maxProperties",params:{limit: 0}};
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
const err45 = {instancePath:instancePath+"/observation/pending",schemaPath:"#/oneOf/6/properties/observation/oneOf/0/properties/pending/type",keyword:"type",params:{type: "object"}};
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
}
}
else {
const err46 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/6/properties/observation/oneOf/0/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err46];
}
else {
vErrors.push(err46);
}
errors++;
}
}
var _valid3 = _errs72 === errors;
if(_valid3){
valid15 = true;
passing1 = 0;
var props7 = true;
}
const _errs77 = errors;
if(errors === _errs77){
if(data28 && typeof data28 == "object" && !Array.isArray(data28)){
let missing13;
if((data28.committed === undefined) && (missing13 = "committed")){
const err47 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/6/properties/observation/oneOf/1/required",keyword:"required",params:{missingProperty: missing13}};
if(vErrors === null){
vErrors = [err47];
}
else {
vErrors.push(err47);
}
errors++;
}
else {
const _errs79 = errors;
for(const key13 in data28){
if(!(key13 === "committed")){
const err48 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/6/properties/observation/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key13}};
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
if(_errs79 === errors){
if(data28.committed !== undefined){
let data30 = data28.committed;
const _errs80 = errors;
if(errors === _errs80){
if(data30 && typeof data30 == "object" && !Array.isArray(data30)){
if(Object.keys(data30).length > 0){
const err49 = {instancePath:instancePath+"/observation/committed",schemaPath:"#/oneOf/6/properties/observation/oneOf/1/properties/committed/maxProperties",keyword:"maxProperties",params:{limit: 0}};
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
const err50 = {instancePath:instancePath+"/observation/committed",schemaPath:"#/oneOf/6/properties/observation/oneOf/1/properties/committed/type",keyword:"type",params:{type: "object"}};
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
}
}
else {
const err51 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/6/properties/observation/oneOf/1/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err51];
}
else {
vErrors.push(err51);
}
errors++;
}
}
var _valid3 = _errs77 === errors;
if(_valid3 && valid15){
valid15 = false;
passing1 = [passing1, 1];
}
else {
if(_valid3){
valid15 = true;
passing1 = 1;
if(props7 !== true){
props7 = true;
}
}
const _errs82 = errors;
if(errors === _errs82){
if(data28 && typeof data28 == "object" && !Array.isArray(data28)){
let missing14;
if((data28.rejected === undefined) && (missing14 = "rejected")){
const err52 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/6/properties/observation/oneOf/2/required",keyword:"required",params:{missingProperty: missing14}};
if(vErrors === null){
vErrors = [err52];
}
else {
vErrors.push(err52);
}
errors++;
}
else {
const _errs84 = errors;
for(const key14 in data28){
if(!(key14 === "rejected")){
const err53 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/6/properties/observation/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key14}};
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
if(_errs84 === errors){
if(data28.rejected !== undefined){
let data31 = data28.rejected;
const _errs85 = errors;
if(errors === _errs85){
if(data31 && typeof data31 == "object" && !Array.isArray(data31)){
let missing15;
if(((data31.record === undefined) && (missing15 = "record")) || ((data31.diagnostic === undefined) && (missing15 = "diagnostic"))){
const err54 = {instancePath:instancePath+"/observation/rejected",schemaPath:"#/oneOf/6/properties/observation/oneOf/2/properties/rejected/required",keyword:"required",params:{missingProperty: missing15}};
if(vErrors === null){
vErrors = [err54];
}
else {
vErrors.push(err54);
}
errors++;
}
else {
const _errs87 = errors;
for(const key15 in data31){
if(!((key15 === "record") || (key15 === "diagnostic"))){
const err55 = {instancePath:instancePath+"/observation/rejected",schemaPath:"#/oneOf/6/properties/observation/oneOf/2/properties/rejected/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key15}};
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
if(_errs87 === errors){
if(data31.record !== undefined){
const _errs88 = errors;
if(!(validate183(data31.record, {instancePath:instancePath+"/observation/rejected/record",parentData:data31,parentDataProperty:"record",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate183.errors : vErrors.concat(validate183.errors);
errors = vErrors.length;
}
var valid19 = _errs88 === errors;
}
else {
var valid19 = true;
}
if(valid19){
if(data31.diagnostic !== undefined){
const _errs89 = errors;
if(!(validate477(data31.diagnostic, {instancePath:instancePath+"/observation/rejected/diagnostic",parentData:data31,parentDataProperty:"diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate477.errors : vErrors.concat(validate477.errors);
errors = vErrors.length;
}
var valid19 = _errs89 === errors;
}
else {
var valid19 = true;
}
}
}
}
}
else {
const err56 = {instancePath:instancePath+"/observation/rejected",schemaPath:"#/oneOf/6/properties/observation/oneOf/2/properties/rejected/type",keyword:"type",params:{type: "object"}};
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
const err57 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/6/properties/observation/oneOf/2/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err57];
}
else {
vErrors.push(err57);
}
errors++;
}
}
var _valid3 = _errs82 === errors;
if(_valid3 && valid15){
valid15 = false;
passing1 = [passing1, 2];
}
else {
if(_valid3){
valid15 = true;
passing1 = 2;
if(props7 !== true){
props7 = true;
}
}
}
}
if(!valid15){
const err58 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/6/properties/observation/oneOf",keyword:"oneOf",params:{passingSchemas: passing1}};
if(vErrors === null){
vErrors = [err58];
}
else {
vErrors.push(err58);
}
errors++;
}
else {
errors = _errs71;
if(vErrors !== null){
if(_errs71){
vErrors.length = _errs71;
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
const err59 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err59];
}
else {
vErrors.push(err59);
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
const _errs90 = errors;
if(errors === _errs90){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing16;
if((data.recovered_control === undefined) && (missing16 = "recovered_control")){
const err60 = {instancePath,schemaPath:"#/oneOf/7/required",keyword:"required",params:{missingProperty: missing16}};
if(vErrors === null){
vErrors = [err60];
}
else {
vErrors.push(err60);
}
errors++;
}
else {
const _errs92 = errors;
for(const key16 in data){
if(!(key16 === "recovered_control")){
const err61 = {instancePath,schemaPath:"#/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key16}};
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
if(_errs92 === errors){
if(data.recovered_control !== undefined){
let data34 = data.recovered_control;
const _errs93 = errors;
if(errors === _errs93){
if(data34 && typeof data34 == "object" && !Array.isArray(data34)){
let missing17;
if((((data34.connection === undefined) && (missing17 = "connection")) || ((data34.control === undefined) && (missing17 = "control"))) || ((data34.input === undefined) && (missing17 = "input"))){
const err62 = {instancePath:instancePath+"/recovered_control",schemaPath:"#/oneOf/7/properties/recovered_control/required",keyword:"required",params:{missingProperty: missing17}};
if(vErrors === null){
vErrors = [err62];
}
else {
vErrors.push(err62);
}
errors++;
}
else {
const _errs95 = errors;
for(const key17 in data34){
if(!(((key17 === "connection") || (key17 === "control")) || (key17 === "input"))){
const err63 = {instancePath:instancePath+"/recovered_control",schemaPath:"#/oneOf/7/properties/recovered_control/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key17}};
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
if(_errs95 === errors){
if(data34.connection !== undefined){
const _errs96 = errors;
if(!(validate448(data34.connection, {instancePath:instancePath+"/recovered_control/connection",parentData:data34,parentDataProperty:"connection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate448.errors : vErrors.concat(validate448.errors);
errors = vErrors.length;
}
var valid21 = _errs96 === errors;
}
else {
var valid21 = true;
}
if(valid21){
if(data34.control !== undefined){
let data36 = data34.control;
const _errs97 = errors;
const _errs98 = errors;
let valid22 = false;
let passing2 = null;
const _errs99 = errors;
if(errors === _errs99){
if(data36 && typeof data36 == "object" && !Array.isArray(data36)){
let missing18;
if((data36.reactive === undefined) && (missing18 = "reactive")){
const err64 = {instancePath:instancePath+"/recovered_control/control",schemaPath:"#/oneOf/7/properties/recovered_control/properties/control/oneOf/0/required",keyword:"required",params:{missingProperty: missing18}};
if(vErrors === null){
vErrors = [err64];
}
else {
vErrors.push(err64);
}
errors++;
}
else {
const _errs101 = errors;
for(const key18 in data36){
if(!(key18 === "reactive")){
const err65 = {instancePath:instancePath+"/recovered_control/control",schemaPath:"#/oneOf/7/properties/recovered_control/properties/control/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key18}};
if(vErrors === null){
vErrors = [err65];
}
else {
vErrors.push(err65);
}
errors++;
break;
}
}
if(_errs101 === errors){
if(data36.reactive !== undefined){
if(!(validate370(data36.reactive, {instancePath:instancePath+"/recovered_control/control/reactive",parentData:data36,parentDataProperty:"reactive",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate370.errors : vErrors.concat(validate370.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err66 = {instancePath:instancePath+"/recovered_control/control",schemaPath:"#/oneOf/7/properties/recovered_control/properties/control/oneOf/0/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err66];
}
else {
vErrors.push(err66);
}
errors++;
}
}
var _valid4 = _errs99 === errors;
if(_valid4){
valid22 = true;
passing2 = 0;
var props10 = true;
}
const _errs103 = errors;
if(errors === _errs103){
if(data36 && typeof data36 == "object" && !Array.isArray(data36)){
let missing19;
if((data36.refresh === undefined) && (missing19 = "refresh")){
const err67 = {instancePath:instancePath+"/recovered_control/control",schemaPath:"#/oneOf/7/properties/recovered_control/properties/control/oneOf/1/required",keyword:"required",params:{missingProperty: missing19}};
if(vErrors === null){
vErrors = [err67];
}
else {
vErrors.push(err67);
}
errors++;
}
else {
const _errs105 = errors;
for(const key19 in data36){
if(!(key19 === "refresh")){
const err68 = {instancePath:instancePath+"/recovered_control/control",schemaPath:"#/oneOf/7/properties/recovered_control/properties/control/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key19}};
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
if(_errs105 === errors){
if(data36.refresh !== undefined){
if(!(validate418(data36.refresh, {instancePath:instancePath+"/recovered_control/control/refresh",parentData:data36,parentDataProperty:"refresh",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate418.errors : vErrors.concat(validate418.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err69 = {instancePath:instancePath+"/recovered_control/control",schemaPath:"#/oneOf/7/properties/recovered_control/properties/control/oneOf/1/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err69];
}
else {
vErrors.push(err69);
}
errors++;
}
}
var _valid4 = _errs103 === errors;
if(_valid4 && valid22){
valid22 = false;
passing2 = [passing2, 1];
}
else {
if(_valid4){
valid22 = true;
passing2 = 1;
if(props10 !== true){
props10 = true;
}
}
}
if(!valid22){
const err70 = {instancePath:instancePath+"/recovered_control/control",schemaPath:"#/oneOf/7/properties/recovered_control/properties/control/oneOf",keyword:"oneOf",params:{passingSchemas: passing2}};
if(vErrors === null){
vErrors = [err70];
}
else {
vErrors.push(err70);
}
errors++;
}
else {
errors = _errs98;
if(vErrors !== null){
if(_errs98){
vErrors.length = _errs98;
}
else {
vErrors = null;
}
}
}
var valid21 = _errs97 === errors;
}
else {
var valid21 = true;
}
if(valid21){
if(data34.input !== undefined){
const _errs107 = errors;
if(!(validate60(data34.input, {instancePath:instancePath+"/recovered_control/input",parentData:data34,parentDataProperty:"input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate60.errors : vErrors.concat(validate60.errors);
errors = vErrors.length;
}
var valid21 = _errs107 === errors;
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
const err71 = {instancePath:instancePath+"/recovered_control",schemaPath:"#/oneOf/7/properties/recovered_control/type",keyword:"type",params:{type: "object"}};
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
const err72 = {instancePath,schemaPath:"#/oneOf/7/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err72];
}
else {
vErrors.push(err72);
}
errors++;
}
}
var _valid0 = _errs90 === errors;
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
const _errs108 = errors;
if(errors === _errs108){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing20;
if((data.signed_read === undefined) && (missing20 = "signed_read")){
const err73 = {instancePath,schemaPath:"#/oneOf/8/required",keyword:"required",params:{missingProperty: missing20}};
if(vErrors === null){
vErrors = [err73];
}
else {
vErrors.push(err73);
}
errors++;
}
else {
const _errs110 = errors;
for(const key20 in data){
if(!(key20 === "signed_read")){
const err74 = {instancePath,schemaPath:"#/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key20}};
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
if(_errs110 === errors){
if(data.signed_read !== undefined){
let data40 = data.signed_read;
const _errs111 = errors;
if(errors === _errs111){
if(data40 && typeof data40 == "object" && !Array.isArray(data40)){
let missing21;
if(((data40.read === undefined) && (missing21 = "read")) || ((data40.proof === undefined) && (missing21 = "proof"))){
const err75 = {instancePath:instancePath+"/signed_read",schemaPath:"#/oneOf/8/properties/signed_read/required",keyword:"required",params:{missingProperty: missing21}};
if(vErrors === null){
vErrors = [err75];
}
else {
vErrors.push(err75);
}
errors++;
}
else {
const _errs113 = errors;
for(const key21 in data40){
if(!((key21 === "read") || (key21 === "proof"))){
const err76 = {instancePath:instancePath+"/signed_read",schemaPath:"#/oneOf/8/properties/signed_read/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key21}};
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
if(_errs113 === errors){
if(data40.read !== undefined){
const _errs114 = errors;
if(!(validate201(data40.read, {instancePath:instancePath+"/signed_read/read",parentData:data40,parentDataProperty:"read",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate201.errors : vErrors.concat(validate201.errors);
errors = vErrors.length;
}
var valid26 = _errs114 === errors;
}
else {
var valid26 = true;
}
if(valid26){
if(data40.proof !== undefined){
const _errs115 = errors;
if(!(validate547(data40.proof, {instancePath:instancePath+"/signed_read/proof",parentData:data40,parentDataProperty:"proof",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate547.errors : vErrors.concat(validate547.errors);
errors = vErrors.length;
}
var valid26 = _errs115 === errors;
}
else {
var valid26 = true;
}
}
}
}
}
else {
const err77 = {instancePath:instancePath+"/signed_read",schemaPath:"#/oneOf/8/properties/signed_read/type",keyword:"type",params:{type: "object"}};
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
const err78 = {instancePath,schemaPath:"#/oneOf/8/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err78];
}
else {
vErrors.push(err78);
}
errors++;
}
}
var _valid0 = _errs108 === errors;
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
const _errs116 = errors;
if(errors === _errs116){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing22;
if((data.refresh_status === undefined) && (missing22 = "refresh_status")){
const err79 = {instancePath,schemaPath:"#/oneOf/9/required",keyword:"required",params:{missingProperty: missing22}};
if(vErrors === null){
vErrors = [err79];
}
else {
vErrors.push(err79);
}
errors++;
}
else {
const _errs118 = errors;
for(const key22 in data){
if(!(key22 === "refresh_status")){
const err80 = {instancePath,schemaPath:"#/oneOf/9/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key22}};
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
if(_errs118 === errors){
if(data.refresh_status !== undefined){
let data43 = data.refresh_status;
const _errs119 = errors;
if(errors === _errs119){
if(data43 && typeof data43 == "object" && !Array.isArray(data43)){
let missing23;
if(((((data43.resource === undefined) && (missing23 = "resource")) || ((data43.revision === undefined) && (missing23 = "revision"))) || ((data43.policy_revision === undefined) && (missing23 = "policy_revision"))) || ((data43.view === undefined) && (missing23 = "view"))){
const err81 = {instancePath:instancePath+"/refresh_status",schemaPath:"#/oneOf/9/properties/refresh_status/required",keyword:"required",params:{missingProperty: missing23}};
if(vErrors === null){
vErrors = [err81];
}
else {
vErrors.push(err81);
}
errors++;
}
else {
const _errs121 = errors;
for(const key23 in data43){
if(!((((((key23 === "resource") || (key23 === "revision")) || (key23 === "policy_revision")) || (key23 === "view")) || (key23 === "diagnostic")) || (key23 === "query_diagnostic"))){
const err82 = {instancePath:instancePath+"/refresh_status",schemaPath:"#/oneOf/9/properties/refresh_status/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key23}};
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
if(_errs121 === errors){
if(data43.resource !== undefined){
const _errs122 = errors;
if(!(validate56(data43.resource, {instancePath:instancePath+"/refresh_status/resource",parentData:data43,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid28 = _errs122 === errors;
}
else {
var valid28 = true;
}
if(valid28){
if(data43.revision !== undefined){
const _errs123 = errors;
if(!(validate56(data43.revision, {instancePath:instancePath+"/refresh_status/revision",parentData:data43,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid28 = _errs123 === errors;
}
else {
var valid28 = true;
}
if(valid28){
if(data43.policy_revision !== undefined){
const _errs124 = errors;
if(!(validate56(data43.policy_revision, {instancePath:instancePath+"/refresh_status/policy_revision",parentData:data43,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid28 = _errs124 === errors;
}
else {
var valid28 = true;
}
if(valid28){
if(data43.view !== undefined){
let data47 = data43.view;
const _errs125 = errors;
if(errors === _errs125){
if(data47 && typeof data47 == "object" && !Array.isArray(data47)){
let missing24;
if((((((((((data47.principal === undefined) && (missing24 = "principal")) || ((data47.session === undefined) && (missing24 = "session"))) || ((data47.generation === undefined) && (missing24 = "generation"))) || ((data47.source === undefined) && (missing24 = "source"))) || ((data47.template === undefined) && (missing24 = "template"))) || ((data47.namespace === undefined) && (missing24 = "namespace"))) || ((data47.dirty === undefined) && (missing24 = "dirty"))) || ((data47.covered === undefined) && (missing24 = "covered"))) || ((data47.limit === undefined) && (missing24 = "limit"))){
const err83 = {instancePath:instancePath+"/refresh_status/view",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/required",keyword:"required",params:{missingProperty: missing24}};
if(vErrors === null){
vErrors = [err83];
}
else {
vErrors.push(err83);
}
errors++;
}
else {
const _errs127 = errors;
for(const key24 in data47){
if(!(func1.call(schema126.oneOf[9].properties.refresh_status.properties.view.properties, key24))){
const err84 = {instancePath:instancePath+"/refresh_status/view",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key24}};
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
if(_errs127 === errors){
if(data47.principal !== undefined){
const _errs128 = errors;
if(!(validate56(data47.principal, {instancePath:instancePath+"/refresh_status/view/principal",parentData:data47,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid29 = _errs128 === errors;
}
else {
var valid29 = true;
}
if(valid29){
if(data47.session !== undefined){
const _errs129 = errors;
if(!(validate380(data47.session, {instancePath:instancePath+"/refresh_status/view/session",parentData:data47,parentDataProperty:"session",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate380.errors : vErrors.concat(validate380.errors);
errors = vErrors.length;
}
var valid29 = _errs129 === errors;
}
else {
var valid29 = true;
}
if(valid29){
if(data47.generation !== undefined){
const _errs130 = errors;
if(!(validate56(data47.generation, {instancePath:instancePath+"/refresh_status/view/generation",parentData:data47,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid29 = _errs130 === errors;
}
else {
var valid29 = true;
}
if(valid29){
if(data47.source !== undefined){
const _errs131 = errors;
if(!(validate251(data47.source, {instancePath:instancePath+"/refresh_status/view/source",parentData:data47,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate251.errors : vErrors.concat(validate251.errors);
errors = vErrors.length;
}
var valid29 = _errs131 === errors;
}
else {
var valid29 = true;
}
if(valid29){
if(data47.template !== undefined){
const _errs132 = errors;
if(!(validate225(data47.template, {instancePath:instancePath+"/refresh_status/view/template",parentData:data47,parentDataProperty:"template",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
errors = vErrors.length;
}
var valid29 = _errs132 === errors;
}
else {
var valid29 = true;
}
if(valid29){
if(data47.namespace !== undefined){
const _errs133 = errors;
if(!(validate225(data47.namespace, {instancePath:instancePath+"/refresh_status/view/namespace",parentData:data47,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
errors = vErrors.length;
}
var valid29 = _errs133 === errors;
}
else {
var valid29 = true;
}
if(valid29){
if(data47.dirty !== undefined){
const _errs134 = errors;
if(!(validate225(data47.dirty, {instancePath:instancePath+"/refresh_status/view/dirty",parentData:data47,parentDataProperty:"dirty",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
errors = vErrors.length;
}
var valid29 = _errs134 === errors;
}
else {
var valid29 = true;
}
if(valid29){
if(data47.covered !== undefined){
const _errs135 = errors;
if(!(validate225(data47.covered, {instancePath:instancePath+"/refresh_status/view/covered",parentData:data47,parentDataProperty:"covered",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
errors = vErrors.length;
}
var valid29 = _errs135 === errors;
}
else {
var valid29 = true;
}
if(valid29){
if(data47.starts !== undefined){
const _errs136 = errors;
if(!(validate65(data47.starts, {instancePath:instancePath+"/refresh_status/view/starts",parentData:data47,parentDataProperty:"starts",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
errors = vErrors.length;
}
var valid29 = _errs136 === errors;
}
else {
var valid29 = true;
}
if(valid29){
if(data47.limit !== undefined){
const _errs137 = errors;
if(!(validate65(data47.limit, {instancePath:instancePath+"/refresh_status/view/limit",parentData:data47,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
errors = vErrors.length;
}
var valid29 = _errs137 === errors;
}
else {
var valid29 = true;
}
if(valid29){
if(data47.next_start_ms !== undefined){
const _errs138 = errors;
if(!(validate56(data47.next_start_ms, {instancePath:instancePath+"/refresh_status/view/next_start_ms",parentData:data47,parentDataProperty:"next_start_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid29 = _errs138 === errors;
}
else {
var valid29 = true;
}
if(valid29){
if(data47.enabled !== undefined){
const _errs139 = errors;
if(typeof data47.enabled !== "boolean"){
const err85 = {instancePath:instancePath+"/refresh_status/view/enabled",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/enabled/type",keyword:"type",params:{type: "boolean"}};
if(vErrors === null){
vErrors = [err85];
}
else {
vErrors.push(err85);
}
errors++;
}
var valid29 = _errs139 === errors;
}
else {
var valid29 = true;
}
if(valid29){
if(data47.phase !== undefined){
const _errs141 = errors;
if(!(validate565(data47.phase, {instancePath:instancePath+"/refresh_status/view/phase",parentData:data47,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate565.errors : vErrors.concat(validate565.errors);
errors = vErrors.length;
}
var valid29 = _errs141 === errors;
}
else {
var valid29 = true;
}
if(valid29){
if(data47.failure !== undefined){
let data61 = data47.failure;
const _errs142 = errors;
const _errs143 = errors;
let valid30 = false;
let passing3 = null;
const _errs144 = errors;
if(!(validate567(data61, {instancePath:instancePath+"/refresh_status/view/failure",parentData:data47,parentDataProperty:"failure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate567.errors : vErrors.concat(validate567.errors);
errors = vErrors.length;
}
var _valid5 = _errs144 === errors;
if(_valid5){
valid30 = true;
passing3 = 0;
var props12 = true;
}
const _errs145 = errors;
if(errors === _errs145){
if(data61 && typeof data61 == "object" && !Array.isArray(data61)){
let missing25;
if((data61.stopped === undefined) && (missing25 = "stopped")){
const err86 = {instancePath:instancePath+"/refresh_status/view/failure",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/required",keyword:"required",params:{missingProperty: missing25}};
if(vErrors === null){
vErrors = [err86];
}
else {
vErrors.push(err86);
}
errors++;
}
else {
const _errs147 = errors;
for(const key25 in data61){
if(!(key25 === "stopped")){
const err87 = {instancePath:instancePath+"/refresh_status/view/failure",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key25}};
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
if(_errs147 === errors){
if(data61.stopped !== undefined){
let data62 = data61.stopped;
const _errs148 = errors;
if(errors === _errs148){
if(data62 && typeof data62 == "object" && !Array.isArray(data62)){
let missing26;
if(((data62.reason === undefined) && (missing26 = "reason")) || ((data62.input === undefined) && (missing26 = "input"))){
const err88 = {instancePath:instancePath+"/refresh_status/view/failure/stopped",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/required",keyword:"required",params:{missingProperty: missing26}};
if(vErrors === null){
vErrors = [err88];
}
else {
vErrors.push(err88);
}
errors++;
}
else {
const _errs150 = errors;
for(const key26 in data62){
if(!(((key26 === "reason") || (key26 === "input")) || (key26 === "witness"))){
const err89 = {instancePath:instancePath+"/refresh_status/view/failure/stopped",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key26}};
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
if(_errs150 === errors){
if(data62.reason !== undefined){
let data63 = data62.reason;
const _errs151 = errors;
if(typeof data63 !== "string"){
const err90 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/reason",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/reason/type",keyword:"type",params:{type: "string"}};
if(vErrors === null){
vErrors = [err90];
}
else {
vErrors.push(err90);
}
errors++;
}
if(!((((((((((((((((((((data63 === "paused") || (data63 === "budget_exhausted")) || (data63 === "session_closed")) || (data63 === "session_expired")) || (data63 === "source_changed")) || (data63 === "binding_unpublished")) || (data63 === "service_denied")) || (data63 === "native_denied")) || (data63 === "query_denied")) || (data63 === "catalog_denied")) || (data63 === "resource_unavailable")) || (data63 === "query_source_unavailable")) || (data63 === "result_unavailable")) || (data63 === "result_unpublished")) || (data63 === "template_invalid")) || (data63 === "upload_closed")) || (data63 === "namespace_occupied")) || (data63 === "query_rejected")) || (data63 === "query_cancelled")) || (data63 === "query_retired"))){
const err91 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/reason",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/reason/enum",keyword:"enum",params:{allowedValues: schema126.oneOf[9].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.reason.enum}};
if(vErrors === null){
vErrors = [err91];
}
else {
vErrors.push(err91);
}
errors++;
}
var valid32 = _errs151 === errors;
}
else {
var valid32 = true;
}
if(valid32){
if(data62.input !== undefined){
const _errs153 = errors;
if(!(validate56(data62.input, {instancePath:instancePath+"/refresh_status/view/failure/stopped/input",parentData:data62,parentDataProperty:"input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid32 = _errs153 === errors;
}
else {
var valid32 = true;
}
if(valid32){
if(data62.witness !== undefined){
let data65 = data62.witness;
const _errs154 = errors;
const _errs155 = errors;
let valid33 = false;
let passing4 = null;
const _errs156 = errors;
if(!(validate567(data65, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",parentData:data62,parentDataProperty:"witness",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate567.errors : vErrors.concat(validate567.errors);
errors = vErrors.length;
}
var _valid6 = _errs156 === errors;
if(_valid6){
valid33 = true;
passing4 = 0;
var props13 = true;
}
const _errs157 = errors;
if(errors === _errs157){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing27;
if((data65.revision === undefined) && (missing27 = "revision")){
const err92 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/1/required",keyword:"required",params:{missingProperty: missing27}};
if(vErrors === null){
vErrors = [err92];
}
else {
vErrors.push(err92);
}
errors++;
}
else {
const _errs159 = errors;
for(const key27 in data65){
if(!(key27 === "revision")){
const err93 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key27}};
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
if(_errs159 === errors){
if(data65.revision !== undefined){
let data66 = data65.revision;
const _errs160 = errors;
if(errors === _errs160){
if(data66 && typeof data66 == "object" && !Array.isArray(data66)){
let missing28;
if((((((data66.kind === undefined) && (missing28 = "kind")) || ((data66.expected === undefined) && (missing28 = "expected"))) || ((data66.actual === undefined) && (missing28 = "actual"))) || ((data66.proposed === undefined) && (missing28 = "proposed"))) || ((data66.present === undefined) && (missing28 = "present"))){
const err94 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/revision",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/1/properties/revision/required",keyword:"required",params:{missingProperty: missing28}};
if(vErrors === null){
vErrors = [err94];
}
else {
vErrors.push(err94);
}
errors++;
}
else {
const _errs162 = errors;
for(const key28 in data66){
if(!(((((key28 === "kind") || (key28 === "expected")) || (key28 === "actual")) || (key28 === "proposed")) || (key28 === "present"))){
const err95 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/revision",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/1/properties/revision/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key28}};
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
if(_errs162 === errors){
if(data66.kind !== undefined){
let data67 = data66.kind;
const _errs163 = errors;
if(typeof data67 !== "string"){
const err96 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/revision/kind",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/1/properties/revision/properties/kind/type",keyword:"type",params:{type: "string"}};
if(vErrors === null){
vErrors = [err96];
}
else {
vErrors.push(err96);
}
errors++;
}
if(!((((data67 === "binding") || (data67 === "policy")) || (data67 === "watch")) || (data67 === "refresh"))){
const err97 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/revision/kind",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/1/properties/revision/properties/kind/enum",keyword:"enum",params:{allowedValues: schema126.oneOf[9].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[1].properties.revision.properties.kind.enum}};
if(vErrors === null){
vErrors = [err97];
}
else {
vErrors.push(err97);
}
errors++;
}
var valid35 = _errs163 === errors;
}
else {
var valid35 = true;
}
if(valid35){
if(data66.expected !== undefined){
const _errs165 = errors;
if(!(validate56(data66.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/revision/expected",parentData:data66,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid35 = _errs165 === errors;
}
else {
var valid35 = true;
}
if(valid35){
if(data66.actual !== undefined){
const _errs166 = errors;
if(!(validate56(data66.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/revision/actual",parentData:data66,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid35 = _errs166 === errors;
}
else {
var valid35 = true;
}
if(valid35){
if(data66.proposed !== undefined){
const _errs167 = errors;
if(!(validate56(data66.proposed, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/revision/proposed",parentData:data66,parentDataProperty:"proposed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid35 = _errs167 === errors;
}
else {
var valid35 = true;
}
if(valid35){
if(data66.present !== undefined){
const _errs168 = errors;
if(typeof data66.present !== "boolean"){
const err98 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/revision/present",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/1/properties/revision/properties/present/type",keyword:"type",params:{type: "boolean"}};
if(vErrors === null){
vErrors = [err98];
}
else {
vErrors.push(err98);
}
errors++;
}
var valid35 = _errs168 === errors;
}
else {
var valid35 = true;
}
}
}
}
}
}
}
}
else {
const err99 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/revision",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/1/properties/revision/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err99];
}
else {
vErrors.push(err99);
}
errors++;
}
}
}
}
}
}
else {
const err100 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/1/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err100];
}
else {
vErrors.push(err100);
}
errors++;
}
}
var _valid6 = _errs157 === errors;
if(_valid6 && valid33){
valid33 = false;
passing4 = [passing4, 1];
}
else {
if(_valid6){
valid33 = true;
passing4 = 1;
if(props13 !== true){
props13 = true;
}
}
const _errs170 = errors;
if(errors === _errs170){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing29;
if((data65.policy === undefined) && (missing29 = "policy")){
const err101 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/2/required",keyword:"required",params:{missingProperty: missing29}};
if(vErrors === null){
vErrors = [err101];
}
else {
vErrors.push(err101);
}
errors++;
}
else {
const _errs172 = errors;
for(const key29 in data65){
if(!(key29 === "policy")){
const err102 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key29}};
if(vErrors === null){
vErrors = [err102];
}
else {
vErrors.push(err102);
}
errors++;
break;
}
}
if(_errs172 === errors){
if(data65.policy !== undefined){
let data72 = data65.policy;
const _errs173 = errors;
if(errors === _errs173){
if(data72 && typeof data72 == "object" && !Array.isArray(data72)){
let missing30;
if((((((data72.principal === undefined) && (missing30 = "principal")) || ((data72.revision === undefined) && (missing30 = "revision"))) || ((data72.present === undefined) && (missing30 = "present"))) || ((data72.commands === undefined) && (missing30 = "commands"))) || ((data72.reads === undefined) && (missing30 = "reads"))){
const err103 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/policy",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/2/properties/policy/required",keyword:"required",params:{missingProperty: missing30}};
if(vErrors === null){
vErrors = [err103];
}
else {
vErrors.push(err103);
}
errors++;
}
else {
const _errs175 = errors;
for(const key30 in data72){
if(!(((((key30 === "principal") || (key30 === "revision")) || (key30 === "present")) || (key30 === "commands")) || (key30 === "reads"))){
const err104 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/policy",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/2/properties/policy/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key30}};
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
if(_errs175 === errors){
if(data72.principal !== undefined){
const _errs176 = errors;
if(!(validate56(data72.principal, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/policy/principal",parentData:data72,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid37 = _errs176 === errors;
}
else {
var valid37 = true;
}
if(valid37){
if(data72.revision !== undefined){
const _errs177 = errors;
if(!(validate56(data72.revision, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/policy/revision",parentData:data72,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid37 = _errs177 === errors;
}
else {
var valid37 = true;
}
if(valid37){
if(data72.present !== undefined){
const _errs178 = errors;
if(typeof data72.present !== "boolean"){
const err105 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/policy/present",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/2/properties/policy/properties/present/type",keyword:"type",params:{type: "boolean"}};
if(vErrors === null){
vErrors = [err105];
}
else {
vErrors.push(err105);
}
errors++;
}
var valid37 = _errs178 === errors;
}
else {
var valid37 = true;
}
if(valid37){
if(data72.commands !== undefined){
const _errs180 = errors;
if(typeof data72.commands !== "boolean"){
const err106 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/policy/commands",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/2/properties/policy/properties/commands/type",keyword:"type",params:{type: "boolean"}};
if(vErrors === null){
vErrors = [err106];
}
else {
vErrors.push(err106);
}
errors++;
}
var valid37 = _errs180 === errors;
}
else {
var valid37 = true;
}
if(valid37){
if(data72.reads !== undefined){
const _errs182 = errors;
if(typeof data72.reads !== "boolean"){
const err107 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/policy/reads",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/2/properties/policy/properties/reads/type",keyword:"type",params:{type: "boolean"}};
if(vErrors === null){
vErrors = [err107];
}
else {
vErrors.push(err107);
}
errors++;
}
var valid37 = _errs182 === errors;
}
else {
var valid37 = true;
}
}
}
}
}
}
}
}
else {
const err108 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/policy",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/2/properties/policy/type",keyword:"type",params:{type: "object"}};
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
const err109 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/2/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err109];
}
else {
vErrors.push(err109);
}
errors++;
}
}
var _valid6 = _errs170 === errors;
if(_valid6 && valid33){
valid33 = false;
passing4 = [passing4, 2];
}
else {
if(_valid6){
valid33 = true;
passing4 = 2;
if(props13 !== true){
props13 = true;
}
}
const _errs184 = errors;
if(errors === _errs184){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing31;
if((data65.identity === undefined) && (missing31 = "identity")){
const err110 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/3/required",keyword:"required",params:{missingProperty: missing31}};
if(vErrors === null){
vErrors = [err110];
}
else {
vErrors.push(err110);
}
errors++;
}
else {
const _errs186 = errors;
for(const key31 in data65){
if(!(key31 === "identity")){
const err111 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key31}};
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
if(_errs186 === errors){
if(data65.identity !== undefined){
let data78 = data65.identity;
const _errs187 = errors;
if(errors === _errs187){
if(data78 && typeof data78 == "object" && !Array.isArray(data78)){
let missing32;
if(((data78.expected === undefined) && (missing32 = "expected")) || ((data78.actual === undefined) && (missing32 = "actual"))){
const err112 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/identity",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/3/properties/identity/required",keyword:"required",params:{missingProperty: missing32}};
if(vErrors === null){
vErrors = [err112];
}
else {
vErrors.push(err112);
}
errors++;
}
else {
const _errs189 = errors;
for(const key32 in data78){
if(!((key32 === "expected") || (key32 === "actual"))){
const err113 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/identity",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/3/properties/identity/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key32}};
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
if(_errs189 === errors){
if(data78.expected !== undefined){
const _errs190 = errors;
if(!(validate64(data78.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/identity/expected",parentData:data78,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
errors = vErrors.length;
}
var valid39 = _errs190 === errors;
}
else {
var valid39 = true;
}
if(valid39){
if(data78.actual !== undefined){
const _errs191 = errors;
if(!(validate64(data78.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/identity/actual",parentData:data78,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
errors = vErrors.length;
}
var valid39 = _errs191 === errors;
}
else {
var valid39 = true;
}
}
}
}
}
else {
const err114 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/identity",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/3/properties/identity/type",keyword:"type",params:{type: "object"}};
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
}
}
else {
const err115 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/3/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err115];
}
else {
vErrors.push(err115);
}
errors++;
}
}
var _valid6 = _errs184 === errors;
if(_valid6 && valid33){
valid33 = false;
passing4 = [passing4, 3];
}
else {
if(_valid6){
valid33 = true;
passing4 = 3;
if(props13 !== true){
props13 = true;
}
}
const _errs192 = errors;
if(errors === _errs192){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing33;
if((data65.capacity === undefined) && (missing33 = "capacity")){
const err116 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/4/required",keyword:"required",params:{missingProperty: missing33}};
if(vErrors === null){
vErrors = [err116];
}
else {
vErrors.push(err116);
}
errors++;
}
else {
const _errs194 = errors;
for(const key33 in data65){
if(!(key33 === "capacity")){
const err117 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key33}};
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
if(_errs194 === errors){
if(data65.capacity !== undefined){
let data81 = data65.capacity;
const _errs195 = errors;
if(errors === _errs195){
if(data81 && typeof data81 == "object" && !Array.isArray(data81)){
let missing34;
if((((data81.kind === undefined) && (missing34 = "kind")) || ((data81.actual === undefined) && (missing34 = "actual"))) || ((data81.limit === undefined) && (missing34 = "limit"))){
const err118 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/capacity",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/4/properties/capacity/required",keyword:"required",params:{missingProperty: missing34}};
if(vErrors === null){
vErrors = [err118];
}
else {
vErrors.push(err118);
}
errors++;
}
else {
const _errs197 = errors;
for(const key34 in data81){
if(!(((key34 === "kind") || (key34 === "actual")) || (key34 === "limit"))){
const err119 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/capacity",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/4/properties/capacity/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key34}};
if(vErrors === null){
vErrors = [err119];
}
else {
vErrors.push(err119);
}
errors++;
break;
}
}
if(_errs197 === errors){
if(data81.kind !== undefined){
let data82 = data81.kind;
const _errs198 = errors;
if(typeof data82 !== "string"){
const err120 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/capacity/kind",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/4/properties/capacity/properties/kind/type",keyword:"type",params:{type: "string"}};
if(vErrors === null){
vErrors = [err120];
}
else {
vErrors.push(err120);
}
errors++;
}
if(!(((((data82 === "service") || (data82 === "caller")) || (data82 === "service_slots")) || (data82 === "sessions")) || (data82 === "caller_sessions"))){
const err121 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/capacity/kind",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/4/properties/capacity/properties/kind/enum",keyword:"enum",params:{allowedValues: schema126.oneOf[9].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[4].properties.capacity.properties.kind.enum}};
if(vErrors === null){
vErrors = [err121];
}
else {
vErrors.push(err121);
}
errors++;
}
var valid41 = _errs198 === errors;
}
else {
var valid41 = true;
}
if(valid41){
if(data81.actual !== undefined){
const _errs200 = errors;
if(!(validate65(data81.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/capacity/actual",parentData:data81,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
errors = vErrors.length;
}
var valid41 = _errs200 === errors;
}
else {
var valid41 = true;
}
if(valid41){
if(data81.limit !== undefined){
const _errs201 = errors;
if(!(validate65(data81.limit, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/capacity/limit",parentData:data81,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
errors = vErrors.length;
}
var valid41 = _errs201 === errors;
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
const err122 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/capacity",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/4/properties/capacity/type",keyword:"type",params:{type: "object"}};
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
const err123 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/4/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err123];
}
else {
vErrors.push(err123);
}
errors++;
}
}
var _valid6 = _errs192 === errors;
if(_valid6 && valid33){
valid33 = false;
passing4 = [passing4, 4];
}
else {
if(_valid6){
valid33 = true;
passing4 = 4;
if(props13 !== true){
props13 = true;
}
}
const _errs202 = errors;
if(errors === _errs202){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing35;
if((data65.generation === undefined) && (missing35 = "generation")){
const err124 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/5/required",keyword:"required",params:{missingProperty: missing35}};
if(vErrors === null){
vErrors = [err124];
}
else {
vErrors.push(err124);
}
errors++;
}
else {
const _errs204 = errors;
for(const key35 in data65){
if(!(key35 === "generation")){
const err125 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key35}};
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
if(_errs204 === errors){
if(data65.generation !== undefined){
if(!(validate580(data65.generation, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/generation",parentData:data65,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate580.errors : vErrors.concat(validate580.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err126 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/5/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err126];
}
else {
vErrors.push(err126);
}
errors++;
}
}
var _valid6 = _errs202 === errors;
if(_valid6 && valid33){
valid33 = false;
passing4 = [passing4, 5];
}
else {
if(_valid6){
valid33 = true;
passing4 = 5;
if(props13 !== true){
props13 = true;
}
}
const _errs206 = errors;
if(errors === _errs206){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing36;
if((data65.session === undefined) && (missing36 = "session")){
const err127 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/6/required",keyword:"required",params:{missingProperty: missing36}};
if(vErrors === null){
vErrors = [err127];
}
else {
vErrors.push(err127);
}
errors++;
}
else {
const _errs208 = errors;
for(const key36 in data65){
if(!(key36 === "session")){
const err128 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key36}};
if(vErrors === null){
vErrors = [err128];
}
else {
vErrors.push(err128);
}
errors++;
break;
}
}
if(_errs208 === errors){
if(data65.session !== undefined){
let data86 = data65.session;
const _errs209 = errors;
if(errors === _errs209){
if(data86 && typeof data86 == "object" && !Array.isArray(data86)){
let missing37;
if(((((data86.phase === undefined) && (missing37 = "phase")) || ((data86.deadline === undefined) && (missing37 = "deadline"))) || ((data86.observed === undefined) && (missing37 = "observed"))) || ((data86.clock_known === undefined) && (missing37 = "clock_known"))){
const err129 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/session",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/6/properties/session/required",keyword:"required",params:{missingProperty: missing37}};
if(vErrors === null){
vErrors = [err129];
}
else {
vErrors.push(err129);
}
errors++;
}
else {
const _errs211 = errors;
for(const key37 in data86){
if(!((((key37 === "phase") || (key37 === "deadline")) || (key37 === "observed")) || (key37 === "clock_known"))){
const err130 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/session",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/6/properties/session/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key37}};
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
if(_errs211 === errors){
if(data86.phase !== undefined){
const _errs212 = errors;
if(!(validate242(data86.phase, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/session/phase",parentData:data86,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate242.errors : vErrors.concat(validate242.errors);
errors = vErrors.length;
}
var valid44 = _errs212 === errors;
}
else {
var valid44 = true;
}
if(valid44){
if(data86.deadline !== undefined){
const _errs213 = errors;
if(!(validate56(data86.deadline, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/session/deadline",parentData:data86,parentDataProperty:"deadline",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid44 = _errs213 === errors;
}
else {
var valid44 = true;
}
if(valid44){
if(data86.observed !== undefined){
const _errs214 = errors;
if(!(validate56(data86.observed, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/session/observed",parentData:data86,parentDataProperty:"observed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid44 = _errs214 === errors;
}
else {
var valid44 = true;
}
if(valid44){
if(data86.clock_known !== undefined){
const _errs215 = errors;
if(typeof data86.clock_known !== "boolean"){
const err131 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/session/clock_known",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/6/properties/session/properties/clock_known/type",keyword:"type",params:{type: "boolean"}};
if(vErrors === null){
vErrors = [err131];
}
else {
vErrors.push(err131);
}
errors++;
}
var valid44 = _errs215 === errors;
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
const err132 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/session",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/6/properties/session/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err132];
}
else {
vErrors.push(err132);
}
errors++;
}
}
}
}
}
}
else {
const err133 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/6/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err133];
}
else {
vErrors.push(err133);
}
errors++;
}
}
var _valid6 = _errs206 === errors;
if(_valid6 && valid33){
valid33 = false;
passing4 = [passing4, 6];
}
else {
if(_valid6){
valid33 = true;
passing4 = 6;
if(props13 !== true){
props13 = true;
}
}
const _errs217 = errors;
if(errors === _errs217){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing38;
if((data65.source === undefined) && (missing38 = "source")){
const err134 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/7/required",keyword:"required",params:{missingProperty: missing38}};
if(vErrors === null){
vErrors = [err134];
}
else {
vErrors.push(err134);
}
errors++;
}
else {
const _errs219 = errors;
for(const key38 in data65){
if(!(key38 === "source")){
const err135 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key38}};
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
if(_errs219 === errors){
if(data65.source !== undefined){
let data91 = data65.source;
const _errs220 = errors;
if(errors === _errs220){
if(data91 && typeof data91 == "object" && !Array.isArray(data91)){
let missing39;
if((((((((data91.expected === undefined) && (missing39 = "expected")) || ((data91.actual === undefined) && (missing39 = "actual"))) || ((data91.present === undefined) && (missing39 = "present"))) || ((data91.published === undefined) && (missing39 = "published"))) || ((data91.target === undefined) && (missing39 = "target"))) || ((data91.resource === undefined) && (missing39 = "resource"))) || ((data91.metadata === undefined) && (missing39 = "metadata"))){
const err136 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/7/properties/source/required",keyword:"required",params:{missingProperty: missing39}};
if(vErrors === null){
vErrors = [err136];
}
else {
vErrors.push(err136);
}
errors++;
}
else {
const _errs222 = errors;
for(const key39 in data91){
if(!(((((((key39 === "expected") || (key39 === "actual")) || (key39 === "present")) || (key39 === "published")) || (key39 === "target")) || (key39 === "resource")) || (key39 === "metadata"))){
const err137 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/7/properties/source/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key39}};
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
if(_errs222 === errors){
if(data91.expected !== undefined){
const _errs223 = errors;
if(!(validate56(data91.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source/expected",parentData:data91,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid46 = _errs223 === errors;
}
else {
var valid46 = true;
}
if(valid46){
if(data91.actual !== undefined){
const _errs224 = errors;
if(!(validate56(data91.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source/actual",parentData:data91,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid46 = _errs224 === errors;
}
else {
var valid46 = true;
}
if(valid46){
if(data91.present !== undefined){
const _errs225 = errors;
if(typeof data91.present !== "boolean"){
const err138 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source/present",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/7/properties/source/properties/present/type",keyword:"type",params:{type: "boolean"}};
if(vErrors === null){
vErrors = [err138];
}
else {
vErrors.push(err138);
}
errors++;
}
var valid46 = _errs225 === errors;
}
else {
var valid46 = true;
}
if(valid46){
if(data91.published !== undefined){
const _errs227 = errors;
if(typeof data91.published !== "boolean"){
const err139 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source/published",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/7/properties/source/properties/published/type",keyword:"type",params:{type: "boolean"}};
if(vErrors === null){
vErrors = [err139];
}
else {
vErrors.push(err139);
}
errors++;
}
var valid46 = _errs227 === errors;
}
else {
var valid46 = true;
}
if(valid46){
if(data91.target !== undefined){
const _errs229 = errors;
if(!(validate56(data91.target, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source/target",parentData:data91,parentDataProperty:"target",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid46 = _errs229 === errors;
}
else {
var valid46 = true;
}
if(valid46){
if(data91.resource !== undefined){
const _errs230 = errors;
if(!(validate56(data91.resource, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source/resource",parentData:data91,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid46 = _errs230 === errors;
}
else {
var valid46 = true;
}
if(valid46){
if(data91.metadata !== undefined){
const _errs231 = errors;
if(!(validate64(data91.metadata, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source/metadata",parentData:data91,parentDataProperty:"metadata",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
errors = vErrors.length;
}
var valid46 = _errs231 === errors;
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
}
}
}
else {
const err140 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/7/properties/source/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err140];
}
else {
vErrors.push(err140);
}
errors++;
}
}
}
}
}
}
else {
const err141 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/7/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err141];
}
else {
vErrors.push(err141);
}
errors++;
}
}
var _valid6 = _errs217 === errors;
if(_valid6 && valid33){
valid33 = false;
passing4 = [passing4, 7];
}
else {
if(_valid6){
valid33 = true;
passing4 = 7;
if(props13 !== true){
props13 = true;
}
}
const _errs232 = errors;
if(errors === _errs232){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing40;
if((data65.lease === undefined) && (missing40 = "lease")){
const err142 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/8/required",keyword:"required",params:{missingProperty: missing40}};
if(vErrors === null){
vErrors = [err142];
}
else {
vErrors.push(err142);
}
errors++;
}
else {
const _errs234 = errors;
for(const key40 in data65){
if(!(key40 === "lease")){
const err143 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key40}};
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
if(_errs234 === errors){
if(data65.lease !== undefined){
let data99 = data65.lease;
const _errs235 = errors;
if(errors === _errs235){
if(data99 && typeof data99 == "object" && !Array.isArray(data99)){
let missing41;
if(((((data99.kind === undefined) && (missing41 = "kind")) || ((data99.requested === undefined) && (missing41 = "requested"))) || ((data99.observed === undefined) && (missing41 = "observed"))) || ((data99.limit === undefined) && (missing41 = "limit"))){
const err144 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/lease",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/8/properties/lease/required",keyword:"required",params:{missingProperty: missing41}};
if(vErrors === null){
vErrors = [err144];
}
else {
vErrors.push(err144);
}
errors++;
}
else {
const _errs237 = errors;
for(const key41 in data99){
if(!((((key41 === "kind") || (key41 === "requested")) || (key41 === "observed")) || (key41 === "limit"))){
const err145 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/lease",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/8/properties/lease/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key41}};
if(vErrors === null){
vErrors = [err145];
}
else {
vErrors.push(err145);
}
errors++;
break;
}
}
if(_errs237 === errors){
if(data99.kind !== undefined){
let data100 = data99.kind;
const _errs238 = errors;
if(typeof data100 !== "string"){
const err146 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/lease/kind",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/8/properties/lease/properties/kind/type",keyword:"type",params:{type: "string"}};
if(vErrors === null){
vErrors = [err146];
}
else {
vErrors.push(err146);
}
errors++;
}
if(!((((((data100 === "clock") || (data100 === "interval")) || (data100 === "binding")) || (data100 === "process")) || (data100 === "resource")) || (data100 === "observer"))){
const err147 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/lease/kind",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/8/properties/lease/properties/kind/enum",keyword:"enum",params:{allowedValues: schema126.oneOf[9].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[8].properties.lease.properties.kind.enum}};
if(vErrors === null){
vErrors = [err147];
}
else {
vErrors.push(err147);
}
errors++;
}
var valid48 = _errs238 === errors;
}
else {
var valid48 = true;
}
if(valid48){
if(data99.requested !== undefined){
const _errs240 = errors;
if(!(validate56(data99.requested, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/lease/requested",parentData:data99,parentDataProperty:"requested",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid48 = _errs240 === errors;
}
else {
var valid48 = true;
}
if(valid48){
if(data99.observed !== undefined){
const _errs241 = errors;
if(!(validate56(data99.observed, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/lease/observed",parentData:data99,parentDataProperty:"observed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid48 = _errs241 === errors;
}
else {
var valid48 = true;
}
if(valid48){
if(data99.limit !== undefined){
const _errs242 = errors;
if(!(validate56(data99.limit, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/lease/limit",parentData:data99,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid48 = _errs242 === errors;
}
else {
var valid48 = true;
}
}
}
}
}
}
}
else {
const err148 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/lease",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/8/properties/lease/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err148];
}
else {
vErrors.push(err148);
}
errors++;
}
}
}
}
}
}
else {
const err149 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/8/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err149];
}
else {
vErrors.push(err149);
}
errors++;
}
}
var _valid6 = _errs232 === errors;
if(_valid6 && valid33){
valid33 = false;
passing4 = [passing4, 8];
}
else {
if(_valid6){
valid33 = true;
passing4 = 8;
if(props13 !== true){
props13 = true;
}
}
const _errs243 = errors;
if(errors === _errs243){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing42;
if((data65.attachment === undefined) && (missing42 = "attachment")){
const err150 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/9/required",keyword:"required",params:{missingProperty: missing42}};
if(vErrors === null){
vErrors = [err150];
}
else {
vErrors.push(err150);
}
errors++;
}
else {
const _errs245 = errors;
for(const key42 in data65){
if(!(key42 === "attachment")){
const err151 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/9/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key42}};
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
if(_errs245 === errors){
if(data65.attachment !== undefined){
if(!(validate580(data65.attachment, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/attachment",parentData:data65,parentDataProperty:"attachment",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate580.errors : vErrors.concat(validate580.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err152 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/9/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err152];
}
else {
vErrors.push(err152);
}
errors++;
}
}
var _valid6 = _errs243 === errors;
if(_valid6 && valid33){
valid33 = false;
passing4 = [passing4, 9];
}
else {
if(_valid6){
valid33 = true;
passing4 = 9;
if(props13 !== true){
props13 = true;
}
}
const _errs247 = errors;
if(errors === _errs247){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing43;
if((data65.subscription === undefined) && (missing43 = "subscription")){
const err153 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/10/required",keyword:"required",params:{missingProperty: missing43}};
if(vErrors === null){
vErrors = [err153];
}
else {
vErrors.push(err153);
}
errors++;
}
else {
const _errs249 = errors;
for(const key43 in data65){
if(!(key43 === "subscription")){
const err154 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/10/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key43}};
if(vErrors === null){
vErrors = [err154];
}
else {
vErrors.push(err154);
}
errors++;
break;
}
}
if(_errs249 === errors){
if(data65.subscription !== undefined){
let data105 = data65.subscription;
const _errs250 = errors;
if(errors === _errs250){
if(data105 && typeof data105 == "object" && !Array.isArray(data105)){
let missing44;
if(((((data105.expected === undefined) && (missing44 = "expected")) || ((data105.actual === undefined) && (missing44 = "actual"))) || ((data105.requested === undefined) && (missing44 = "requested"))) || ((data105.active === undefined) && (missing44 = "active"))){
const err155 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/subscription",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/10/properties/subscription/required",keyword:"required",params:{missingProperty: missing44}};
if(vErrors === null){
vErrors = [err155];
}
else {
vErrors.push(err155);
}
errors++;
}
else {
const _errs252 = errors;
for(const key44 in data105){
if(!((((key44 === "expected") || (key44 === "actual")) || (key44 === "requested")) || (key44 === "active"))){
const err156 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/subscription",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/10/properties/subscription/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key44}};
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
if(_errs252 === errors){
if(data105.expected !== undefined){
const _errs253 = errors;
if(!(validate56(data105.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/subscription/expected",parentData:data105,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid51 = _errs253 === errors;
}
else {
var valid51 = true;
}
if(valid51){
if(data105.actual !== undefined){
const _errs254 = errors;
if(!(validate56(data105.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/subscription/actual",parentData:data105,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid51 = _errs254 === errors;
}
else {
var valid51 = true;
}
if(valid51){
if(data105.requested !== undefined){
const _errs255 = errors;
if(!(validate56(data105.requested, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/subscription/requested",parentData:data105,parentDataProperty:"requested",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid51 = _errs255 === errors;
}
else {
var valid51 = true;
}
if(valid51){
if(data105.active !== undefined){
const _errs256 = errors;
if(!(validate56(data105.active, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/subscription/active",parentData:data105,parentDataProperty:"active",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid51 = _errs256 === errors;
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
else {
const err157 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/subscription",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/10/properties/subscription/type",keyword:"type",params:{type: "object"}};
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
}
}
else {
const err158 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/10/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err158];
}
else {
vErrors.push(err158);
}
errors++;
}
}
var _valid6 = _errs247 === errors;
if(_valid6 && valid33){
valid33 = false;
passing4 = [passing4, 10];
}
else {
if(_valid6){
valid33 = true;
passing4 = 10;
if(props13 !== true){
props13 = true;
}
}
const _errs257 = errors;
if(errors === _errs257){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing45;
if((data65.renewal === undefined) && (missing45 = "renewal")){
const err159 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/11/required",keyword:"required",params:{missingProperty: missing45}};
if(vErrors === null){
vErrors = [err159];
}
else {
vErrors.push(err159);
}
errors++;
}
else {
const _errs259 = errors;
for(const key45 in data65){
if(!(key45 === "renewal")){
const err160 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/11/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key45}};
if(vErrors === null){
vErrors = [err160];
}
else {
vErrors.push(err160);
}
errors++;
break;
}
}
if(_errs259 === errors){
if(data65.renewal !== undefined){
let data110 = data65.renewal;
const _errs260 = errors;
if(errors === _errs260){
if(data110 && typeof data110 == "object" && !Array.isArray(data110)){
let missing46;
if((((data110.expected === undefined) && (missing46 = "expected")) || ((data110.actual === undefined) && (missing46 = "actual"))) || ((data110.proposed === undefined) && (missing46 = "proposed"))){
const err161 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/renewal",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/11/properties/renewal/required",keyword:"required",params:{missingProperty: missing46}};
if(vErrors === null){
vErrors = [err161];
}
else {
vErrors.push(err161);
}
errors++;
}
else {
const _errs262 = errors;
for(const key46 in data110){
if(!(((key46 === "expected") || (key46 === "actual")) || (key46 === "proposed"))){
const err162 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/renewal",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/11/properties/renewal/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key46}};
if(vErrors === null){
vErrors = [err162];
}
else {
vErrors.push(err162);
}
errors++;
break;
}
}
if(_errs262 === errors){
if(data110.expected !== undefined){
const _errs263 = errors;
if(!(validate56(data110.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/renewal/expected",parentData:data110,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid53 = _errs263 === errors;
}
else {
var valid53 = true;
}
if(valid53){
if(data110.actual !== undefined){
const _errs264 = errors;
if(!(validate56(data110.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/renewal/actual",parentData:data110,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid53 = _errs264 === errors;
}
else {
var valid53 = true;
}
if(valid53){
if(data110.proposed !== undefined){
const _errs265 = errors;
if(!(validate56(data110.proposed, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/renewal/proposed",parentData:data110,parentDataProperty:"proposed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid53 = _errs265 === errors;
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
const err163 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/renewal",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/11/properties/renewal/type",keyword:"type",params:{type: "object"}};
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
const err164 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/11/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err164];
}
else {
vErrors.push(err164);
}
errors++;
}
}
var _valid6 = _errs257 === errors;
if(_valid6 && valid33){
valid33 = false;
passing4 = [passing4, 11];
}
else {
if(_valid6){
valid33 = true;
passing4 = 11;
if(props13 !== true){
props13 = true;
}
}
const _errs266 = errors;
if(errors === _errs266){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing47;
if((data65.binding === undefined) && (missing47 = "binding")){
const err165 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/12/required",keyword:"required",params:{missingProperty: missing47}};
if(vErrors === null){
vErrors = [err165];
}
else {
vErrors.push(err165);
}
errors++;
}
else {
const _errs268 = errors;
for(const key47 in data65){
if(!(key47 === "binding")){
const err166 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/12/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key47}};
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
if(_errs268 === errors){
if(data65.binding !== undefined){
let data114 = data65.binding;
const _errs269 = errors;
if(errors === _errs269){
if(data114 && typeof data114 == "object" && !Array.isArray(data114)){
let missing48;
if((((((((data114.expected === undefined) && (missing48 = "expected")) || ((data114.actual === undefined) && (missing48 = "actual"))) || ((data114.expected_codec === undefined) && (missing48 = "expected_codec"))) || ((data114.actual_codec === undefined) && (missing48 = "actual_codec"))) || ((data114.target === undefined) && (missing48 = "target"))) || ((data114.present === undefined) && (missing48 = "present"))) || ((data114.published === undefined) && (missing48 = "published"))){
const err167 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/binding",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/12/properties/binding/required",keyword:"required",params:{missingProperty: missing48}};
if(vErrors === null){
vErrors = [err167];
}
else {
vErrors.push(err167);
}
errors++;
}
else {
const _errs271 = errors;
for(const key48 in data114){
if(!(((((((key48 === "expected") || (key48 === "actual")) || (key48 === "expected_codec")) || (key48 === "actual_codec")) || (key48 === "target")) || (key48 === "present")) || (key48 === "published"))){
const err168 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/binding",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/12/properties/binding/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key48}};
if(vErrors === null){
vErrors = [err168];
}
else {
vErrors.push(err168);
}
errors++;
break;
}
}
if(_errs271 === errors){
if(data114.expected !== undefined){
const _errs272 = errors;
if(!(validate56(data114.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/binding/expected",parentData:data114,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid55 = _errs272 === errors;
}
else {
var valid55 = true;
}
if(valid55){
if(data114.actual !== undefined){
const _errs273 = errors;
if(!(validate56(data114.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/binding/actual",parentData:data114,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid55 = _errs273 === errors;
}
else {
var valid55 = true;
}
if(valid55){
if(data114.expected_codec !== undefined){
const _errs274 = errors;
if(!(validate164(data114.expected_codec, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/binding/expected_codec",parentData:data114,parentDataProperty:"expected_codec",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate164.errors : vErrors.concat(validate164.errors);
errors = vErrors.length;
}
var valid55 = _errs274 === errors;
}
else {
var valid55 = true;
}
if(valid55){
if(data114.actual_codec !== undefined){
const _errs275 = errors;
if(!(validate164(data114.actual_codec, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/binding/actual_codec",parentData:data114,parentDataProperty:"actual_codec",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate164.errors : vErrors.concat(validate164.errors);
errors = vErrors.length;
}
var valid55 = _errs275 === errors;
}
else {
var valid55 = true;
}
if(valid55){
if(data114.target !== undefined){
const _errs276 = errors;
if(!(validate56(data114.target, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/binding/target",parentData:data114,parentDataProperty:"target",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid55 = _errs276 === errors;
}
else {
var valid55 = true;
}
if(valid55){
if(data114.present !== undefined){
const _errs277 = errors;
if(typeof data114.present !== "boolean"){
const err169 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/binding/present",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/12/properties/binding/properties/present/type",keyword:"type",params:{type: "boolean"}};
if(vErrors === null){
vErrors = [err169];
}
else {
vErrors.push(err169);
}
errors++;
}
var valid55 = _errs277 === errors;
}
else {
var valid55 = true;
}
if(valid55){
if(data114.published !== undefined){
const _errs279 = errors;
if(typeof data114.published !== "boolean"){
const err170 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/binding/published",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/12/properties/binding/properties/published/type",keyword:"type",params:{type: "boolean"}};
if(vErrors === null){
vErrors = [err170];
}
else {
vErrors.push(err170);
}
errors++;
}
var valid55 = _errs279 === errors;
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
}
}
else {
const err171 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/binding",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/12/properties/binding/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err171];
}
else {
vErrors.push(err171);
}
errors++;
}
}
}
}
}
}
else {
const err172 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/12/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err172];
}
else {
vErrors.push(err172);
}
errors++;
}
}
var _valid6 = _errs266 === errors;
if(_valid6 && valid33){
valid33 = false;
passing4 = [passing4, 12];
}
else {
if(_valid6){
valid33 = true;
passing4 = 12;
if(props13 !== true){
props13 = true;
}
}
const _errs281 = errors;
if(errors === _errs281){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing49;
if((data65.refresh === undefined) && (missing49 = "refresh")){
const err173 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/13/required",keyword:"required",params:{missingProperty: missing49}};
if(vErrors === null){
vErrors = [err173];
}
else {
vErrors.push(err173);
}
errors++;
}
else {
const _errs283 = errors;
for(const key49 in data65){
if(!(key49 === "refresh")){
const err174 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/13/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key49}};
if(vErrors === null){
vErrors = [err174];
}
else {
vErrors.push(err174);
}
errors++;
break;
}
}
if(_errs283 === errors){
if(data65.refresh !== undefined){
let data122 = data65.refresh;
const _errs284 = errors;
if(errors === _errs284){
if(data122 && typeof data122 == "object" && !Array.isArray(data122)){
let missing50;
if((((data122.expected === undefined) && (missing50 = "expected")) || ((data122.actual === undefined) && (missing50 = "actual"))) || ((data122.phase === undefined) && (missing50 = "phase"))){
const err175 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/refresh",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/13/properties/refresh/required",keyword:"required",params:{missingProperty: missing50}};
if(vErrors === null){
vErrors = [err175];
}
else {
vErrors.push(err175);
}
errors++;
}
else {
const _errs286 = errors;
for(const key50 in data122){
if(!(((key50 === "expected") || (key50 === "actual")) || (key50 === "phase"))){
const err176 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/refresh",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/13/properties/refresh/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key50}};
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
if(_errs286 === errors){
if(data122.expected !== undefined){
const _errs287 = errors;
if(!(validate225(data122.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/refresh/expected",parentData:data122,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
errors = vErrors.length;
}
var valid57 = _errs287 === errors;
}
else {
var valid57 = true;
}
if(valid57){
if(data122.actual !== undefined){
const _errs288 = errors;
if(!(validate225(data122.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/refresh/actual",parentData:data122,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
errors = vErrors.length;
}
var valid57 = _errs288 === errors;
}
else {
var valid57 = true;
}
if(valid57){
if(data122.phase !== undefined){
const _errs289 = errors;
if(!(validate565(data122.phase, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/refresh/phase",parentData:data122,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate565.errors : vErrors.concat(validate565.errors);
errors = vErrors.length;
}
var valid57 = _errs289 === errors;
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
const err177 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/refresh",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/13/properties/refresh/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err177];
}
else {
vErrors.push(err177);
}
errors++;
}
}
}
}
}
}
else {
const err178 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/13/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err178];
}
else {
vErrors.push(err178);
}
errors++;
}
}
var _valid6 = _errs281 === errors;
if(_valid6 && valid33){
valid33 = false;
passing4 = [passing4, 13];
}
else {
if(_valid6){
valid33 = true;
passing4 = 13;
if(props13 !== true){
props13 = true;
}
}
const _errs290 = errors;
if(errors === _errs290){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing51;
if((data65.frame === undefined) && (missing51 = "frame")){
const err179 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/14/required",keyword:"required",params:{missingProperty: missing51}};
if(vErrors === null){
vErrors = [err179];
}
else {
vErrors.push(err179);
}
errors++;
}
else {
const _errs292 = errors;
for(const key51 in data65){
if(!(key51 === "frame")){
const err180 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/14/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key51}};
if(vErrors === null){
vErrors = [err180];
}
else {
vErrors.push(err180);
}
errors++;
break;
}
}
if(_errs292 === errors){
if(data65.frame !== undefined){
let data126 = data65.frame;
const _errs293 = errors;
if(errors === _errs293){
if(data126 && typeof data126 == "object" && !Array.isArray(data126)){
let missing52;
if(((((data126.correlation === undefined) && (missing52 = "correlation")) || ((data126.expected === undefined) && (missing52 = "expected"))) || ((data126.actual === undefined) && (missing52 = "actual"))) || ((data126.kind === undefined) && (missing52 = "kind"))){
const err181 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/frame",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/14/properties/frame/required",keyword:"required",params:{missingProperty: missing52}};
if(vErrors === null){
vErrors = [err181];
}
else {
vErrors.push(err181);
}
errors++;
}
else {
const _errs295 = errors;
for(const key52 in data126){
if(!(((((key52 === "correlation") || (key52 === "expected")) || (key52 === "actual")) || (key52 === "kind")) || (key52 === "actual_known"))){
const err182 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/frame",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/14/properties/frame/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key52}};
if(vErrors === null){
vErrors = [err182];
}
else {
vErrors.push(err182);
}
errors++;
break;
}
}
if(_errs295 === errors){
if(data126.correlation !== undefined){
const _errs296 = errors;
if(!(validate56(data126.correlation, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/frame/correlation",parentData:data126,parentDataProperty:"correlation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid59 = _errs296 === errors;
}
else {
var valid59 = true;
}
if(valid59){
if(data126.expected !== undefined){
const _errs297 = errors;
if(!(validate56(data126.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/frame/expected",parentData:data126,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid59 = _errs297 === errors;
}
else {
var valid59 = true;
}
if(valid59){
if(data126.actual !== undefined){
const _errs298 = errors;
if(!(validate56(data126.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/frame/actual",parentData:data126,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid59 = _errs298 === errors;
}
else {
var valid59 = true;
}
if(valid59){
if(data126.kind !== undefined){
let data130 = data126.kind;
const _errs299 = errors;
if(typeof data130 !== "string"){
const err183 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/frame/kind",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/14/properties/frame/properties/kind/type",keyword:"type",params:{type: "string"}};
if(vErrors === null){
vErrors = [err183];
}
else {
vErrors.push(err183);
}
errors++;
}
if(!((((data130 === "reply_source") || (data130 === "observer")) || (data130 === "timer")) || (data130 === "administrator"))){
const err184 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/frame/kind",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/14/properties/frame/properties/kind/enum",keyword:"enum",params:{allowedValues: schema126.oneOf[9].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[14].properties.frame.properties.kind.enum}};
if(vErrors === null){
vErrors = [err184];
}
else {
vErrors.push(err184);
}
errors++;
}
var valid59 = _errs299 === errors;
}
else {
var valid59 = true;
}
if(valid59){
if(data126.actual_known !== undefined){
const _errs301 = errors;
if(typeof data126.actual_known !== "boolean"){
const err185 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/frame/actual_known",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/14/properties/frame/properties/actual_known/type",keyword:"type",params:{type: "boolean"}};
if(vErrors === null){
vErrors = [err185];
}
else {
vErrors.push(err185);
}
errors++;
}
var valid59 = _errs301 === errors;
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
else {
const err186 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/frame",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/14/properties/frame/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err186];
}
else {
vErrors.push(err186);
}
errors++;
}
}
}
}
}
}
else {
const err187 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/14/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err187];
}
else {
vErrors.push(err187);
}
errors++;
}
}
var _valid6 = _errs290 === errors;
if(_valid6 && valid33){
valid33 = false;
passing4 = [passing4, 14];
}
else {
if(_valid6){
valid33 = true;
passing4 = 14;
if(props13 !== true){
props13 = true;
}
}
const _errs303 = errors;
if(errors === _errs303){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing53;
if((data65.target === undefined) && (missing53 = "target")){
const err188 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/15/required",keyword:"required",params:{missingProperty: missing53}};
if(vErrors === null){
vErrors = [err188];
}
else {
vErrors.push(err188);
}
errors++;
}
else {
const _errs305 = errors;
for(const key53 in data65){
if(!(key53 === "target")){
const err189 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/15/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key53}};
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
if(_errs305 === errors){
if(data65.target !== undefined){
let data132 = data65.target;
const _errs306 = errors;
if(errors === _errs306){
if(data132 && typeof data132 == "object" && !Array.isArray(data132)){
let missing54;
if((((data132.expected === undefined) && (missing54 = "expected")) || ((data132.actual === undefined) && (missing54 = "actual"))) || ((data132.kind === undefined) && (missing54 = "kind"))){
const err190 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/target",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/15/properties/target/required",keyword:"required",params:{missingProperty: missing54}};
if(vErrors === null){
vErrors = [err190];
}
else {
vErrors.push(err190);
}
errors++;
}
else {
const _errs308 = errors;
for(const key54 in data132){
if(!(((key54 === "expected") || (key54 === "actual")) || (key54 === "kind"))){
const err191 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/target",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/15/properties/target/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key54}};
if(vErrors === null){
vErrors = [err191];
}
else {
vErrors.push(err191);
}
errors++;
break;
}
}
if(_errs308 === errors){
if(data132.expected !== undefined){
const _errs309 = errors;
if(!(validate56(data132.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/target/expected",parentData:data132,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid61 = _errs309 === errors;
}
else {
var valid61 = true;
}
if(valid61){
if(data132.actual !== undefined){
const _errs310 = errors;
if(!(validate56(data132.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/target/actual",parentData:data132,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid61 = _errs310 === errors;
}
else {
var valid61 = true;
}
if(valid61){
if(data132.kind !== undefined){
let data135 = data132.kind;
const _errs311 = errors;
if(typeof data135 !== "string"){
const err192 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/target/kind",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/15/properties/target/properties/kind/type",keyword:"type",params:{type: "string"}};
if(vErrors === null){
vErrors = [err192];
}
else {
vErrors.push(err192);
}
errors++;
}
if(!(((data135 === "source") || (data135 === "resource")) || (data135 === "partition"))){
const err193 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/target/kind",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/15/properties/target/properties/kind/enum",keyword:"enum",params:{allowedValues: schema126.oneOf[9].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[15].properties.target.properties.kind.enum}};
if(vErrors === null){
vErrors = [err193];
}
else {
vErrors.push(err193);
}
errors++;
}
var valid61 = _errs311 === errors;
}
else {
var valid61 = true;
}
}
}
}
}
}
else {
const err194 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/target",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/15/properties/target/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err194];
}
else {
vErrors.push(err194);
}
errors++;
}
}
}
}
}
}
else {
const err195 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/15/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err195];
}
else {
vErrors.push(err195);
}
errors++;
}
}
var _valid6 = _errs303 === errors;
if(_valid6 && valid33){
valid33 = false;
passing4 = [passing4, 15];
}
else {
if(_valid6){
valid33 = true;
passing4 = 15;
if(props13 !== true){
props13 = true;
}
}
const _errs313 = errors;
if(errors === _errs313){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing55;
if((data65.basis === undefined) && (missing55 = "basis")){
const err196 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/16/required",keyword:"required",params:{missingProperty: missing55}};
if(vErrors === null){
vErrors = [err196];
}
else {
vErrors.push(err196);
}
errors++;
}
else {
const _errs315 = errors;
for(const key55 in data65){
if(!(key55 === "basis")){
const err197 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/16/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key55}};
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
if(_errs315 === errors){
if(data65.basis !== undefined){
let data136 = data65.basis;
const _errs316 = errors;
if(errors === _errs316){
if(data136 && typeof data136 == "object" && !Array.isArray(data136)){
let missing56;
if((((data136.expected === undefined) && (missing56 = "expected")) || ((data136.actual === undefined) && (missing56 = "actual"))) || ((data136.kind === undefined) && (missing56 = "kind"))){
const err198 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/basis",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/16/properties/basis/required",keyword:"required",params:{missingProperty: missing56}};
if(vErrors === null){
vErrors = [err198];
}
else {
vErrors.push(err198);
}
errors++;
}
else {
const _errs318 = errors;
for(const key56 in data136){
if(!(((key56 === "expected") || (key56 === "actual")) || (key56 === "kind"))){
const err199 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/basis",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/16/properties/basis/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key56}};
if(vErrors === null){
vErrors = [err199];
}
else {
vErrors.push(err199);
}
errors++;
break;
}
}
if(_errs318 === errors){
if(data136.expected !== undefined){
const _errs319 = errors;
if(!(validate64(data136.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/basis/expected",parentData:data136,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
errors = vErrors.length;
}
var valid63 = _errs319 === errors;
}
else {
var valid63 = true;
}
if(valid63){
if(data136.actual !== undefined){
const _errs320 = errors;
if(!(validate64(data136.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/basis/actual",parentData:data136,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
errors = vErrors.length;
}
var valid63 = _errs320 === errors;
}
else {
var valid63 = true;
}
if(valid63){
if(data136.kind !== undefined){
let data139 = data136.kind;
const _errs321 = errors;
if(typeof data139 !== "string"){
const err200 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/basis/kind",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/16/properties/basis/properties/kind/type",keyword:"type",params:{type: "string"}};
if(vErrors === null){
vErrors = [err200];
}
else {
vErrors.push(err200);
}
errors++;
}
if(!(((data139 === "schema") || (data139 === "contract")) || (data139 === "metadata"))){
const err201 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/basis/kind",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/16/properties/basis/properties/kind/enum",keyword:"enum",params:{allowedValues: schema126.oneOf[9].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[16].properties.basis.properties.kind.enum}};
if(vErrors === null){
vErrors = [err201];
}
else {
vErrors.push(err201);
}
errors++;
}
var valid63 = _errs321 === errors;
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
const err202 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/basis",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/16/properties/basis/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err202];
}
else {
vErrors.push(err202);
}
errors++;
}
}
}
}
}
}
else {
const err203 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/16/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err203];
}
else {
vErrors.push(err203);
}
errors++;
}
}
var _valid6 = _errs313 === errors;
if(_valid6 && valid33){
valid33 = false;
passing4 = [passing4, 16];
}
else {
if(_valid6){
valid33 = true;
passing4 = 16;
if(props13 !== true){
props13 = true;
}
}
const _errs323 = errors;
if(errors === _errs323){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing57;
if((data65.source_kind === undefined) && (missing57 = "source_kind")){
const err204 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/17/required",keyword:"required",params:{missingProperty: missing57}};
if(vErrors === null){
vErrors = [err204];
}
else {
vErrors.push(err204);
}
errors++;
}
else {
const _errs325 = errors;
for(const key57 in data65){
if(!(key57 === "source_kind")){
const err205 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/17/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key57}};
if(vErrors === null){
vErrors = [err205];
}
else {
vErrors.push(err205);
}
errors++;
break;
}
}
if(_errs325 === errors){
if(data65.source_kind !== undefined){
let data140 = data65.source_kind;
const _errs326 = errors;
if(errors === _errs326){
if(data140 && typeof data140 == "object" && !Array.isArray(data140)){
let missing58;
if(((data140.expected === undefined) && (missing58 = "expected")) || ((data140.actual === undefined) && (missing58 = "actual"))){
const err206 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source_kind",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/17/properties/source_kind/required",keyword:"required",params:{missingProperty: missing58}};
if(vErrors === null){
vErrors = [err206];
}
else {
vErrors.push(err206);
}
errors++;
}
else {
const _errs328 = errors;
for(const key58 in data140){
if(!((key58 === "expected") || (key58 === "actual"))){
const err207 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source_kind",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/17/properties/source_kind/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key58}};
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
if(_errs328 === errors){
if(data140.expected !== undefined){
const _errs329 = errors;
if(!(validate618(data140.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source_kind/expected",parentData:data140,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate618.errors : vErrors.concat(validate618.errors);
errors = vErrors.length;
}
var valid65 = _errs329 === errors;
}
else {
var valid65 = true;
}
if(valid65){
if(data140.actual !== undefined){
const _errs330 = errors;
if(!(validate618(data140.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source_kind/actual",parentData:data140,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate618.errors : vErrors.concat(validate618.errors);
errors = vErrors.length;
}
var valid65 = _errs330 === errors;
}
else {
var valid65 = true;
}
}
}
}
}
else {
const err208 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/source_kind",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/17/properties/source_kind/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err208];
}
else {
vErrors.push(err208);
}
errors++;
}
}
}
}
}
}
else {
const err209 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/17/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err209];
}
else {
vErrors.push(err209);
}
errors++;
}
}
var _valid6 = _errs323 === errors;
if(_valid6 && valid33){
valid33 = false;
passing4 = [passing4, 17];
}
else {
if(_valid6){
valid33 = true;
passing4 = 17;
if(props13 !== true){
props13 = true;
}
}
const _errs331 = errors;
if(errors === _errs331){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing59;
if((data65.table === undefined) && (missing59 = "table")){
const err210 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/18/required",keyword:"required",params:{missingProperty: missing59}};
if(vErrors === null){
vErrors = [err210];
}
else {
vErrors.push(err210);
}
errors++;
}
else {
const _errs333 = errors;
for(const key59 in data65){
if(!(key59 === "table")){
const err211 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/18/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key59}};
if(vErrors === null){
vErrors = [err211];
}
else {
vErrors.push(err211);
}
errors++;
break;
}
}
if(_errs333 === errors){
if(data65.table !== undefined){
if(!(validate225(data65.table, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/table",parentData:data65,parentDataProperty:"table",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err212 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/18/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err212];
}
else {
vErrors.push(err212);
}
errors++;
}
}
var _valid6 = _errs331 === errors;
if(_valid6 && valid33){
valid33 = false;
passing4 = [passing4, 18];
}
else {
if(_valid6){
valid33 = true;
passing4 = 18;
if(props13 !== true){
props13 = true;
}
}
const _errs335 = errors;
if(errors === _errs335){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing60;
if((data65.watch_type === undefined) && (missing60 = "watch_type")){
const err213 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/19/required",keyword:"required",params:{missingProperty: missing60}};
if(vErrors === null){
vErrors = [err213];
}
else {
vErrors.push(err213);
}
errors++;
}
else {
const _errs337 = errors;
for(const key60 in data65){
if(!(key60 === "watch_type")){
const err214 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/19/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key60}};
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
if(_errs337 === errors){
if(data65.watch_type !== undefined){
let data144 = data65.watch_type;
const _errs338 = errors;
if(errors === _errs338){
if(data144 && typeof data144 == "object" && !Array.isArray(data144)){
let missing61;
if(((data144.expected === undefined) && (missing61 = "expected")) || ((data144.actual === undefined) && (missing61 = "actual"))){
const err215 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_type",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/19/properties/watch_type/required",keyword:"required",params:{missingProperty: missing61}};
if(vErrors === null){
vErrors = [err215];
}
else {
vErrors.push(err215);
}
errors++;
}
else {
const _errs340 = errors;
for(const key61 in data144){
if(!(((key61 === "expected") || (key61 === "actual")) || (key61 === "column"))){
const err216 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_type",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/19/properties/watch_type/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key61}};
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
if(_errs340 === errors){
if(data144.expected !== undefined){
const _errs341 = errors;
if(!(validate622(data144.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_type/expected",parentData:data144,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate622.errors : vErrors.concat(validate622.errors);
errors = vErrors.length;
}
var valid68 = _errs341 === errors;
}
else {
var valid68 = true;
}
if(valid68){
if(data144.actual !== undefined){
const _errs342 = errors;
if(!(validate622(data144.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_type/actual",parentData:data144,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate622.errors : vErrors.concat(validate622.errors);
errors = vErrors.length;
}
var valid68 = _errs342 === errors;
}
else {
var valid68 = true;
}
if(valid68){
if(data144.column !== undefined){
const _errs343 = errors;
if(!(validate65(data144.column, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_type/column",parentData:data144,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
errors = vErrors.length;
}
var valid68 = _errs343 === errors;
}
else {
var valid68 = true;
}
}
}
}
}
}
else {
const err217 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_type",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/19/properties/watch_type/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err217];
}
else {
vErrors.push(err217);
}
errors++;
}
}
}
}
}
}
else {
const err218 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/19/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err218];
}
else {
vErrors.push(err218);
}
errors++;
}
}
var _valid6 = _errs335 === errors;
if(_valid6 && valid33){
valid33 = false;
passing4 = [passing4, 19];
}
else {
if(_valid6){
valid33 = true;
passing4 = 19;
if(props13 !== true){
props13 = true;
}
}
const _errs344 = errors;
if(errors === _errs344){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing62;
if((data65.progress === undefined) && (missing62 = "progress")){
const err219 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/20/required",keyword:"required",params:{missingProperty: missing62}};
if(vErrors === null){
vErrors = [err219];
}
else {
vErrors.push(err219);
}
errors++;
}
else {
const _errs346 = errors;
for(const key62 in data65){
if(!(key62 === "progress")){
const err220 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/20/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key62}};
if(vErrors === null){
vErrors = [err220];
}
else {
vErrors.push(err220);
}
errors++;
break;
}
}
if(_errs346 === errors){
if(data65.progress !== undefined){
let data148 = data65.progress;
const _errs347 = errors;
if(errors === _errs347){
if(data148 && typeof data148 == "object" && !Array.isArray(data148)){
let missing63;
if((((((data148.present === undefined) && (missing63 = "present")) || ((data148.actual === undefined) && (missing63 = "actual"))) || ((data148.limit === undefined) && (missing63 = "limit"))) || ((data148.key === undefined) && (missing63 = "key"))) || ((data148.length === undefined) && (missing63 = "length"))){
const err221 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/progress",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/20/properties/progress/required",keyword:"required",params:{missingProperty: missing63}};
if(vErrors === null){
vErrors = [err221];
}
else {
vErrors.push(err221);
}
errors++;
}
else {
const _errs349 = errors;
for(const key63 in data148){
if(!(((((key63 === "present") || (key63 === "actual")) || (key63 === "limit")) || (key63 === "key")) || (key63 === "length"))){
const err222 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/progress",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/20/properties/progress/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key63}};
if(vErrors === null){
vErrors = [err222];
}
else {
vErrors.push(err222);
}
errors++;
break;
}
}
if(_errs349 === errors){
if(data148.present !== undefined){
const _errs350 = errors;
if(typeof data148.present !== "boolean"){
const err223 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/progress/present",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/20/properties/progress/properties/present/type",keyword:"type",params:{type: "boolean"}};
if(vErrors === null){
vErrors = [err223];
}
else {
vErrors.push(err223);
}
errors++;
}
var valid70 = _errs350 === errors;
}
else {
var valid70 = true;
}
if(valid70){
if(data148.actual !== undefined){
const _errs352 = errors;
if(!(validate56(data148.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/progress/actual",parentData:data148,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid70 = _errs352 === errors;
}
else {
var valid70 = true;
}
if(valid70){
if(data148.limit !== undefined){
const _errs353 = errors;
if(!(validate56(data148.limit, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/progress/limit",parentData:data148,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid70 = _errs353 === errors;
}
else {
var valid70 = true;
}
if(valid70){
if(data148.key !== undefined){
const _errs354 = errors;
if(!(validate64(data148.key, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/progress/key",parentData:data148,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
errors = vErrors.length;
}
var valid70 = _errs354 === errors;
}
else {
var valid70 = true;
}
if(valid70){
if(data148.length !== undefined){
const _errs355 = errors;
if(!(validate65(data148.length, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/progress/length",parentData:data148,parentDataProperty:"length",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
errors = vErrors.length;
}
var valid70 = _errs355 === errors;
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
const err224 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/progress",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/20/properties/progress/type",keyword:"type",params:{type: "object"}};
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
const err225 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/20/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err225];
}
else {
vErrors.push(err225);
}
errors++;
}
}
var _valid6 = _errs344 === errors;
if(_valid6 && valid33){
valid33 = false;
passing4 = [passing4, 20];
}
else {
if(_valid6){
valid33 = true;
passing4 = 20;
if(props13 !== true){
props13 = true;
}
}
const _errs356 = errors;
if(errors === _errs356){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing64;
if((data65.reader_identity === undefined) && (missing64 = "reader_identity")){
const err226 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/21/required",keyword:"required",params:{missingProperty: missing64}};
if(vErrors === null){
vErrors = [err226];
}
else {
vErrors.push(err226);
}
errors++;
}
else {
const _errs358 = errors;
for(const key64 in data65){
if(!(key64 === "reader_identity")){
const err227 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/21/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key64}};
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
if(_errs358 === errors){
if(data65.reader_identity !== undefined){
let data154 = data65.reader_identity;
const _errs359 = errors;
if(errors === _errs359){
if(data154 && typeof data154 == "object" && !Array.isArray(data154)){
let missing65;
if((((data154.field === undefined) && (missing65 = "field")) || ((data154.expected === undefined) && (missing65 = "expected"))) || ((data154.actual === undefined) && (missing65 = "actual"))){
const err228 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_identity",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/21/properties/reader_identity/required",keyword:"required",params:{missingProperty: missing65}};
if(vErrors === null){
vErrors = [err228];
}
else {
vErrors.push(err228);
}
errors++;
}
else {
const _errs361 = errors;
for(const key65 in data154){
if(!((((((key65 === "field") || (key65 === "expected")) || (key65 === "actual")) || (key65 === "present")) || (key65 === "policy_revision")) || (key65 === "policy_known"))){
const err229 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_identity",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/21/properties/reader_identity/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key65}};
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
if(_errs361 === errors){
if(data154.field !== undefined){
let data155 = data154.field;
const _errs362 = errors;
if(typeof data155 !== "string"){
const err230 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_identity/field",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/21/properties/reader_identity/properties/field/type",keyword:"type",params:{type: "string"}};
if(vErrors === null){
vErrors = [err230];
}
else {
vErrors.push(err230);
}
errors++;
}
if(!((((data155 === "principal") || (data155 === "pid")) || (data155 === "permissions")) || (data155 === "turn_pid"))){
const err231 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_identity/field",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/21/properties/reader_identity/properties/field/enum",keyword:"enum",params:{allowedValues: schema126.oneOf[9].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[21].properties.reader_identity.properties.field.enum}};
if(vErrors === null){
vErrors = [err231];
}
else {
vErrors.push(err231);
}
errors++;
}
var valid72 = _errs362 === errors;
}
else {
var valid72 = true;
}
if(valid72){
if(data154.expected !== undefined){
const _errs364 = errors;
if(!(validate56(data154.expected, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_identity/expected",parentData:data154,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid72 = _errs364 === errors;
}
else {
var valid72 = true;
}
if(valid72){
if(data154.actual !== undefined){
const _errs365 = errors;
if(!(validate56(data154.actual, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_identity/actual",parentData:data154,parentDataProperty:"actual",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid72 = _errs365 === errors;
}
else {
var valid72 = true;
}
if(valid72){
if(data154.present !== undefined){
const _errs366 = errors;
if(typeof data154.present !== "boolean"){
const err232 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_identity/present",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/21/properties/reader_identity/properties/present/type",keyword:"type",params:{type: "boolean"}};
if(vErrors === null){
vErrors = [err232];
}
else {
vErrors.push(err232);
}
errors++;
}
var valid72 = _errs366 === errors;
}
else {
var valid72 = true;
}
if(valid72){
if(data154.policy_revision !== undefined){
const _errs368 = errors;
if(!(validate56(data154.policy_revision, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_identity/policy_revision",parentData:data154,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid72 = _errs368 === errors;
}
else {
var valid72 = true;
}
if(valid72){
if(data154.policy_known !== undefined){
const _errs369 = errors;
if(typeof data154.policy_known !== "boolean"){
const err233 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_identity/policy_known",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/21/properties/reader_identity/properties/policy_known/type",keyword:"type",params:{type: "boolean"}};
if(vErrors === null){
vErrors = [err233];
}
else {
vErrors.push(err233);
}
errors++;
}
var valid72 = _errs369 === errors;
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
else {
const err234 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_identity",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/21/properties/reader_identity/type",keyword:"type",params:{type: "object"}};
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
const err235 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/21/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err235];
}
else {
vErrors.push(err235);
}
errors++;
}
}
var _valid6 = _errs356 === errors;
if(_valid6 && valid33){
valid33 = false;
passing4 = [passing4, 21];
}
else {
if(_valid6){
valid33 = true;
passing4 = 21;
if(props13 !== true){
props13 = true;
}
}
const _errs371 = errors;
if(errors === _errs371){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing66;
if((data65.reader_failure === undefined) && (missing66 = "reader_failure")){
const err236 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/22/required",keyword:"required",params:{missingProperty: missing66}};
if(vErrors === null){
vErrors = [err236];
}
else {
vErrors.push(err236);
}
errors++;
}
else {
const _errs373 = errors;
for(const key66 in data65){
if(!(key66 === "reader_failure")){
const err237 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/22/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key66}};
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
if(_errs373 === errors){
if(data65.reader_failure !== undefined){
let data161 = data65.reader_failure;
const _errs374 = errors;
if(errors === _errs374){
if(data161 && typeof data161 == "object" && !Array.isArray(data161)){
let missing67;
if(((((data161.operation === undefined) && (missing67 = "operation")) || ((data161.principal === undefined) && (missing67 = "principal"))) || ((data161.resource === undefined) && (missing67 = "resource"))) || ((data161.cause === undefined) && (missing67 = "cause"))){
const err238 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_failure",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/22/properties/reader_failure/required",keyword:"required",params:{missingProperty: missing67}};
if(vErrors === null){
vErrors = [err238];
}
else {
vErrors.push(err238);
}
errors++;
}
else {
const _errs376 = errors;
for(const key67 in data161){
if(!(((((key67 === "operation") || (key67 === "principal")) || (key67 === "resource")) || (key67 === "namespace")) || (key67 === "cause"))){
const err239 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_failure",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/22/properties/reader_failure/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key67}};
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
if(_errs376 === errors){
if(data161.operation !== undefined){
let data162 = data161.operation;
const _errs377 = errors;
if(typeof data162 !== "string"){
const err240 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_failure/operation",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/22/properties/reader_failure/properties/operation/type",keyword:"type",params:{type: "string"}};
if(vErrors === null){
vErrors = [err240];
}
else {
vErrors.push(err240);
}
errors++;
}
if(!((((data162 === "identity") || (data162 === "source")) || (data162 === "requester")) || (data162 === "result"))){
const err241 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_failure/operation",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/22/properties/reader_failure/properties/operation/enum",keyword:"enum",params:{allowedValues: schema126.oneOf[9].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[22].properties.reader_failure.properties.operation.enum}};
if(vErrors === null){
vErrors = [err241];
}
else {
vErrors.push(err241);
}
errors++;
}
var valid74 = _errs377 === errors;
}
else {
var valid74 = true;
}
if(valid74){
if(data161.principal !== undefined){
const _errs379 = errors;
if(!(validate56(data161.principal, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_failure/principal",parentData:data161,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid74 = _errs379 === errors;
}
else {
var valid74 = true;
}
if(valid74){
if(data161.resource !== undefined){
const _errs380 = errors;
if(!(validate56(data161.resource, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_failure/resource",parentData:data161,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid74 = _errs380 === errors;
}
else {
var valid74 = true;
}
if(valid74){
if(data161.namespace !== undefined){
const _errs381 = errors;
if(!(validate56(data161.namespace, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_failure/namespace",parentData:data161,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid74 = _errs381 === errors;
}
else {
var valid74 = true;
}
if(valid74){
if(data161.cause !== undefined){
let data166 = data161.cause;
const _errs382 = errors;
if(typeof data166 !== "string"){
const err242 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_failure/cause",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/22/properties/reader_failure/properties/cause/type",keyword:"type",params:{type: "string"}};
if(vErrors === null){
vErrors = [err242];
}
else {
vErrors.push(err242);
}
errors++;
}
if(!(((((((((((data166 === "AccessDenied") || (data166 === "Forbidden")) || (data166 === "StateResourceExpired")) || (data166 === "UnknownStateResource")) || (data166 === "DeadlineExpired")) || (data166 === "RetiredProcess")) || (data166 === "CatalogDenied")) || (data166 === "QueryDenied")) || (data166 === "QuerySourceUnavailable")) || (data166 === "ResultUnavailable")) || (data166 === "PublicationNotPublished"))){
const err243 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_failure/cause",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/22/properties/reader_failure/properties/cause/enum",keyword:"enum",params:{allowedValues: schema126.oneOf[9].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[22].properties.reader_failure.properties.cause.enum}};
if(vErrors === null){
vErrors = [err243];
}
else {
vErrors.push(err243);
}
errors++;
}
var valid74 = _errs382 === errors;
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
}
else {
const err244 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_failure",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/22/properties/reader_failure/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err244];
}
else {
vErrors.push(err244);
}
errors++;
}
}
}
}
}
}
else {
const err245 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/22/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err245];
}
else {
vErrors.push(err245);
}
errors++;
}
}
var _valid6 = _errs371 === errors;
if(_valid6 && valid33){
valid33 = false;
passing4 = [passing4, 22];
}
else {
if(_valid6){
valid33 = true;
passing4 = 22;
if(props13 !== true){
props13 = true;
}
}
const _errs384 = errors;
if(errors === _errs384){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing68;
if((data65.reader_resource === undefined) && (missing68 = "reader_resource")){
const err246 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/required",keyword:"required",params:{missingProperty: missing68}};
if(vErrors === null){
vErrors = [err246];
}
else {
vErrors.push(err246);
}
errors++;
}
else {
const _errs386 = errors;
for(const key68 in data65){
if(!(key68 === "reader_resource")){
const err247 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key68}};
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
if(_errs386 === errors){
if(data65.reader_resource !== undefined){
let data167 = data65.reader_resource;
const _errs387 = errors;
if(errors === _errs387){
if(data167 && typeof data167 == "object" && !Array.isArray(data167)){
let missing69;
if((((((((data167.role === undefined) && (missing69 = "role")) || ((data167.resource === undefined) && (missing69 = "resource"))) || ((data167.expected_writer === undefined) && (missing69 = "expected_writer"))) || ((data167.actual_writer === undefined) && (missing69 = "actual_writer"))) || ((data167.phase === undefined) && (missing69 = "phase"))) || ((data167.writer_check === undefined) && (missing69 = "writer_check"))) || ((data167.revision === undefined) && (missing69 = "revision"))){
const err248 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/properties/reader_resource/required",keyword:"required",params:{missingProperty: missing69}};
if(vErrors === null){
vErrors = [err248];
}
else {
vErrors.push(err248);
}
errors++;
}
else {
const _errs389 = errors;
for(const key69 in data167){
if(!(((((((key69 === "role") || (key69 === "resource")) || (key69 === "expected_writer")) || (key69 === "actual_writer")) || (key69 === "phase")) || (key69 === "writer_check")) || (key69 === "revision"))){
const err249 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/properties/reader_resource/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key69}};
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
if(_errs389 === errors){
if(data167.role !== undefined){
let data168 = data167.role;
const _errs390 = errors;
if(typeof data168 !== "string"){
const err250 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource/role",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/properties/reader_resource/properties/role/type",keyword:"type",params:{type: "string"}};
if(vErrors === null){
vErrors = [err250];
}
else {
vErrors.push(err250);
}
errors++;
}
if(!((data168 === "source") || (data168 === "requester"))){
const err251 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource/role",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/properties/reader_resource/properties/role/enum",keyword:"enum",params:{allowedValues: schema126.oneOf[9].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[23].properties.reader_resource.properties.role.enum}};
if(vErrors === null){
vErrors = [err251];
}
else {
vErrors.push(err251);
}
errors++;
}
var valid76 = _errs390 === errors;
}
else {
var valid76 = true;
}
if(valid76){
if(data167.resource !== undefined){
const _errs392 = errors;
if(!(validate56(data167.resource, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource/resource",parentData:data167,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid76 = _errs392 === errors;
}
else {
var valid76 = true;
}
if(valid76){
if(data167.expected_writer !== undefined){
const _errs393 = errors;
if(!(validate56(data167.expected_writer, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource/expected_writer",parentData:data167,parentDataProperty:"expected_writer",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid76 = _errs393 === errors;
}
else {
var valid76 = true;
}
if(valid76){
if(data167.actual_writer !== undefined){
const _errs394 = errors;
if(!(validate56(data167.actual_writer, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource/actual_writer",parentData:data167,parentDataProperty:"actual_writer",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid76 = _errs394 === errors;
}
else {
var valid76 = true;
}
if(valid76){
if(data167.phase !== undefined){
let data172 = data167.phase;
const _errs395 = errors;
if(typeof data172 !== "string"){
const err252 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource/phase",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/properties/reader_resource/properties/phase/type",keyword:"type",params:{type: "string"}};
if(vErrors === null){
vErrors = [err252];
}
else {
vErrors.push(err252);
}
errors++;
}
if(!(((data172 === "active") || (data172 === "retired")) || (data172 === "reclaimed"))){
const err253 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource/phase",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/properties/reader_resource/properties/phase/enum",keyword:"enum",params:{allowedValues: schema126.oneOf[9].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[23].properties.reader_resource.properties.phase.enum}};
if(vErrors === null){
vErrors = [err253];
}
else {
vErrors.push(err253);
}
errors++;
}
var valid76 = _errs395 === errors;
}
else {
var valid76 = true;
}
if(valid76){
if(data167.writer_check !== undefined){
const _errs397 = errors;
if(typeof data167.writer_check !== "boolean"){
const err254 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource/writer_check",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/properties/reader_resource/properties/writer_check/type",keyword:"type",params:{type: "boolean"}};
if(vErrors === null){
vErrors = [err254];
}
else {
vErrors.push(err254);
}
errors++;
}
var valid76 = _errs397 === errors;
}
else {
var valid76 = true;
}
if(valid76){
if(data167.revision !== undefined){
const _errs399 = errors;
if(!(validate56(data167.revision, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource/revision",parentData:data167,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid76 = _errs399 === errors;
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
}
}
}
else {
const err255 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_resource",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/properties/reader_resource/type",keyword:"type",params:{type: "object"}};
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
}
}
else {
const err256 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/23/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err256];
}
else {
vErrors.push(err256);
}
errors++;
}
}
var _valid6 = _errs384 === errors;
if(_valid6 && valid33){
valid33 = false;
passing4 = [passing4, 23];
}
else {
if(_valid6){
valid33 = true;
passing4 = 23;
if(props13 !== true){
props13 = true;
}
}
const _errs400 = errors;
if(errors === _errs400){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing70;
if((data65.watch_shape === undefined) && (missing70 = "watch_shape")){
const err257 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/24/required",keyword:"required",params:{missingProperty: missing70}};
if(vErrors === null){
vErrors = [err257];
}
else {
vErrors.push(err257);
}
errors++;
}
else {
const _errs402 = errors;
for(const key70 in data65){
if(!(key70 === "watch_shape")){
const err258 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/24/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key70}};
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
if(_errs402 === errors){
if(data65.watch_shape !== undefined){
let data175 = data65.watch_shape;
const _errs403 = errors;
if(errors === _errs403){
if(data175 && typeof data175 == "object" && !Array.isArray(data175)){
let missing71;
if(((((data175.columns === undefined) && (missing71 = "columns")) || ((data175.first_nullable === undefined) && (missing71 = "first_nullable"))) || ((data175.primary_columns === undefined) && (missing71 = "primary_columns"))) || ((data175.primary_first === undefined) && (missing71 = "primary_first"))){
const err259 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_shape",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/24/properties/watch_shape/required",keyword:"required",params:{missingProperty: missing71}};
if(vErrors === null){
vErrors = [err259];
}
else {
vErrors.push(err259);
}
errors++;
}
else {
const _errs405 = errors;
for(const key71 in data175){
if(!((((key71 === "columns") || (key71 === "first_nullable")) || (key71 === "primary_columns")) || (key71 === "primary_first"))){
const err260 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_shape",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/24/properties/watch_shape/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key71}};
if(vErrors === null){
vErrors = [err260];
}
else {
vErrors.push(err260);
}
errors++;
break;
}
}
if(_errs405 === errors){
if(data175.columns !== undefined){
const _errs406 = errors;
if(!(validate65(data175.columns, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_shape/columns",parentData:data175,parentDataProperty:"columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
errors = vErrors.length;
}
var valid78 = _errs406 === errors;
}
else {
var valid78 = true;
}
if(valid78){
if(data175.first_nullable !== undefined){
const _errs407 = errors;
if(typeof data175.first_nullable !== "boolean"){
const err261 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_shape/first_nullable",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/24/properties/watch_shape/properties/first_nullable/type",keyword:"type",params:{type: "boolean"}};
if(vErrors === null){
vErrors = [err261];
}
else {
vErrors.push(err261);
}
errors++;
}
var valid78 = _errs407 === errors;
}
else {
var valid78 = true;
}
if(valid78){
if(data175.primary_columns !== undefined){
const _errs409 = errors;
if(!(validate65(data175.primary_columns, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_shape/primary_columns",parentData:data175,parentDataProperty:"primary_columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
errors = vErrors.length;
}
var valid78 = _errs409 === errors;
}
else {
var valid78 = true;
}
if(valid78){
if(data175.primary_first !== undefined){
const _errs410 = errors;
if(typeof data175.primary_first !== "boolean"){
const err262 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_shape/primary_first",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/24/properties/watch_shape/properties/primary_first/type",keyword:"type",params:{type: "boolean"}};
if(vErrors === null){
vErrors = [err262];
}
else {
vErrors.push(err262);
}
errors++;
}
var valid78 = _errs410 === errors;
}
else {
var valid78 = true;
}
}
}
}
}
}
}
else {
const err263 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/watch_shape",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/24/properties/watch_shape/type",keyword:"type",params:{type: "object"}};
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
const err264 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/24/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err264];
}
else {
vErrors.push(err264);
}
errors++;
}
}
var _valid6 = _errs400 === errors;
if(_valid6 && valid33){
valid33 = false;
passing4 = [passing4, 24];
}
else {
if(_valid6){
valid33 = true;
passing4 = 24;
if(props13 !== true){
props13 = true;
}
}
const _errs412 = errors;
if(errors === _errs412){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing72;
if((data65.reader_template === undefined) && (missing72 = "reader_template")){
const err265 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/25/required",keyword:"required",params:{missingProperty: missing72}};
if(vErrors === null){
vErrors = [err265];
}
else {
vErrors.push(err265);
}
errors++;
}
else {
const _errs414 = errors;
for(const key72 in data65){
if(!(key72 === "reader_template")){
const err266 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/25/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key72}};
if(vErrors === null){
vErrors = [err266];
}
else {
vErrors.push(err266);
}
errors++;
break;
}
}
if(_errs414 === errors){
if(data65.reader_template !== undefined){
let data180 = data65.reader_template;
const _errs415 = errors;
if(errors === _errs415){
if(data180 && typeof data180 == "object" && !Array.isArray(data180)){
let missing73;
if(((data180.namespace === undefined) && (missing73 = "namespace")) || ((data180.present === undefined) && (missing73 = "present"))){
const err267 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_template",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/25/properties/reader_template/required",keyword:"required",params:{missingProperty: missing73}};
if(vErrors === null){
vErrors = [err267];
}
else {
vErrors.push(err267);
}
errors++;
}
else {
const _errs417 = errors;
for(const key73 in data180){
if(!((((key73 === "namespace") || (key73 === "present")) || (key73 === "phase")) || (key73 === "manifest"))){
const err268 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_template",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/25/properties/reader_template/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key73}};
if(vErrors === null){
vErrors = [err268];
}
else {
vErrors.push(err268);
}
errors++;
break;
}
}
if(_errs417 === errors){
if(data180.namespace !== undefined){
const _errs418 = errors;
if(!(validate56(data180.namespace, {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_template/namespace",parentData:data180,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid80 = _errs418 === errors;
}
else {
var valid80 = true;
}
if(valid80){
if(data180.present !== undefined){
const _errs419 = errors;
if(typeof data180.present !== "boolean"){
const err269 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_template/present",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/25/properties/reader_template/properties/present/type",keyword:"type",params:{type: "boolean"}};
if(vErrors === null){
vErrors = [err269];
}
else {
vErrors.push(err269);
}
errors++;
}
var valid80 = _errs419 === errors;
}
else {
var valid80 = true;
}
if(valid80){
if(data180.phase !== undefined){
let data183 = data180.phase;
const _errs421 = errors;
if(typeof data183 !== "string"){
const err270 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_template/phase",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/25/properties/reader_template/properties/phase/type",keyword:"type",params:{type: "string"}};
if(vErrors === null){
vErrors = [err270];
}
else {
vErrors.push(err270);
}
errors++;
}
if(!(((((((((data183 === "uploading") || (data183 === "sealed")) || (data183 === "admitted")) || (data183 === "complete")) || (data183 === "cancelled")) || (data183 === "denied")) || (data183 === "rejected")) || (data183 === "retired")) || (data183 === "prepared"))){
const err271 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_template/phase",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/25/properties/reader_template/properties/phase/enum",keyword:"enum",params:{allowedValues: schema126.oneOf[9].properties.refresh_status.properties.view.properties.failure.oneOf[1].properties.stopped.properties.witness.oneOf[25].properties.reader_template.properties.phase.enum}};
if(vErrors === null){
vErrors = [err271];
}
else {
vErrors.push(err271);
}
errors++;
}
var valid80 = _errs421 === errors;
}
else {
var valid80 = true;
}
if(valid80){
if(data180.manifest !== undefined){
const _errs423 = errors;
if(typeof data180.manifest !== "boolean"){
const err272 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_template/manifest",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/25/properties/reader_template/properties/manifest/type",keyword:"type",params:{type: "boolean"}};
if(vErrors === null){
vErrors = [err272];
}
else {
vErrors.push(err272);
}
errors++;
}
var valid80 = _errs423 === errors;
}
else {
var valid80 = true;
}
}
}
}
}
}
}
else {
const err273 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness/reader_template",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/25/properties/reader_template/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err273];
}
else {
vErrors.push(err273);
}
errors++;
}
}
}
}
}
}
else {
const err274 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf/25/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err274];
}
else {
vErrors.push(err274);
}
errors++;
}
}
var _valid6 = _errs412 === errors;
if(_valid6 && valid33){
valid33 = false;
passing4 = [passing4, 25];
}
else {
if(_valid6){
valid33 = true;
passing4 = 25;
if(props13 !== true){
props13 = true;
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
if(!valid33){
const err275 = {instancePath:instancePath+"/refresh_status/view/failure/stopped/witness",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/properties/witness/oneOf",keyword:"oneOf",params:{passingSchemas: passing4}};
if(vErrors === null){
vErrors = [err275];
}
else {
vErrors.push(err275);
}
errors++;
}
else {
errors = _errs155;
if(vErrors !== null){
if(_errs155){
vErrors.length = _errs155;
}
else {
vErrors = null;
}
}
}
var valid32 = _errs154 === errors;
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
const err276 = {instancePath:instancePath+"/refresh_status/view/failure/stopped",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/properties/stopped/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err276];
}
else {
vErrors.push(err276);
}
errors++;
}
}
}
}
}
}
else {
const err277 = {instancePath:instancePath+"/refresh_status/view/failure",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf/1/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err277];
}
else {
vErrors.push(err277);
}
errors++;
}
}
var _valid5 = _errs145 === errors;
if(_valid5 && valid30){
valid30 = false;
passing3 = [passing3, 1];
}
else {
if(_valid5){
valid30 = true;
passing3 = 1;
if(props12 !== true){
props12 = true;
}
}
}
if(!valid30){
const err278 = {instancePath:instancePath+"/refresh_status/view/failure",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/properties/failure/oneOf",keyword:"oneOf",params:{passingSchemas: passing3}};
if(vErrors === null){
vErrors = [err278];
}
else {
vErrors.push(err278);
}
errors++;
}
else {
errors = _errs143;
if(vErrors !== null){
if(_errs143){
vErrors.length = _errs143;
}
else {
vErrors = null;
}
}
}
var valid29 = _errs142 === errors;
}
else {
var valid29 = true;
}
}
}
}
}
}
}
}
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
const err279 = {instancePath:instancePath+"/refresh_status/view",schemaPath:"#/oneOf/9/properties/refresh_status/properties/view/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err279];
}
else {
vErrors.push(err279);
}
errors++;
}
}
var valid28 = _errs125 === errors;
}
else {
var valid28 = true;
}
if(valid28){
if(data43.diagnostic !== undefined){
const _errs425 = errors;
if(!(validate477(data43.diagnostic, {instancePath:instancePath+"/refresh_status/diagnostic",parentData:data43,parentDataProperty:"diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate477.errors : vErrors.concat(validate477.errors);
errors = vErrors.length;
}
var valid28 = _errs425 === errors;
}
else {
var valid28 = true;
}
if(valid28){
if(data43.query_diagnostic !== undefined){
const _errs426 = errors;
if(!(validate477(data43.query_diagnostic, {instancePath:instancePath+"/refresh_status/query_diagnostic",parentData:data43,parentDataProperty:"query_diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate477.errors : vErrors.concat(validate477.errors);
errors = vErrors.length;
}
var valid28 = _errs426 === errors;
}
else {
var valid28 = true;
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
const err280 = {instancePath:instancePath+"/refresh_status",schemaPath:"#/oneOf/9/properties/refresh_status/type",keyword:"type",params:{type: "object"}};
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
const err281 = {instancePath,schemaPath:"#/oneOf/9/type",keyword:"type",params:{type: "object"}};
if(vErrors === null){
vErrors = [err281];
}
else {
vErrors.push(err281);
}
errors++;
}
}
var _valid0 = _errs116 === errors;
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
const err282 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0}};
if(vErrors === null){
vErrors = [err282];
}
else {
vErrors.push(err282);
}
errors++;
validate447.errors = vErrors;
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
validate447.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate447.evaluated = {"dynamicProps":true,"dynamicItems":false};
