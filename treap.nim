# treap implemented as in opendatastructures.org
# interface parallels std::multiset

import random, algorithm, sequtils


type
  Node[T] = object
    left, right, parent: ptr Node[T]
    priority: int
    value: T

  Multiset[T] = object
    root: ptr Node[T]
    counter: int


proc `$`[T](node: ptr Node[T]): string =
  if node.isNil:
    return
  # echo node.left.addr, ' ', node.value, ' ', node.right.addr
  result = '(' & $node.left & ' ' & $node.value & ':' & $node.priority & ' ' & $node.right & ')'


proc `$`[T](m: Multiset[T]): string =
  result = "size: " & $m.size & " tree: " & $m.root


proc size[T](m: Multiset[T]): int =
  m.counter


proc len[T](m: Multiset[T]): int =
  m.counter


proc first[T](m: Multiset[T]): ptr Node[T] =
  if m.root.isNil:
    return nil

  result = m.root
  while not result.left.isNil:
    result = result.left


proc last[T](m: Multiset[T]): ptr Node[T] =
  if m.root.isNil:
    return nil

  result = m.root
  while not result.right.isNil:
    result = result.right


proc next[T](node: var ptr Node[T]) =
  if node.right.isNil:
    while not node.parent.isNil and node == node.parent.right:
      node = node.parent
    node = node.parent
  else:
    node = node.right
    while not node.left.isNil:
      node = node.left


proc prev[T](node: var ptr Node[T]) =
  if node.left.isNil:
    while not node.parent.isNil and node == node.parent.left:
      node = node.parent
    node = node.parent
  else:
    node = node.left
    while not node.right.isNil:
      node = node.right


proc rotateLeft[T](m: var Multiset[T], u: ptr Node[T]) =
  let w = u.right
  w.parent = u.parent
  if not w.parent.isNil:
    if w.parent.left == u:
      w.parent.left = w
    else:
      w.parent.right = w
  u.right = w.left
  if not u.right.isNil:
    u.right.parent = u
  u.parent = w
  w.left = u
  if u == m.root:
    m.root = w
    w.parent = nil


proc rotateRight[T](m: var Multiset[T], u: ptr Node[T]) =
  let w = u.left
  w.parent = u.parent
  if not w.parent.isNil:
    if w.parent.left == u:
      w.parent.left = w
    else:
      w.parent.right = w
  u.left = w.right
  if not u.left.isNil:
    u.left.parent = u
  u.parent = w
  w.right = u
  if u == m.root:
    m.root = w
    w.parent = nil


proc insert[T](m: var Multiset[T], x: T) =
  let node: ptr Node[T] = create(Node[T])
  node.value = x
  node.priority = rand(int.high)

  if m.root.isNil:
    m.root = node
    return

  # insert new node
  var 
    walk = m.root
  while true:
    if cmp(node.value, walk.value) < 0:
      if walk.left.isNil:
        walk.left = node
        node.parent = walk
        break
      else: walk = walk.left
    else:
      if walk.right.isNil:
        walk.right = node
        node.parent = walk
        break
      else: walk = walk.right

  # preserve heap property through rotations
  while not node.parent.isNil and node.parent.priority > node.priority:
    if node.parent.right == node:
      m.rotateLeft(node.parent)
    else:
      m.rotateRight(node.parent)
  if node.parent.isNil:
    m.root = node

  inc m.counter


proc erase[T](m: var Multiset[T], node: var ptr Node[T]) =
  # move node so that it becomes a leaf
  while not (node.left.isNil and node.right.isNil):
    if node.left.isNil:
      m.rotateLeft(node)
    elif node.right.isNil:
      m.rotateRight(node)
    elif node.left.priority < node.right.priority:
      m.rotateRight(node)
    else:
      m.rotateLeft(node)
    if m.root == node:
      m.root = node.parent
  
  # remove (leaf) node
  if node.parent.left == node:
    node.parent.left = nil
  else:
    node.parent.right = nil
  
  dec m.counter
  `=destroy`(node)
  dealloc(node)


proc find[T](m: Multiset[T], x: T): ptr Node[T] =
  if m.root.isNil:
    return nil

  var walk = m.root
  while true:
    let rel = cmp(x, walk.value)
    if rel < 0:
      if walk.left.isNil:
        break
      else:
        walk = walk.left
    elif rel > 0:
      if walk.right.isNil:
        break
      else:
        walk = walk.right
    else:
      return walk
  return nil


proc findFirst[T](m: Multiset[T], x: T): ptr Node[T] =
  result = m.find(x)
  while result.value == x:
    result.prev()
  result.next()


proc findLast[T](m: Multiset[T], x: T): ptr Node[T] =
  result = m.find(x)
  while result.value == x:
    result.next()
  result.prev()


proc lowerBound[T](m: Multiset[T], x: T): ptr Node[T] =
  if m.root.isNil:
    return nil

  result = m.root
  while true:
    let rel = cmp(x, result.value)
    if rel < 0:
      if result.left.isNil:
        break
      else:
        result = result.left
    elif rel > 0:
      if result.right.isNil:
        break
      else:
        result = result.right
    else:
      var walk = result
      while true:
        walk.prev()
        if walk.isNil or walk.value < x:
          return
        result.prev()


proc upperBound[T](m: Multiset[T], x: T): ptr Node[T] =
  if m.root.isNil:
    return nil

  result = m.root
  while true:
    let rel = cmp(x, result.value)
    if rel < 0:
      if result.left.isNil:
        break
      else:
        result = result.left
    elif rel > 0:
      if result.right.isNil:
        break
      else:
        result = result.right
    else:
      var walk = result
      while true:
        walk.next()
        result.next()
        if walk.isNil or walk.value > x:
          return


proc count[T](m: Multiset[T], x: T): int =
  var first, last = m.find(x)
  if first.isNil:
    return 0
  last.next()
  while not first.isNil and first.value == x:
    first.prev()
    inc result
  while not last.isNil and last.value == x:
    last.next()
    inc result


proc erase[T](m: var Multiset[T], x: T) =
  var node = m.find(x)
  if not node.isNil:
    m.erase(node)

var
  m: Multiset[int]
  v: seq[int]

const
  N = 100000
  X = 10000

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
    it.next()
    inc i

block:
  var
    it = m.last()
    i = 1
  while not it.isNil:
    assert it.value == vst[^i]
    it.prev()
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
    it.next()
    inc i

block:
  var 
    it = m.last()
    i = 1
  while not it.isNil:
    assert it.value == remainder[^i]
    it.prev()
    inc i

echo "passed erase test"

block:
  for i in 0..<1000:
    let x = rand(X)
    assert m.count(x) == remainder.count(x)

echo "passed count test"