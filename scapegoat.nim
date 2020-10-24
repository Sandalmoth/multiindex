import algorithm, random

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
  result = '(' & $node.left & ' ' & $node.value & ' ' & $node.right & ')'


proc `$`[T](m: Multiset[T]): string =
  result = "size: " & $m.size & " tree: " & $m.root


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


proc erase[T](m: var Multiset[T], node: var ptr Node[T]) =
  if node.left.isNil and node.right.isNil:
    # leaf
    echo "leaf"
    if node.parent.left == node:
      node.parent.left = nil
    else: node.parent.right = nil
  elif node.left.isNil xor node.right.isNil:
    # one child
    echo "one"
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
    echo "two"
    var succ = node
    succ.next()
    # if succ.parent.left == succ:
      # succ.parent.left = nil
    # else: succ.parent.right = nil
    if succ.parent.left == succ:
      succ.parent.left = succ.right
    else:
      succ.parent.right = succ.right
    if not succ.right.isNil:
      succ.right.parent = succ.parent
    succ.left = node.left
    succ.right = node.right
    succ.parent = node.parent

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


var
  m: Multiset[int]
  v: seq[int]

randomize()
for i in 0..<10:
  let x = rand(100 div 2)
  echo x
  m.insert(x)
  v.add(x)

var
  to_erase = v[0..<(v.len div 6)].sorted()
  remainder = v[(v.len div 6)..<v.len].sorted()
  vst = v.sorted()

echo m

block:
  var 
    it = m.first()
    i = 0
  while not it.isNil:
    echo it.value, ' ', vst[i]
    assert it.value == vst[i]
    it.next()
    inc i

block:
  var
    it = m.last()
    i = 1
  while not it.isNil:
    echo it.value, ' ', vst[^i]
    assert it.value == vst[^i]
    it.prev()
    inc i

echo "erasing"

block:
  for x in to_erase:
    var it = m.find(x)
    echo x, ' ', it.value
    m.erase(it)

echo m

block:
  var 
    it = m.first()
    i = 0
  while not it.isNil:
    echo it.value, ' ', remainder[i]
    assert it.value == remainder[i]
    it.next()
    inc i