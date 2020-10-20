import 
  macros, typetraits

proc macroReplaceRecursive(old, to: NimNode, ast: NimNode): NimNode =
  # recursively replace all instances of 'old' nimnodes with 'to'
  # in the AST given by 'ast'
  # TODO: implementation works for this case, but may be flawed
  # TODO: consider making a better implementation
  result = ast.copyNimTree()
  case result.kind:
    of nnkNone, nnkEmpty, nnkNilLit, nnkCharLit..nnkUInt64Lit, nnkFloatLit..nnkFloat64Lit, 
        nnkStrLit..nnkTripleStrLit, nnkCommentStmt, nnkIdent, nnkSym:
      discard
    else:
      for i in 0..<result.len:
        if result[i] == old:
          result[i] = to
        else:
          result[i] = macroReplaceRecursive(old, to, result[i])

macro staticFor(index: untyped, a, b: static int, body: untyped): untyped =
  # static for loop emulation which unrolls a statement like
  # staticFor i, 0, 2:
  #   echo i
  # to
  # echo 0
  # echo 1
  # this allows for looping through the elements of a tuple
  result = nnkStmtList.newTree()
  for j in a..<b:
    result.add(
      macroReplaceRecursive(index, newLit(j), body)
    )
  # debug printing
  echo "-- Unrolled:", body.repr
  echo "-- To:", result.repr, '\n'

# unclear why t.type.arity sometimes cannot be used directly.
# This makes it possible to access the number of elements in
# a tuple without issue however, and with a familiar syntax.
func len(t: typedesc): static int =
  t.type.arity

type
  Header[T] = object
    parent, left, right: ptr Node[T]

  Node[T: tuple] = object
    headers: array[T.len, Header[T]]
    value: T

  MultiIndex[T: tuple] = object
    roots: array[T.len, ptr Node[T]]
    counter: int


iterator nodes[T: tuple](mi: MultiIndex[T], k: static int): ptr Node[T] =
  # in order traversal of the tree for field k
  var 
    leftDone = false
    walk = mi.roots[k]

  while not walk.isNil:
    if not leftDone:
      while not walk.headers[k].left.isNil:
        walk = walk.headers[k].left
    
    yield walk

    leftDone = true
    if not walk.headers[k].right.isNil:
      leftDone = false
      walk = walk.headers[k].right
    elif not walk.headers[k].parent.isNil:
      while not walk.headers[k].parent.isNil and walk == walk.headers[k].parent.headers[k].right:
        walk = walk.headers[k].parent
      if walk.headers[k].parent.isNil:
        break
      walk = walk.headers[k].parent
    else:
      break

proc findNode[T: tuple, K](mi: MultiIndex[T], k: static int, key: K): ptr Node[T] =
  var walk: ptr Node[mi.T]
  walk = mi.roots[k]
  while true:
    let rel = cmp(key, walk.value[k])
    if rel < 0:
      if walk.headers[k].left.isNil:
        break
      else:
        walk = walk.headers[k].left
    elif rel > 0:
      if walk.headers[k].right.isNil:
        break
      else:
        walk = walk.headers[k].right
    else:
      return walk
  return nil

proc next[T](node: ptr Node[T], k: static int): ptr Node[T] =
  if node.headers[k].right.isNil:
    if node.headers[k].parent.headers[k].right == node:
      return nil
    else:
      result = node.headers[k].parent
  else:
    result = node.headers[k].right
    while not result.headers[k].left.isNil:
      result = result.headers[k].left

proc `=destroy`[T](mi: var MultiIndex[T]) =
  # in order traversal of the tree for field k
  var data: seq[ptr Node[T]]
  for node in mi.nodes(0):
    data.add(node)

  for i in 0..<data.len:
    `=destroy`(data[i])
    dealloc(data[i])

proc len(mi: MultiIndex): int =
  return mi.counter

proc add(mi: var MultiIndex; val: mi.T) =
  var node: ptr Node[mi.T] = create(Node[mi.T])
  node.value = val
  inc mi.counter

  if mi.roots[0].isNil:
    # not very defensive programming, but if one 
    # is unset, then the rest should be as well
    staticFor k, 0, mi.T.len:
      mi.roots[k] = node
    return

  # unbalanced insertion for now
  # TODO switch to scapegoat tree
  var walk: ptr Node[mi.T]
  staticFor k, 0, mi.T.len:
    walk = mi.roots[k]
    while true:
      if cmp(node.value[k], walk.value[k]) < 0:
        if walk.headers[k].left.isNil:
          walk.headers[k].left = node
          node.headers[k].parent = walk
          break
        else:
          walk = walk.headers[k].left
      else:
        if walk.headers[k].right.isNil:
          walk.headers[k].right = node
          node.headers[k].parent = walk
          break
        else:
          walk = walk.headers[k].right
    
iterator items(mi: MultiIndex, k: static int): mi.T =
  # in order traversal of the tree for field k
  var 
    leftDone = false
    walk = mi.roots[k]

  while not walk.isNil:
    if not leftDone:
      while not walk.headers[k].left.isNil:
        walk = walk.headers[k].left
    
    yield walk.value

    leftDone = true
    if not walk.headers[k].right.isNil:
      leftDone = false
      walk = walk.headers[k].right
    elif not walk.headers[k].parent.isNil:
      while not walk.headers[k].parent.isNil and walk == walk.headers[k].parent.headers[k].right:
        walk = walk.headers[k].parent
      if walk.headers[k].parent.isNil:
        break
      walk = walk.headers[k].parent
    else:
      break

proc hasKey[T: tuple, K](mi: MultiIndex[T], k: static int, key: K): bool =
  not findNode(mi, k, key).isNil

proc find[T: tuple, K](mi: MultiIndex[T], k: static int, key: K): T =
  # find the first occurence of key ordered by dimension k
  let node = findNode(mi, k, key)
  if node.isNil:
    raise newException(KeyError, "key not found: " & $key)
  return node.value

proc del[T](mi: var MultiIndex[T], val: T) =
  var node = findNode(mi, 0, val[0])
  if node.isNil:
    return
  while node.value != val:
    node = node.next(0)
  echo node.value, val
  staticFor k, 0, mi.T.len:
    if node.headers[k].left.isNil and node.headers[k].right.isNil:
      # leaf node
      if node.headers[k].parent.headers[k].left == node:
        node.headers[k].parent.headers[k].left = nil
      else:
        node.headers[k].parent.headers[k].right = nil
    elif node.headers[k].left.isNil xor node.headers[k].right.isNil:
      # node has single child
      if node.headers[k].left.isNil:
        if node.headers[k].parent.headers[k].left == node:
          node.headers[k].parent.headers[k].left = node.headers[k].right
        else:
          node.headers[k].parent.headers[k].right = node.headers[k].right
      else:
        if node.headers[k].parent.headers[k].left == node:
          node.headers[k].parent.headers[k].left = node.headers[k].left
        else:
          node.headers[k].parent.headers[k].right = node.headers[k].left
    else:
      # node has two children
      var next = node.next(k)
      if next.headers[k].parent.headers[k].left == next:
        next.headers[k].parent.headers[k].left = nil
      else:
        next.headers[k].parent.headers[k].right = nil
      next.headers[k] = node.headers[k]

  `=destroy`(node)
  dealloc(node)

proc contains[T](mi: MultiIndex, val: T): bool =
  for node in mi.nodes(0):
    if node.value == val:
      return true
  false

proc `[]`[T, K](mi: MultiIndex[T], k: static int, key: K): MultiIndex[T] =
  # returns a new multiindex container
  # subsetted using the key
  var 
    node = findNode(mi, k, key)

  if node.isNil:
    return

  while not node.isNil and node.value[k] == key:
    result.add(node.value)
    node = node.next(k)

proc `[]`[T, K](mi: MultiIndex[T], k: static int, slice: HSlice[K, K]): MultiIndex[T] =
  # returns a new multiindex container
  # subsetted using the key slice (from..to) inclusive
  var 
    node = findNode(mi, k, slice.a)

  if node.isNil:
    return

  if not mi.hasKey(k, slice.b):
    return

  var 
    next = true
    atB = false

  while not node.isNil and next:
    result.add(node.value)
    node = node.next(k)
    if slice.b == node.value[k]:
      atB = true
    else:
      if atB:
        next = false

proc union[T](mi1, mi2: MultiIndex[T]): MultiIndex[T] =
  for item in mi1.items(0):
    result.add(item)
  for item in mi2.items(0):
    result.add(item)

proc `+`[T](mi1, mi2: MultiIndex[T]): MultiIndex[T] {.inline.} =
  union(mi1, mi2)


var mi: MultiIndex[(int, string, float)]

mi.add((1, "howdy", 4.5))
mi.add((0, "pardner", 3.8))
mi.add((1, "xavier", 29.3))
mi.add((0, "another", 22.0))

for x in mi.items(0):
  echo x
for x in mi.items(1):
  echo x
for x in mi.items(2):
  echo x

echo "\n"
echo mi.find(0, 1)
echo mi.find(1, "xavier")
echo mi.hasKey(1, "jimmy")
echo  (1, "xavier", 29.3) in mi
echo  (3, "jimmy", 129.3) in mi

echo "\n"
var mi2 = mi[0, 1]
for x in mi2.items(1):
  echo x

echo "\n"
var mi3 = mi[2, 3.8..22.0]
for x in mi3.items(1):
  echo x


echo "\n"
var mi4 = mi + mi2 + mi3
for x in mi4.items(2):
  echo x

echo "deleting ", (1, "howdy", 4.5)
# mi4.del((1, "howdy", 4.5))
mi4.del((0, "pardner", 3.8))
echo "produces"
for x in mi4.items(2):
  echo x