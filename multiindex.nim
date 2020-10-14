import 
  macros, typetraits

macro zipFields(a, b: untyped): untyped =
  discard

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
  var k = 0
  for field in val.fields:
    inc k

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
      else:
        break



var mi: MultiIndex[(int, string)]

mi.add((3, "howdy"))
mi.add((2, "pardner"))

for x in mi.items(0):
  echo x
for x in mi.items(1):
  echo x