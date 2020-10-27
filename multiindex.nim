import 
  macros, typetraits, random


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


type
  Header[T] = object
    parent, left, right: ptr Node[T]

  Node[T: tuple] = object
    headers: array[T.tupleLen, Header[T]]
    priority: int
    value: T

  Multiindex[T: tuple] = object
    roots: array[T.tupleLen, ptr Node[T]]
    counter: int


proc toString[T](node: ptr Node[T], k: static int): string =
  if node.isNil:
    return
  result = '[' & $node.headers[k].left.tostring(k) & ' ' & $node.value[k] & 
           ':' & $node.priority & ' ' & $node.headers[k].right.tostring(k) & ']'


proc `$`[T](m: Multiindex[T]): string =
  result = "size: " & $m.counter & '\n'
  staticFor k, 0, T.tupleLen:
    result = result & $k & " tree: " & m.roots[k].toString(k) & '\n'

proc len[T](m: Multiindex[T]): int =
  m.counter


proc first[T](m: Multiindex[T], k: static int): ptr Node[T] =
  if m.roots[k].isNil:
    return nil

  result = m.roots[k]
  while not result.headers[k].left.isNil:
    result = result.headers[k].left


proc last[T](m: Multiindex[T], k: static int): ptr Node[T] =
  if m.roots[k].isNil:
    return nil

  result = m.roots[k]
  while not result.headers[k].right.isNil:
    result = result.headers[k].right


proc next[T](node: var ptr Node[T], k: static int) =
  if node.headers[k].right.isNil:
    while not node.headers[k].parent.isNil and node == node.headers[k].parent.headers[k].right:
      node = node.headers[k].parent
    node = node.headers[k].parent
  else:
    node = node.headers[k].right
    while not node.headers[k].left.isNil:
      node = node.headers[k].left


proc prev[T](node: var ptr Node[T], k: static int) =
  if node.headers[k].left.isNil:
    while not node.headers[k].parent.isNil and node == node.headers[k].parent.headers[k].left:
      node = node.headers[k].parent
    node = node.headers[k].parent
  else:
    node = node.headers[k].left
    while not node.headers[k].right.isNil:
      node = node.headers[k].right


proc rotateLeft[T](m: var Multiindex[T], k: static int, u: ptr Node[T]) =
  let w = u.headers[k].right
  w.headers[k].parent = u.headers[k].parent
  if not w.headers[k].parent.isNil:
    if w.headers[k].parent.headers[k].left == u:
      w.headers[k].parent.headers[k].left = w
    else:
      w.headers[k].parent.headers[k].right = w
  u.headers[k].right = w.headers[k].left
  if not u.headers[k].right.isNil:
    u.headers[k].right.headers[k].parent = u
  u.headers[k].parent = w
  w.headers[k].left = u
  if u == m.roots[k]:
    m.roots[k] = w
    w.headers[k].parent = nil


proc rotateRight[T](m: var Multiindex[T], k: static int, u: ptr Node[T]) =
  let w = u.headers[k].left
  w.headers[k].parent = u.headers[k].parent
  if not w.headers[k].parent.isNil:
    if w.headers[k].parent.headers[k].left == u:
      w.headers[k].parent.headers[k].left = w
    else:
      w.headers[k].parent.headers[k].right = w
  u.headers[k].left = w.headers[k].right
  if not u.headers[k].left.isNil:
    u.headers[k].left.headers[k].parent = u
  u.headers[k].parent = w
  w.headers[k].right = u
  if u == m.roots[k]:
    m.roots[k] = w
    w.headers[k].parent = nil


proc incl[T](m: var Multiindex[T], x: T) =
  let node: ptr Node[T] = create(Node[T])
  node.value = x
  node.priority = rand(99)#rand(int.high)

  if m.roots[0].isNil:
    for k in 0..<T.tupleLen:
      m.roots[k] = node
    inc m.counter
    return

  # insert new node
  var walk: ptr Node[T]
  staticFor k, 0, m.T.tupleLen:
    walk = m.roots[k]
    while true:
      if cmp(node.value[k], walk.value[k]) < 0:
        if walk.headers[k].left.isNil:
          walk.headers[k].left = node
          node.headers[k].parent = walk
          break
        else: walk = walk.headers[k].left
      else:
        if walk.headers[k].right.isNil:
          walk.headers[k].right = node
          node.headers[k].parent = walk
          break
        else: walk = walk.headers[k].right

    # preserve heap property through rotations
    while not node.headers[k].parent.isNil and node.headers[k].parent.priority > node.priority:
      if node.headers[k].parent.headers[k].right == node:
        m.rotateLeft(k, node.headers[k].parent)
      else:
        m.rotateRight(k, node.headers[k].parent)
    if node.headers[k].parent.isNil:
      m.roots[k] = node

  inc m.counter


proc excl[T](m: var Multiindex[T], node: ptr Node[T]) =
  var walk: ptr Node[T]
  staticFor k, 0, m.T.tupleLen:
    walk = node
  # move node so that it becomes a leaf
    while not (walk.headers[k].left.isNil and walk.headers[k].right.isNil):
      if walk.headers[k].left.isNil:
        m.rotateLeft(k, walk)
      elif walk.headers[k].right.isNil:
        m.rotateRight(k, walk)
      elif walk.headers[k].left.priority < walk.headers[k].right.priority:
        m.rotateRight(k, walk)
      else:
        m.rotateLeft(k, walk)
      if m.roots[k] == walk:
        m.roots[k] = walk.headers[k].parent
    
    # remove (leaf) node
    if walk.headers[k].parent.headers[k].left == walk:
      walk.headers[k].parent.headers[k].left = nil
    else:
      walk.headers[k].parent.headers[k].right = nil
  
  dec m.counter
  `=destroy`(walk)
  dealloc(walk)


proc find[T, U](m: Multiindex[T], k: static int, x: U): ptr Node[T] =
  if m.roots[k].isNil:
    return nil

  var walk = m.roots[k]
  while true:
    let rel = cmp(x[k], walk.value[k])
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


proc find[T](m: Multiindex[T], x: T): ptr Node[T] =
  var up, down = m.find(0, x[0])
  while not down.isNil and down.value[0] == x[0]:
    if down.value == x:
      return down
    down.prev()
  up.next()
  while not up.isNil and up.value[0] == x[0]:
    if up.value == x:
      return up
    up.next()
  return nil


proc findFirst[T, U](m: Multiindex[T], k: static int, x: U): ptr Node[T] =
  var walk = m.find(k, x)
  while not walk.isNil and result.value[k] == x:
    result = walk
    walk.prev()


proc findFirst[T](m: Multiindex[T], x: T): ptr Node[T] =
  var walk = m.find(x)
  while not walk.isNil and result.value == x:
    result = walk
    walk.prev()


proc findLast[T, U](m: Multiindex[T], k: static int, x: U): ptr Node[T] =
  var walk = m.find(k, x)
  while not walk.isNil and result.value[k] == x:
    result = walk
    walk.next()


proc findLast[T](m: Multiindex[T], x: T): ptr Node[T] =
  var walk = m.find(x)
  while not walk.isNil and result.value == x:
    result = walk
    walk.next()


proc count[T, U](m: Multiindex[T], k: static int, x: U): int =
  var first, last = m.find(k, x)
  if first.isNil:
    return 0
  last.next()
  while not first.isNil and first.value[k] == x:
    first.prev()
    inc result
  while not last.isNil and last.value[k] == x:
    last.next()
    inc result


proc count[T](m: Multiindex[T], x: T): int =
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


proc clear[T](m: var Multiindex[T]) =
  var 
    data: seq[ptr Node[T]]
    walk = m.first(0)

  while not walk.isNil:
    data.add(walk)
    walk.next(0)

  for i in 0..<data.len:
    `=destroy`(data[i])
    dealloc(data[i])
  
  m.counter = 0
  for k in 0..<T.tupleLen:
    m.roots[k] = nil


proc `=destroy`[T](m: var Multiindex[T]) =
  # in order traversal of the tree for field k
  m.clear()


# default version should work just the same
# proc `=sink`[T](a: var Multiindex[T], b: Multiindex[T]) =
#   `=destroy`(a)
#   wasMoved(a)
#   a.roots = b.roots
#   a.counter = b.counter


proc `=copy`[T](a: var Multiindex[T], b: Multiindex[T]) =
  if a.roots == b.roots:
    return
  `=destroy`(a)
  wasMoved(a)
  var walk = b.first(0)
  while not walk.isNil:
    a.incl(walk.value)
    walk.next(0)


randomize(1)

var m: Multiindex[(int, string, float)]

m.incl((1, "howdy", 4.5))
echo m
m.incl((2, "xavier", 29.3))
echo m
m.incl((3, "pardner", 3.8))
echo m
m.incl((4, "another", 22.0))
echo m

for i in 0..<3:
  echo cast[int](m.roots[i])

block:
  var it = m.first(0)
  while not it.isNil:
    echo it.value, '\t', it.priority, '\t', cast[int](it)
    it.next(0)
  it = m.last(0)
  while not it.isNil:
    echo it.value, '\t', it.priority
    it.prev(0)
  echo " "

block:
  var it = m.first(1)
  while not it.isNil:
    echo it.value, '\t', it.priority, '\t', cast[int](it)
    it.next(1)
  it = m.last(1)
  while not it.isNil:
    echo it.value, '\t', it.priority
    it.prev(1)
  echo " "

block:
  var it = m.first(2)
  while not it.isNil:
    echo it.value, '\t', it.priority, '\t', cast[int](it)
    it.next(2)
  it = m.last(2)
  while not it.isNil:
    echo it.value, '\t', it.priority
    it.prev(2)
  echo " "

echo m
m.excl(m.roots[1])
echo m

block:
  var it = m.first(0)
  while not it.isNil:
    echo it.value, '\t', it.priority, '\t', cast[int](it)
    it.next(0)
  it = m.last(0)
  while not it.isNil:
    echo it.value, '\t', it.priority
    it.prev(0)
  echo " "

block:
  var it = m.first(1)
  while not it.isNil:
    echo it.value, '\t', it.priority, '\t', cast[int](it)
    it.next(1)
  it = m.last(1)
  while not it.isNil:
    echo it.value, '\t', it.priority
    it.prev(1)
  echo " "

block:
  var it = m.first(2)
  while not it.isNil:
    echo it.value, '\t', it.priority, '\t', cast[int](it)
    it.next(2)
  it = m.last(2)
  while not it.isNil:
    echo it.value, '\t', it.priority
    it.prev(2)
  echo " "

block:
  var m2: m.type
  m2 = m

  m2.incl((123, "yo", 1.23))

  echo "yo"
  echo m
  echo "yo"
  echo m2