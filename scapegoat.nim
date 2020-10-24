import algorithm, random, sequtils

const
  balance_limit = 1

type
  Node[T] = object
    left, right, parent: ptr Node[T]
    value: T

  Multiset[T] = object
    root: ptr Node[T]
    size, max_size: int


proc `$`[T](node: ptr Node[T]): string =
  if node.isNil:
    return
  # echo node.left.addr, ' ', node.value, ' ', node.right.addr
  result = '(' & $node.left & ' ' & $node.value & ' ' & $node.right & ')'


proc `$`[T](m: Multiset[T]): string =
  result = "size: " & $m.size & " tree: " & $m.root


proc size[T](node: ptr Node[T]): int =
  # for production code, non-recursive size is probably preferable
  if node.isNil:
    return 0
  result = 1 + node.left.size + node.right.size


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


proc findScapegoat[T](m: Multiset[T], node: ptr Node[T]): ptr Node[T] =
  if node == m.root:
    return nil
  result = node
  while abs(result.left.size - result.right.size) <= balance_limit:
    if result == m.root:
      return nil
    result = result.parent


proc flatten[T](root: var ptr Node[T]): ptr Node[T] =
  # flatten a subtree into a doubly linked list, returning the first node
  result = root
  while not result.left.isNil:
    result = result.left
  var 
    last, walk = result
  walk.next()
  last.left = nil
  while not walk.isNil:
    last.right = walk
    last.parent = nil
    last = walk


proc buildFromSorted[T](first: var ptr Node[T], size: int): ptr Node[T] =
  # build a sorted bst from doubly linked list
  result = first
  for i in 0..<(size div 2):
    result = result.right
  var second = result.right
  if not result.left.isNil: 
    result.left.right = nil
  if not result.right.isNil:
    result.right.left = nil
  result.left = buildFromSorted(first, size div 2)
  result.right = buildFromSorted(first, size div 2 - 1)


proc insert[T](m: var Multiset[T], x: T) =
  var node: ptr Node[T] = create(Node[T])
  node.value = x
  inc m.size

  if m.root.isNil:
    m.root = node
    return

  # unbalanced insertion
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

  var scapegoat = m.findScapegoat(node)
  if not scapegoat.isNil:
    echo "BALANCING"

proc erase[T](m: var Multiset[T], node: var ptr Node[T]) =
  if node.left.isNil and node.right.isNil:
    # leaf
    if node.parent.left == node:
      node.parent.left = nil
    else: node.parent.right = nil
  elif node.left.isNil xor node.right.isNil:
    # one child
    var child: ptr Node[T]
    if node.left.isNil:
      child = node.right
    else:
      child = node.left
    if node.parent.isNil:
      m.root = child
      child.parent = nil
    else:
      if node.parent.left == node:
        node.parent.left = child
      else:
        node.parent.right = child
      child.parent = node.parent
  else:
    # two children
    var succ = node
    succ.next()
    if node.parent.isNil:
      m.root = succ
    else:
      if node.parent.left == node:
        node.parent.left = succ
      else:
        node.parent.right = succ
    # successor is guaranteed to have either no children or one right child
    if succ.parent.left == succ:
      succ.parent.left = succ.right
    else:
      succ.parent.right = succ.right
    if not succ.right.isNil:
      succ.right.parent = succ.parent
    succ.left = node.left
    succ.right = node.right
    succ.parent = node.parent
    node.left.parent = succ
    if not node.right.isNil:
      node.right.parent = succ

  `=destroy`(node)
  dealloc(node)
  dec m.size


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

proc count[T](m: Multiset[T], x: T): int =
  # consider better implementation
  # this has O(N) worst case
  # (for instance, container of all same value)
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