// Generated; no runtime code generation or eval.
import lengthModule from "ajv/dist/runtime/ucs2length.js";
const ucs2length = lengthModule.default ?? lengthModule;
"use strict";
export const ComputationRequest = validate3344;
const schema910 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/ComputationRequest/$defs/T1"},"namespace":{"$ref":"#/$defs/ComputationRequest/$defs/T2"},"name":{"$ref":"#/$defs/ComputationRequest/$defs/T3"},"expected":{"$ref":"#/$defs/ComputationRequest/$defs/T4"},"revision":{"$ref":"#/$defs/ComputationRequest/$defs/T8"}},"required":["definition","namespace","name","expected","revision"]};
const schema21 = {"type":"string","enum":["8c9d76eb76a63bc1415e8554f64cfd67ee34402107dfe34950f43756329d49eb"]};

function validate3345(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3345.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate3345.errors = [{}];
return false;
}
if(!(data === "8c9d76eb76a63bc1415e8554f64cfd67ee34402107dfe34950f43756329d49eb")){
validate3345.errors = [{}];
return false;
}
validate3345.errors = vErrors;
return errors === 0;
}
validate3345.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema22 = {"type":"integer","minimum":0,"maximum":9007199254740991};

function validate3347(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3347.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate3347.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 9007199254740991 || isNaN(data)){
validate3347.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate3347.errors = [{}];
return false;
}
}
}
}
validate3347.errors = vErrors;
return errors === 0;
}
validate3347.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema913 = {"type":"string","maxLength":262144};
const func3 = ucs2length;

function validate3349(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3349.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func3(data) > 262144){
validate3349.errors = [{}];
return false;
}
}
else {
validate3349.errors = [{}];
return false;
}
}
validate3349.errors = vErrors;
return errors === 0;
}
validate3349.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema914 = {"anyOf":[{"$ref":"#/$defs/ComputationRequest/$defs/T5"},{"type":"null"}]};
const schema915 = {"type":"object","additionalProperties":false,"properties":{"object":{"$ref":"#/$defs/ComputationRequest/$defs/T6"},"revision":{"$ref":"#/$defs/ComputationRequest/$defs/T3"},"digest":{"$ref":"#/$defs/ComputationRequest/$defs/T3"}},"required":["object","revision","digest"]};
const schema916 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/ComputationRequest/$defs/T7"},"branch":{"$ref":"#/$defs/ComputationRequest/$defs/T3"},"object":{"$ref":"#/$defs/ComputationRequest/$defs/T3"}},"required":["scope","branch","object"]};
const schema917 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"#/$defs/ComputationRequest/$defs/T2"},"resource":{"$ref":"#/$defs/ComputationRequest/$defs/T2"},"catalog":{"$ref":"#/$defs/ComputationRequest/$defs/T3"}},"required":["realm","resource","catalog"]};

function validate3354(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3354.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.realm === undefined) && (missing0 = "realm")) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.catalog === undefined) && (missing0 = "catalog"))){
validate3354.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "realm") || (key0 === "resource")) || (key0 === "catalog"))){
validate3354.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate3347(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3347.errors : vErrors.concat(validate3347.errors);
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
if(!(validate3347(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3347.errors : vErrors.concat(validate3347.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.catalog !== undefined){
const _errs4 = errors;
if(!(validate3349(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3349.errors : vErrors.concat(validate3349.errors);
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
validate3354.errors = [{}];
return false;
}
}
validate3354.errors = vErrors;
return errors === 0;
}
validate3354.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3353(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3353.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.scope === undefined) && (missing0 = "scope")) || ((data.branch === undefined) && (missing0 = "branch"))) || ((data.object === undefined) && (missing0 = "object"))){
validate3353.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "scope") || (key0 === "branch")) || (key0 === "object"))){
validate3353.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate3354(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3354.errors : vErrors.concat(validate3354.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.branch !== undefined){
const _errs3 = errors;
if(!(validate3349(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3349.errors : vErrors.concat(validate3349.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.object !== undefined){
const _errs4 = errors;
if(!(validate3349(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3349.errors : vErrors.concat(validate3349.errors);
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
validate3353.errors = [{}];
return false;
}
}
validate3353.errors = vErrors;
return errors === 0;
}
validate3353.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3352(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3352.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.object === undefined) && (missing0 = "object")) || ((data.revision === undefined) && (missing0 = "revision"))) || ((data.digest === undefined) && (missing0 = "digest"))){
validate3352.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "object") || (key0 === "revision")) || (key0 === "digest"))){
validate3352.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.object !== undefined){
const _errs2 = errors;
if(!(validate3353(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3353.errors : vErrors.concat(validate3353.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.revision !== undefined){
const _errs3 = errors;
if(!(validate3349(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3349.errors : vErrors.concat(validate3349.errors);
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
if(!(validate3349(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3349.errors : vErrors.concat(validate3349.errors);
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
validate3352.errors = [{}];
return false;
}
}
validate3352.errors = vErrors;
return errors === 0;
}
validate3352.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3351(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3351.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate3352(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3352.errors : vErrors.concat(validate3352.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
if(_valid0){
var props0 = true;
}
const _errs2 = errors;
if(data !== null){
const err0 = {};
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
const err1 = {};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate3351.errors = vErrors;
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
validate3351.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3351.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema918 = {"anyOf":[{"$ref":"#/$defs/ComputationRequest/$defs/T3"},{"type":"null"}]};

function validate3366(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3366.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate3349(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3349.errors : vErrors.concat(validate3349.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
const _errs2 = errors;
if(data !== null){
const err0 = {};
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
const err1 = {};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate3366.errors = vErrors;
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
validate3366.errors = vErrors;
return errors === 0;
}
validate3366.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate3344(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3344.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.definition === undefined) && (missing0 = "definition")) || ((data.namespace === undefined) && (missing0 = "namespace"))) || ((data.name === undefined) && (missing0 = "name"))) || ((data.expected === undefined) && (missing0 = "expected"))) || ((data.revision === undefined) && (missing0 = "revision"))){
validate3344.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "definition") || (key0 === "namespace")) || (key0 === "name")) || (key0 === "expected")) || (key0 === "revision"))){
validate3344.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate3345(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3345.errors : vErrors.concat(validate3345.errors);
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
if(!(validate3347(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3347.errors : vErrors.concat(validate3347.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.name !== undefined){
const _errs4 = errors;
if(!(validate3349(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3349.errors : vErrors.concat(validate3349.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.expected !== undefined){
const _errs5 = errors;
if(!(validate3351(data.expected, {instancePath:instancePath+"/expected",parentData:data,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3351.errors : vErrors.concat(validate3351.errors);
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
if(!(validate3366(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3366.errors : vErrors.concat(validate3366.errors);
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
validate3344.errors = [{}];
return false;
}
}
validate3344.errors = vErrors;
return errors === 0;
}
validate3344.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const ComputationResponse = validate3369;
const schema919 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/ComputationResponse/$defs/T1"},"binding":{"$ref":"#/$defs/ComputationResponse/$defs/T2"},"source":{"$ref":"#/$defs/ComputationResponse/$defs/T2"},"output":{"$ref":"#/$defs/ComputationResponse/$defs/T2"},"sql":{"$ref":"#/$defs/ComputationResponse/$defs/T4"},"current":{"$ref":"#/$defs/ComputationResponse/$defs/T8"},"completed":{"$ref":"#/$defs/ComputationResponse/$defs/T16"}},"required":["definition","binding","source","output","sql","current","completed"]};

function validate3370(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3370.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate3370.errors = [{}];
return false;
}
if(!(data === "8c9d76eb76a63bc1415e8554f64cfd67ee34402107dfe34950f43756329d49eb")){
validate3370.errors = [{}];
return false;
}
validate3370.errors = vErrors;
return errors === 0;
}
validate3370.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema921 = {"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"#/$defs/ComputationResponse/$defs/T3"},"name":{"$ref":"#/$defs/ComputationResponse/$defs/T4"},"interpretation":{"$ref":"#/$defs/ComputationResponse/$defs/T5"}},"required":["namespace","name","interpretation"]};

function validate3373(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3373.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate3373.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 9007199254740991 || isNaN(data)){
validate3373.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate3373.errors = [{}];
return false;
}
}
}
}
validate3373.errors = vErrors;
return errors === 0;
}
validate3373.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema923 = {"type":"string","maxLength":262144};

function validate3375(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3375.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func3(data) > 262144){
validate3375.errors = [{}];
return false;
}
}
else {
validate3375.errors = [{}];
return false;
}
}
validate3375.errors = vErrors;
return errors === 0;
}
validate3375.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema924 = {"type":"object","additionalProperties":false,"properties":{"object":{"$ref":"#/$defs/ComputationResponse/$defs/T6"},"revision":{"$ref":"#/$defs/ComputationResponse/$defs/T4"},"digest":{"$ref":"#/$defs/ComputationResponse/$defs/T4"}},"required":["object","revision","digest"]};
const schema925 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/ComputationResponse/$defs/T7"},"branch":{"$ref":"#/$defs/ComputationResponse/$defs/T4"},"object":{"$ref":"#/$defs/ComputationResponse/$defs/T4"}},"required":["scope","branch","object"]};
const schema926 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"#/$defs/ComputationResponse/$defs/T3"},"resource":{"$ref":"#/$defs/ComputationResponse/$defs/T3"},"catalog":{"$ref":"#/$defs/ComputationResponse/$defs/T4"}},"required":["realm","resource","catalog"]};

function validate3379(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3379.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.realm === undefined) && (missing0 = "realm")) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.catalog === undefined) && (missing0 = "catalog"))){
validate3379.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "realm") || (key0 === "resource")) || (key0 === "catalog"))){
validate3379.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate3373(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3373.errors : vErrors.concat(validate3373.errors);
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
if(!(validate3373(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3373.errors : vErrors.concat(validate3373.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.catalog !== undefined){
const _errs4 = errors;
if(!(validate3375(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3375.errors : vErrors.concat(validate3375.errors);
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
validate3379.errors = [{}];
return false;
}
}
validate3379.errors = vErrors;
return errors === 0;
}
validate3379.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3378(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3378.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.scope === undefined) && (missing0 = "scope")) || ((data.branch === undefined) && (missing0 = "branch"))) || ((data.object === undefined) && (missing0 = "object"))){
validate3378.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "scope") || (key0 === "branch")) || (key0 === "object"))){
validate3378.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate3379(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3379.errors : vErrors.concat(validate3379.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.branch !== undefined){
const _errs3 = errors;
if(!(validate3375(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3375.errors : vErrors.concat(validate3375.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.object !== undefined){
const _errs4 = errors;
if(!(validate3375(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3375.errors : vErrors.concat(validate3375.errors);
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
validate3378.errors = [{}];
return false;
}
}
validate3378.errors = vErrors;
return errors === 0;
}
validate3378.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3377(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3377.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.object === undefined) && (missing0 = "object")) || ((data.revision === undefined) && (missing0 = "revision"))) || ((data.digest === undefined) && (missing0 = "digest"))){
validate3377.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "object") || (key0 === "revision")) || (key0 === "digest"))){
validate3377.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.object !== undefined){
const _errs2 = errors;
if(!(validate3378(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3378.errors : vErrors.concat(validate3378.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.revision !== undefined){
const _errs3 = errors;
if(!(validate3375(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3375.errors : vErrors.concat(validate3375.errors);
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
if(!(validate3375(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3375.errors : vErrors.concat(validate3375.errors);
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
validate3377.errors = [{}];
return false;
}
}
validate3377.errors = vErrors;
return errors === 0;
}
validate3377.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3372(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3372.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.namespace === undefined) && (missing0 = "namespace")) || ((data.name === undefined) && (missing0 = "name"))) || ((data.interpretation === undefined) && (missing0 = "interpretation"))){
validate3372.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "namespace") || (key0 === "name")) || (key0 === "interpretation"))){
validate3372.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.namespace !== undefined){
const _errs2 = errors;
if(!(validate3373(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3373.errors : vErrors.concat(validate3373.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.name !== undefined){
const _errs3 = errors;
if(!(validate3375(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3375.errors : vErrors.concat(validate3375.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.interpretation !== undefined){
const _errs4 = errors;
if(!(validate3377(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3377.errors : vErrors.concat(validate3377.errors);
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
validate3372.errors = [{}];
return false;
}
}
validate3372.errors = vErrors;
return errors === 0;
}
validate3372.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema927 = {"anyOf":[{"$ref":"#/$defs/ComputationResponse/$defs/T9"},{"type":"null"}]};
const schema928 = {"type":"object","additionalProperties":false,"properties":{"state":{"$ref":"#/$defs/ComputationResponse/$defs/T10"},"epoch":{"$ref":"#/$defs/ComputationResponse/$defs/T4"},"refresh":{"$ref":"#/$defs/ComputationResponse/$defs/T4"},"attempt":{"$ref":"#/$defs/ComputationResponse/$defs/T4"},"pending":{"$ref":"#/$defs/ComputationResponse/$defs/T11"},"blocked":{"$ref":"#/$defs/ComputationResponse/$defs/T13"},"retirement_complete":{"$ref":"#/$defs/ComputationResponse/$defs/T14"},"storage":{"$ref":"#/$defs/ComputationResponse/$defs/T5"},"position":{"$ref":"#/$defs/ComputationResponse/$defs/T15"}},"required":["state","epoch","refresh","attempt","pending","blocked","retirement_complete","storage","position"]};
const func1 = Object.prototype.hasOwnProperty;
const schema929 = {"type":"string","enum":["published","authorized","active","suspended","retired"]};

function validate3396(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3396.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate3396.errors = [{}];
return false;
}
if(!(((((data === "published") || (data === "authorized")) || (data === "active")) || (data === "suspended")) || (data === "retired"))){
validate3396.errors = [{}];
return false;
}
validate3396.errors = vErrors;
return errors === 0;
}
validate3396.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema930 = {"anyOf":[{"$ref":"#/$defs/ComputationResponse/$defs/T12"},{"type":"null"}]};
const schema931 = {"type":"object","additionalProperties":false,"properties":{"account":{"$ref":"#/$defs/ComputationResponse/$defs/T4"},"token":{"$ref":"#/$defs/ComputationResponse/$defs/T4"}},"required":["account","token"]};

function validate3402(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3402.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.account === undefined) && (missing0 = "account")) || ((data.token === undefined) && (missing0 = "token"))){
validate3402.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "account") || (key0 === "token"))){
validate3402.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.account !== undefined){
const _errs2 = errors;
if(!(validate3375(data.account, {instancePath:instancePath+"/account",parentData:data,parentDataProperty:"account",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3375.errors : vErrors.concat(validate3375.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.token !== undefined){
const _errs3 = errors;
if(!(validate3375(data.token, {instancePath:instancePath+"/token",parentData:data,parentDataProperty:"token",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3375.errors : vErrors.concat(validate3375.errors);
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
validate3402.errors = [{}];
return false;
}
}
validate3402.errors = vErrors;
return errors === 0;
}
validate3402.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3401(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3401.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate3402(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3402.errors : vErrors.concat(validate3402.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
if(_valid0){
var props0 = true;
}
const _errs2 = errors;
if(data !== null){
const err0 = {};
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
const err1 = {};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate3401.errors = vErrors;
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
validate3401.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3401.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema932 = {"type":"string","enum":["none","authorization","source_changed","history_expired","storage_unavailable","budget","execution_failed","lease_fenced","unresolved_transaction"]};

function validate3407(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3407.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate3407.errors = [{}];
return false;
}
if(!(((((((((data === "none") || (data === "authorization")) || (data === "source_changed")) || (data === "history_expired")) || (data === "storage_unavailable")) || (data === "budget")) || (data === "execution_failed")) || (data === "lease_fenced")) || (data === "unresolved_transaction"))){
validate3407.errors = [{}];
return false;
}
validate3407.errors = vErrors;
return errors === 0;
}
validate3407.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema933 = {"type":"boolean"};

function validate3409(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3409.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate3409.errors = [{}];
return false;
}
validate3409.errors = vErrors;
return errors === 0;
}
validate3409.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema934 = {"type":"object","additionalProperties":false,"properties":{"partition":{"$ref":"#/$defs/ComputationResponse/$defs/T4"},"next_lsn":{"$ref":"#/$defs/ComputationResponse/$defs/T4"}},"required":["partition","next_lsn"]};

function validate3412(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3412.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.partition === undefined) && (missing0 = "partition")) || ((data.next_lsn === undefined) && (missing0 = "next_lsn"))){
validate3412.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "partition") || (key0 === "next_lsn"))){
validate3412.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.partition !== undefined){
const _errs2 = errors;
if(!(validate3375(data.partition, {instancePath:instancePath+"/partition",parentData:data,parentDataProperty:"partition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3375.errors : vErrors.concat(validate3375.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.next_lsn !== undefined){
const _errs3 = errors;
if(!(validate3375(data.next_lsn, {instancePath:instancePath+"/next_lsn",parentData:data,parentDataProperty:"next_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3375.errors : vErrors.concat(validate3375.errors);
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
validate3412.errors = [{}];
return false;
}
}
validate3412.errors = vErrors;
return errors === 0;
}
validate3412.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3395(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3395.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((((data.state === undefined) && (missing0 = "state")) || ((data.epoch === undefined) && (missing0 = "epoch"))) || ((data.refresh === undefined) && (missing0 = "refresh"))) || ((data.attempt === undefined) && (missing0 = "attempt"))) || ((data.pending === undefined) && (missing0 = "pending"))) || ((data.blocked === undefined) && (missing0 = "blocked"))) || ((data.retirement_complete === undefined) && (missing0 = "retirement_complete"))) || ((data.storage === undefined) && (missing0 = "storage"))) || ((data.position === undefined) && (missing0 = "position"))){
validate3395.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema928.properties, key0))){
validate3395.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.state !== undefined){
const _errs2 = errors;
if(!(validate3396(data.state, {instancePath:instancePath+"/state",parentData:data,parentDataProperty:"state",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3396.errors : vErrors.concat(validate3396.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.epoch !== undefined){
const _errs3 = errors;
if(!(validate3375(data.epoch, {instancePath:instancePath+"/epoch",parentData:data,parentDataProperty:"epoch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3375.errors : vErrors.concat(validate3375.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.refresh !== undefined){
const _errs4 = errors;
if(!(validate3375(data.refresh, {instancePath:instancePath+"/refresh",parentData:data,parentDataProperty:"refresh",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3375.errors : vErrors.concat(validate3375.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.attempt !== undefined){
const _errs5 = errors;
if(!(validate3375(data.attempt, {instancePath:instancePath+"/attempt",parentData:data,parentDataProperty:"attempt",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3375.errors : vErrors.concat(validate3375.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.pending !== undefined){
const _errs6 = errors;
if(!(validate3401(data.pending, {instancePath:instancePath+"/pending",parentData:data,parentDataProperty:"pending",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3401.errors : vErrors.concat(validate3401.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.blocked !== undefined){
const _errs7 = errors;
if(!(validate3407(data.blocked, {instancePath:instancePath+"/blocked",parentData:data,parentDataProperty:"blocked",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3407.errors : vErrors.concat(validate3407.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.retirement_complete !== undefined){
const _errs8 = errors;
if(!(validate3409(data.retirement_complete, {instancePath:instancePath+"/retirement_complete",parentData:data,parentDataProperty:"retirement_complete",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3409.errors : vErrors.concat(validate3409.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.storage !== undefined){
const _errs9 = errors;
if(!(validate3377(data.storage, {instancePath:instancePath+"/storage",parentData:data,parentDataProperty:"storage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3377.errors : vErrors.concat(validate3377.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.position !== undefined){
const _errs10 = errors;
if(!(validate3412(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3412.errors : vErrors.concat(validate3412.errors);
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
}
else {
validate3395.errors = [{}];
return false;
}
}
validate3395.errors = vErrors;
return errors === 0;
}
validate3395.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3394(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3394.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate3395(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3395.errors : vErrors.concat(validate3395.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
if(_valid0){
var props0 = true;
}
const _errs2 = errors;
if(data !== null){
const err0 = {};
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
const err1 = {};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate3394.errors = vErrors;
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
validate3394.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3394.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema935 = {"anyOf":[{"$ref":"#/$defs/ComputationResponse/$defs/T17"},{"type":"null"}]};
const schema936 = {"type":"object","additionalProperties":false,"properties":{"revision":{"$ref":"#/$defs/ComputationResponse/$defs/T4"},"rows":{"$ref":"#/$defs/ComputationResponse/$defs/T4"},"source":{"$ref":"#/$defs/ComputationResponse/$defs/T5"},"output":{"$ref":"#/$defs/ComputationResponse/$defs/T5"},"source_position":{"$ref":"#/$defs/ComputationResponse/$defs/T15"},"schema":{"$ref":"#/$defs/ComputationResponse/$defs/T18"},"manifest":{"$ref":"#/$defs/ComputationResponse/$defs/T18"},"decision":{"$ref":"#/$defs/ComputationResponse/$defs/T19"}},"required":["revision","rows","source","output","source_position","schema","manifest","decision"]};
const schema937 = {"type":"object","additionalProperties":false,"properties":{"bytes":{"$ref":"#/$defs/ComputationResponse/$defs/T4"},"sha256":{"$ref":"#/$defs/ComputationResponse/$defs/T4"}},"required":["bytes","sha256"]};

function validate3425(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3425.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.bytes === undefined) && (missing0 = "bytes")) || ((data.sha256 === undefined) && (missing0 = "sha256"))){
validate3425.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "bytes") || (key0 === "sha256"))){
validate3425.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.bytes !== undefined){
const _errs2 = errors;
if(!(validate3375(data.bytes, {instancePath:instancePath+"/bytes",parentData:data,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3375.errors : vErrors.concat(validate3375.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.sha256 !== undefined){
const _errs3 = errors;
if(!(validate3375(data.sha256, {instancePath:instancePath+"/sha256",parentData:data,parentDataProperty:"sha256",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3375.errors : vErrors.concat(validate3375.errors);
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
validate3425.errors = [{}];
return false;
}
}
validate3425.errors = vErrors;
return errors === 0;
}
validate3425.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema938 = {"type":"object","additionalProperties":false,"properties":{"attempt":{"$ref":"#/$defs/ComputationResponse/$defs/T20"},"outcome":{"$ref":"#/$defs/ComputationResponse/$defs/T24"},"prepared":{"$ref":"#/$defs/ComputationResponse/$defs/T23"},"position":{"$ref":"#/$defs/ComputationResponse/$defs/T15"},"coordinator_epoch":{"$ref":"#/$defs/ComputationResponse/$defs/T4"},"policy_epoch":{"$ref":"#/$defs/ComputationResponse/$defs/T4"}},"required":["attempt","outcome","prepared","position","coordinator_epoch","policy_epoch"]};
const schema939 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/ComputationResponse/$defs/T1"},"transaction":{"$ref":"#/$defs/ComputationResponse/$defs/T21"},"operation":{"$ref":"#/$defs/ComputationResponse/$defs/T22"},"cut":{"$ref":"#/$defs/ComputationResponse/$defs/T18"},"workspace":{"$ref":"#/$defs/ComputationResponse/$defs/T18"},"participants":{"$ref":"#/$defs/ComputationResponse/$defs/T23"},"writes":{"$ref":"#/$defs/ComputationResponse/$defs/T4"},"last_statement":{"$ref":"#/$defs/ComputationResponse/$defs/T4"}},"required":["definition","transaction","operation","cut","workspace","participants","writes","last_statement"]};
const schema940 = {"type":"object","additionalProperties":false,"properties":{"begin":{"$ref":"#/$defs/ComputationResponse/$defs/T22"},"branch":{"$ref":"#/$defs/ComputationResponse/$defs/T4"}},"required":["begin","branch"]};
const schema941 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/ComputationResponse/$defs/T7"},"principal":{"$ref":"#/$defs/ComputationResponse/$defs/T3"},"operation":{"$ref":"#/$defs/ComputationResponse/$defs/T4"}},"required":["scope","principal","operation"]};

function validate3434(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3434.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.scope === undefined) && (missing0 = "scope")) || ((data.principal === undefined) && (missing0 = "principal"))) || ((data.operation === undefined) && (missing0 = "operation"))){
validate3434.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "scope") || (key0 === "principal")) || (key0 === "operation"))){
validate3434.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate3379(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3379.errors : vErrors.concat(validate3379.errors);
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
if(!(validate3373(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3373.errors : vErrors.concat(validate3373.errors);
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
if(!(validate3375(data.operation, {instancePath:instancePath+"/operation",parentData:data,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3375.errors : vErrors.concat(validate3375.errors);
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
validate3434.errors = [{}];
return false;
}
}
validate3434.errors = vErrors;
return errors === 0;
}
validate3434.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3433(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3433.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.begin === undefined) && (missing0 = "begin")) || ((data.branch === undefined) && (missing0 = "branch"))){
validate3433.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "begin") || (key0 === "branch"))){
validate3433.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.begin !== undefined){
const _errs2 = errors;
if(!(validate3434(data.begin, {instancePath:instancePath+"/begin",parentData:data,parentDataProperty:"begin",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3434.errors : vErrors.concat(validate3434.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.branch !== undefined){
const _errs3 = errors;
if(!(validate3375(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3375.errors : vErrors.concat(validate3375.errors);
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
validate3433.errors = [{}];
return false;
}
}
validate3433.errors = vErrors;
return errors === 0;
}
validate3433.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema942 = {"type":"object","additionalProperties":false,"properties":{"content":{"$ref":"#/$defs/ComputationResponse/$defs/T18"},"count":{"$ref":"#/$defs/ComputationResponse/$defs/T4"}},"required":["content","count"]};

function validate3444(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3444.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.content === undefined) && (missing0 = "content")) || ((data.count === undefined) && (missing0 = "count"))){
validate3444.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "content") || (key0 === "count"))){
validate3444.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.content !== undefined){
const _errs2 = errors;
if(!(validate3425(data.content, {instancePath:instancePath+"/content",parentData:data,parentDataProperty:"content",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3425.errors : vErrors.concat(validate3425.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.count !== undefined){
const _errs3 = errors;
if(!(validate3375(data.count, {instancePath:instancePath+"/count",parentData:data,parentDataProperty:"count",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3375.errors : vErrors.concat(validate3375.errors);
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
validate3444.errors = [{}];
return false;
}
}
validate3444.errors = vErrors;
return errors === 0;
}
validate3444.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3431(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3431.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((((data.definition === undefined) && (missing0 = "definition")) || ((data.transaction === undefined) && (missing0 = "transaction"))) || ((data.operation === undefined) && (missing0 = "operation"))) || ((data.cut === undefined) && (missing0 = "cut"))) || ((data.workspace === undefined) && (missing0 = "workspace"))) || ((data.participants === undefined) && (missing0 = "participants"))) || ((data.writes === undefined) && (missing0 = "writes"))) || ((data.last_statement === undefined) && (missing0 = "last_statement"))){
validate3431.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "definition") || (key0 === "transaction")) || (key0 === "operation")) || (key0 === "cut")) || (key0 === "workspace")) || (key0 === "participants")) || (key0 === "writes")) || (key0 === "last_statement"))){
validate3431.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate3370(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3370.errors : vErrors.concat(validate3370.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.transaction !== undefined){
const _errs3 = errors;
if(!(validate3433(data.transaction, {instancePath:instancePath+"/transaction",parentData:data,parentDataProperty:"transaction",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3433.errors : vErrors.concat(validate3433.errors);
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
if(!(validate3434(data.operation, {instancePath:instancePath+"/operation",parentData:data,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3434.errors : vErrors.concat(validate3434.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.cut !== undefined){
const _errs5 = errors;
if(!(validate3425(data.cut, {instancePath:instancePath+"/cut",parentData:data,parentDataProperty:"cut",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3425.errors : vErrors.concat(validate3425.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.workspace !== undefined){
const _errs6 = errors;
if(!(validate3425(data.workspace, {instancePath:instancePath+"/workspace",parentData:data,parentDataProperty:"workspace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3425.errors : vErrors.concat(validate3425.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.participants !== undefined){
const _errs7 = errors;
if(!(validate3444(data.participants, {instancePath:instancePath+"/participants",parentData:data,parentDataProperty:"participants",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3444.errors : vErrors.concat(validate3444.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.writes !== undefined){
const _errs8 = errors;
if(!(validate3375(data.writes, {instancePath:instancePath+"/writes",parentData:data,parentDataProperty:"writes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3375.errors : vErrors.concat(validate3375.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.last_statement !== undefined){
const _errs9 = errors;
if(!(validate3375(data.last_statement, {instancePath:instancePath+"/last_statement",parentData:data,parentDataProperty:"last_statement",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3375.errors : vErrors.concat(validate3375.errors);
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
validate3431.errors = [{}];
return false;
}
}
validate3431.errors = vErrors;
return errors === 0;
}
validate3431.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema943 = {"type":"string","enum":["committed","aborted"]};

function validate3451(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3451.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate3451.errors = [{}];
return false;
}
if(!((data === "committed") || (data === "aborted"))){
validate3451.errors = [{}];
return false;
}
validate3451.errors = vErrors;
return errors === 0;
}
validate3451.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate3430(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3430.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((data.attempt === undefined) && (missing0 = "attempt")) || ((data.outcome === undefined) && (missing0 = "outcome"))) || ((data.prepared === undefined) && (missing0 = "prepared"))) || ((data.position === undefined) && (missing0 = "position"))) || ((data.coordinator_epoch === undefined) && (missing0 = "coordinator_epoch"))) || ((data.policy_epoch === undefined) && (missing0 = "policy_epoch"))){
validate3430.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "attempt") || (key0 === "outcome")) || (key0 === "prepared")) || (key0 === "position")) || (key0 === "coordinator_epoch")) || (key0 === "policy_epoch"))){
validate3430.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.attempt !== undefined){
const _errs2 = errors;
if(!(validate3431(data.attempt, {instancePath:instancePath+"/attempt",parentData:data,parentDataProperty:"attempt",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3431.errors : vErrors.concat(validate3431.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.outcome !== undefined){
const _errs3 = errors;
if(!(validate3451(data.outcome, {instancePath:instancePath+"/outcome",parentData:data,parentDataProperty:"outcome",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3451.errors : vErrors.concat(validate3451.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.prepared !== undefined){
const _errs4 = errors;
if(!(validate3444(data.prepared, {instancePath:instancePath+"/prepared",parentData:data,parentDataProperty:"prepared",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3444.errors : vErrors.concat(validate3444.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.position !== undefined){
const _errs5 = errors;
if(!(validate3412(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3412.errors : vErrors.concat(validate3412.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.coordinator_epoch !== undefined){
const _errs6 = errors;
if(!(validate3375(data.coordinator_epoch, {instancePath:instancePath+"/coordinator_epoch",parentData:data,parentDataProperty:"coordinator_epoch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3375.errors : vErrors.concat(validate3375.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.policy_epoch !== undefined){
const _errs7 = errors;
if(!(validate3375(data.policy_epoch, {instancePath:instancePath+"/policy_epoch",parentData:data,parentDataProperty:"policy_epoch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3375.errors : vErrors.concat(validate3375.errors);
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
validate3430.errors = [{}];
return false;
}
}
validate3430.errors = vErrors;
return errors === 0;
}
validate3430.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3419(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3419.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((((data.revision === undefined) && (missing0 = "revision")) || ((data.rows === undefined) && (missing0 = "rows"))) || ((data.source === undefined) && (missing0 = "source"))) || ((data.output === undefined) && (missing0 = "output"))) || ((data.source_position === undefined) && (missing0 = "source_position"))) || ((data.schema === undefined) && (missing0 = "schema"))) || ((data.manifest === undefined) && (missing0 = "manifest"))) || ((data.decision === undefined) && (missing0 = "decision"))){
validate3419.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "revision") || (key0 === "rows")) || (key0 === "source")) || (key0 === "output")) || (key0 === "source_position")) || (key0 === "schema")) || (key0 === "manifest")) || (key0 === "decision"))){
validate3419.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.revision !== undefined){
const _errs2 = errors;
if(!(validate3375(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3375.errors : vErrors.concat(validate3375.errors);
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
if(!(validate3375(data.rows, {instancePath:instancePath+"/rows",parentData:data,parentDataProperty:"rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3375.errors : vErrors.concat(validate3375.errors);
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
if(!(validate3377(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3377.errors : vErrors.concat(validate3377.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.output !== undefined){
const _errs5 = errors;
if(!(validate3377(data.output, {instancePath:instancePath+"/output",parentData:data,parentDataProperty:"output",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3377.errors : vErrors.concat(validate3377.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.source_position !== undefined){
const _errs6 = errors;
if(!(validate3412(data.source_position, {instancePath:instancePath+"/source_position",parentData:data,parentDataProperty:"source_position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3412.errors : vErrors.concat(validate3412.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.schema !== undefined){
const _errs7 = errors;
if(!(validate3425(data.schema, {instancePath:instancePath+"/schema",parentData:data,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3425.errors : vErrors.concat(validate3425.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.manifest !== undefined){
const _errs8 = errors;
if(!(validate3425(data.manifest, {instancePath:instancePath+"/manifest",parentData:data,parentDataProperty:"manifest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3425.errors : vErrors.concat(validate3425.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.decision !== undefined){
const _errs9 = errors;
if(!(validate3430(data.decision, {instancePath:instancePath+"/decision",parentData:data,parentDataProperty:"decision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3430.errors : vErrors.concat(validate3430.errors);
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
validate3419.errors = [{}];
return false;
}
}
validate3419.errors = vErrors;
return errors === 0;
}
validate3419.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3418(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3418.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate3419(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3419.errors : vErrors.concat(validate3419.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
if(_valid0){
var props0 = true;
}
const _errs2 = errors;
if(data !== null){
const err0 = {};
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
const err1 = {};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate3418.errors = vErrors;
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
validate3418.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3418.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate3369(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3369.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((data.definition === undefined) && (missing0 = "definition")) || ((data.binding === undefined) && (missing0 = "binding"))) || ((data.source === undefined) && (missing0 = "source"))) || ((data.output === undefined) && (missing0 = "output"))) || ((data.sql === undefined) && (missing0 = "sql"))) || ((data.current === undefined) && (missing0 = "current"))) || ((data.completed === undefined) && (missing0 = "completed"))){
validate3369.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "definition") || (key0 === "binding")) || (key0 === "source")) || (key0 === "output")) || (key0 === "sql")) || (key0 === "current")) || (key0 === "completed"))){
validate3369.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate3370(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3370.errors : vErrors.concat(validate3370.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.binding !== undefined){
const _errs3 = errors;
if(!(validate3372(data.binding, {instancePath:instancePath+"/binding",parentData:data,parentDataProperty:"binding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3372.errors : vErrors.concat(validate3372.errors);
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
if(!(validate3372(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3372.errors : vErrors.concat(validate3372.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.output !== undefined){
const _errs5 = errors;
if(!(validate3372(data.output, {instancePath:instancePath+"/output",parentData:data,parentDataProperty:"output",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3372.errors : vErrors.concat(validate3372.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.sql !== undefined){
const _errs6 = errors;
if(!(validate3375(data.sql, {instancePath:instancePath+"/sql",parentData:data,parentDataProperty:"sql",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3375.errors : vErrors.concat(validate3375.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.current !== undefined){
const _errs7 = errors;
if(!(validate3394(data.current, {instancePath:instancePath+"/current",parentData:data,parentDataProperty:"current",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3394.errors : vErrors.concat(validate3394.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.completed !== undefined){
const _errs8 = errors;
if(!(validate3418(data.completed, {instancePath:instancePath+"/completed",parentData:data,parentDataProperty:"completed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3418.errors : vErrors.concat(validate3418.errors);
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
validate3369.errors = [{}];
return false;
}
}
validate3369.errors = vErrors;
return errors === 0;
}
validate3369.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};
