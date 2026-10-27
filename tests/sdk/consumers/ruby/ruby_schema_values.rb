# frozen_string_literal: true
require 'transit/client'
# Independent recursive shape, including a nullable scalar and distinct roots.
validator = Transit.const_get(:Internal)
empty = { 'type' => 'object', 'properties' => {}, 'required' => [], 'additionalProperties' => false }
root = {
  '$ref' => '#/$defs/Cell',
  '$defs' => {
    'Cell' => { 'oneOf' => [
      { 'type' => 'null' },
      { 'type' => 'integer', 'minimum' => -128, 'maximum' => 127 },
      { 'type' => 'array', 'items' => { '$ref' => '#/$defs/Cell' }, 'maxItems' => 4 }
    ] }
  }
}
raise 'Recursive values rejected' unless validator.valid?(root, [1, [nil, [-128, 127]], []])
[128, -129, '1', [1, 2, 3, 4, 5], [1, [true]]].each do |value|
  raise 'Malformed recursive value accepted' if validator.valid?(root, value)
end
other = { '$ref' => '#/$defs/Cell', '$defs' => { 'Cell' => empty } }
raise 'Reference roots leaked' unless validator.valid?(other, {}) && !validator.valid?(other, 1) && !validator.valid?(root, {})
[
  { '$ref' => 'https://example.invalid/schema' },
  { '$ref' => '#/$defs/Missing', '$defs' => {} },
  { '$ref' => '#/$defs/Cell', '$defs' => { 'Cell' => empty }, 'type' => 'object' },
  { '$ref' => '#/$defs/A', '$defs' => { 'A' => { '$ref' => '#/$defs/B' }, 'B' => { '$ref' => '#/$defs/A' } } },
  { 'unsupported' => true },
].each do |schema|
  raise 'Invalid schema reference accepted' if validator.valid?(schema, {})
end
cyclic = []; cyclic << cyclic
raise 'Cyclic host value accepted' if validator.valid?(root, cyclic)
puts 'Ruby schemas: recursive local references, root isolation, exact alternatives and malformed/cyclic rejection passed.' if $PROGRAM_NAME == __FILE__
