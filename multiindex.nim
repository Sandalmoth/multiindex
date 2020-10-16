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

macro forStatic(index: untyped, a, b: static int, body: untyped): untyped =
  # static for loop emulation which unrolls a statement like
  # forStatic i, 0, 2:
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
    roots: array[T.len, Header[T]]


# proc newNode[T](val: T): Node[T] =
#   new result
#   result.value = val

proc add(mi: var MultiIndex; val: mi.T) =
  discard
  # var node = newNode(val)

#   if mi.root.isNil:
#     mi.root = node
#     return

#   # unbalanced insertion for now
#   # TODO switch to scapegoat tree
#   var 
#     root = mi.root
#   forStatic k, 0, mi.T.len:
#     while true:
#       echo node.value[k], ' ', root.value[k], ' ', cmp(node.value[k], root.value[k])
#       if cmp(node.value[k], root.value[k]) < 0:
#         echo "lesser"
#         if root.headers[k].left.isNil:
#           echo "adding l"
#           root.headers[k].left = node
#           node.headers[k].parent = root
#           break
#         else:
#           echo "diving l"
#           root = root.headers[k].left
#       else:
#         echo "greater"
#         if root.headers[k].right.isNil:
#           echo "adding r"
#           root.headers[k].right = node
#           node.headers[k].parent = root
#           break
#         else:
#           echo "diving r"
#           root = root.headers[k].right
    

# iterator items(mi: MultiIndex, k: static int): mi.T =
#   # in order traversal of the tree for field k
#   var 
#     leftDone = false
#     node = mi.root

#   while not node.isNil:
#     if not leftDone:
#       while not node.headers[k].left.isNil:
#         node = node.headers[k].left
      
#     yield node.value

#     leftDone = true
#     if not node.headers[k].right.isNil:
#       leftDone = false
#       node = node.headers[k].right
#     elif not node.headers[k].parent.isNil:
#       while not node.headers[k].parent.isNil and node == node.headers[k].parent.headers[k].right:
#         node = node.headers[k].parent
#       if node.headers[k].parent.isNil:
#         break
#       node = node.headers[k].parent
#     else:
#       break



var mi: MultiIndex[(int, string, float)]

mi.add((3, "howdy", 4.5))
mi.add((2, "pardner", 3.8))
mi.add((1, "xavier", 29.3))
mi.add((4, "another", 22.0))

# for x in mi.items(0):
#   echo x
# for x in mi.items(1):
#   echo x
# for x in mi.items(2):
#   echo x

# echo "\n"
# echo mi.root.value
# echo mi.root.headers[2].left.value
# echo mi.root.headers[2].right.value
# echo mi.root.headers[2].left.headers[2].right.value