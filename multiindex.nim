import 
  macros, typetraits

proc macroReplaceRecursive(old, to: NimNode, ast: NimNode): NimNode =
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

macro forStatic(index: untyped, a, b: static int, body: untyped): untyped =
  result = nnkStmtList.newTree()
  for j in a..<b:
    result.add(
      macroReplaceRecursive(index, newLit(j), body)
    )

  echo "-- Unrolled:", body.repr
  echo "-- To:", result.repr, '\n'

# unclear why t.type.arity sometimes cannot be used directly.
# This makes it possible to access the number of elements in
# a tuple without issue however, and with a familiar syntax.
func len(t: typedesc): static int =
  t.type.arity

type
  Header[T] = object
    parent, left, right: T

  Node[T: tuple] = ref object
    headers: array[T.len, Header[Node[T]]]
    value: T

  MultiIndex[T: tuple] = object
    root: Node[T]


proc newNode[T](val: T): Node[T] =
  new result
  result.value = val

proc add(mi: var MultiIndex; val: mi.T) =
  var node = newNode(val)

  if mi.root.isNil:
    mi.root = node
    return

  # unbalanced insertion for now
  # TODO switch to scapegoat tree
  var 
    root = mi.root
  forStatic k, 0, mi.T.len:
    while true:
      echo root.headers
      if cmp(node.value[k], root.value[k]) < 0:
        if root.headers[k].left.isNil:
          root.headers[k].left = node
          node.headers[k].parent = root
          break
        else:
          root = root.headers[k].left
      else:
        if root.headers[k].right.isNil:
          root.headers[k].right = node
          node.headers[k].parent = root
          break
        else:
          root = root.headers[k].right
    

iterator items(mi: MultiIndex, k: static int): mi.T =
  # in order traversal of the tree for field k
  var 
    leftDone = false
    node = mi.root

  while not node.isNil:
    if not leftDone:
      while not node.headers[k].left.isNil:
        node = node.headers[k].left
      
    yield node.value

    leftDone = true
    if not node.headers[k].right.isNil:
      leftDone = false
      node = node.headers[k].right
    elif not node.headers[k].parent.isNil:
      while not node.headers[k].parent.isNil and node == node.headers[k].parent.headers[k].right:
        node = node.headers[k].parent
      if node.headers[k].parent.isNil:
        break
      node = node.headers[k].parent
    else:
      break



var mi: MultiIndex[(int, string)]

mi.add((3, "howdy"))
mi.add((2, "pardner"))
mi.add((1, "xavier"))
mi.add((4, "another"))

for x in mi.items(0):
  echo x
for x in mi.items(1):
  echo x