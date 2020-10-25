# skiplist data structure implemented
# like on opendatastructures.org
# using an interface like std::multiset

import
  algorithm, bitops, math, random, sequtils


const 
  max_height = 16


proc pickHeight(): int =
  # fast geometric distribution with p=0.5
  min(max_height, countTrailingZeroBits(rand(high(int))) + 1)


type
  Node[T] = object
    next: ptr UncheckedArray[ptr Node[T]]
    value: T

  Multiset[T] = object
    sentinel: ptr Node[T]
    level, counter: int

import strformat

proc `$`[T](m: Multiset[T]): string =
  for i in 0..<m.level:
    var walk = m.sentinel.next[i]
    var j = 0
    while not walk.isNil:
      inc j
      result = result & ' ' & $walk.value
      walk = walk.next[i]
    result = result & '\n'


proc init[T](m: var Multiset[T]) =
  var node: ptr Node[T] = create(Node[T])
  let 
    next = alloc0(sizeof(ptr Node[T])*max_height)
  node.next = cast[ptr UncheckedArray[ptr Node[T]]](next)
  m.sentinel = node
  m.level = 0
  m.counter = 0


proc first[T](m: Multiset[T]): ptr Node[T] =
  m.sentinel.next[0]


proc next[T](node: var ptr Node[T]) =
  node = node.next[0]


proc insert[T](m: var Multiset[T], x: T) =
  var 
    node: ptr Node[T] = create(Node[T])
    update: ptr UncheckedArray[ptr Node[T]]
  let 
    height = pickHeight()
    next = alloc0(sizeof(ptr Node[T])*height)
    stack = alloc0(sizeof(ptr Node[T])*max(height, m.level))
  node.value = x
  node.next = cast[ptr UncheckedArray[ptr Node[T]]](next)
  update = cast[ptr UncheckedArray[ptr Node[T]]](stack)

  var walk = m.sentinel
  # find position for new node
  for i in countdown(m.level - 1, 0):
    while not walk.next[i].isNil and walk.next[i].value < x:
      walk = walk.next[i]
    update[i] = walk
  # insert
  # walk = walk.next[0]
  while m.level < height:
    update[m.level] = m.sentinel
    inc m.level
  for i in 0..<height:
    node.next[i] = update[i].next[i]
    update[i].next[i] = node

  inc m.counter
  dealloc(stack)


proc erase[T](m: var Multiset[T], node: var ptr Node[T]) =
  # erasing a specific node with duplicates allowed
  # is more complex than erasing the first with a given value
  # first find the first element with the
  # same value and save the path
  let
    stack = alloc0(sizeof(ptr Node[T])*m.level)
  var 
    walk = m.sentinel
    update = cast[ptr UncheckedArray[ptr Node[T]]](stack)
  for i in countdown(m.level - 1, 0):
    while not walk.next[i].isNil and walk.next[i].value < node.value:
      walk = walk.next[i]
    update[i] = walk
  # now keep stepping forward at level 0 until we reach our element
  while walk.next[0] != node:
    walk = walk.next[0]
    for i in 1..<m.level:
      # check that we didn't step past something changing the shortest path
      if update[i].next[i] == walk:
        update[i] = walk
  update[0] = walk
  # finally erase on all levels
  for i in countdown(m.level - 1, 0):
    if update[i].next[i] == node:
      update[i].next[i] = node.next[i]
    if update[i] == m.sentinel and node.next[i].isNil:
      dec m.level

  dealloc(stack)
  `=destroy`(node)
  dealloc(node.next)
  dealloc(node)


proc find[T](m: Multiset[T], x: T): ptr Node[T] =
  result = m.sentinel
  for i in countdown(m.level - 1, 0):
    while not result.next[i].isNil and result.next[i].value < x:
      result = result.next[i]
  result = result.next[0]
  if not result.isNil and result.value != x:
    result = nil


proc count[T](m: Multiset[T], x: T): int=
  var it = m.find(x)
  if it.isNil:
    return
  while not it.isNil and it.value == x:
    inc result
    next(it)


proc lower_bound[T](m: Multiset[T], x: T): ptr Node[T] =
  result = m.sentinel
  for i in countdown(m.level - 1, 0):
    while not result.next[i].isNil and result.next[i].value < x:
      result = result.next[i]
  if result.next[0].value == x:
    result = result.next[0]


proc upper_bound[T](m: Multiset[T], x: T): ptr Node[T] =
  result = m.sentinel
  for i in countdown(m.level - 1, 0):
    while not result.next[i].isNil and result.next[i].value <= x:
      result = result.next[i]
  result = result.next[0]
  if not result.isNil and not result.next[0].isNil and result.next[0].value == x:
    result = result.next[0]


var
  m: Multiset[int]
  v: seq[int]

m.init()

const
  N = 10000
  X = 1000

randomize()
for i in 0..<N:
  let x = rand(X)
  m.insert(x)
  v.add(x)

var
  to_erase = v[0..<(v.len div 3)].sorted()
  remainder = v[(v.len div 3)..<v.len].sorted()
  vst = v.sorted()

block:
  var 
    it = m.first()
    i = 0
  while not it.isNil:
    assert it.value == vst[i]
    next(it)
    inc i

echo "passed insert test"

block:
  for x in to_erase:
    var it = m.find(x)
    m.erase(it)

block:
  var 
    it = m.first()
    i = 0
  while not it.isNil:
    assert it.value == remainder[i]
    next(it)
    inc i

echo "passed erase test"

block:
  for i in 0..<1000:
    let x = rand(X)
    assert m.count(x) == remainder.count(x)

echo "passed count test"