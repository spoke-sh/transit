# Enhance ProllyTreeBuilder with Point Updates - SDD

## Overview

This voyage adds point-mutation capabilities to the Prolly Tree implementation.

## Architecture

Prolly Trees are immutable and content-addressed. "Updates" produce a new root digest by recursively updating only the path from the modified leaf to the root.

## Components

- `ProllyTreeBuilder`: Extended with `insert` and `delete` methods.
- Recursive Update Logic: Logic to find the target leaf, modify it, and re-hash/re-chunk affected parent nodes.

## Data Flow

1. User calls `insert(root, key, value)`.
2. Builder traverses from `root` to the target `LeafNode`.
3. Builder modifies the leaf and computes its new digest.
4. Builder recursively propagates the change up the tree, creating new internal nodes as needed.
5. Builder returns the new `root_digest`.
