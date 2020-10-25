import
  bitops, math, random


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
    echo i
    while not walk.isNil:
      # echo fmt"{cast[int](walk):#x}"
      # echo j, "\t", walk.value
      # echo walk.addr.repr
      # echo walk.next.repr
      # echo fmt"{cast[int](walk.next[i]):#x}"
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
    stack = alloc0(sizeof(ptr Node[T])*height)
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





var
  m: Multiset[int]
  v: seq[int]

m.init()

const
  N = 500
  X = 9

randomize()
for i in 0..<N:
  let x = rand(X)
  m.insert(x)
  v.add(x)


var 
  f = m.first()
  j = 0
echo f.type
while not f.isNil:
  echo j, ' ', f.value
  next(f)
  inc j


echo "level ", m.level
# echo m