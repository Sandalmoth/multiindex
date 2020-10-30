# Copyright (c) 2020 Jonathan Lindström
# 
# This software is provided 'as-is', without any express or implied
# warranty. In no event will the authors be held liable for any damages
# arising from the use of this software.
# 
# Permission is granted to anyone to use this software for any purpose,
# including commercial applications, and to alter it and redistribute it
# freely, subject to the following restrictions:
# 
# 1. The origin of this software must not be misrepresented; you must not
#    claim that you wrote the original software. If you use this software
#    in a product, an acknowledgment in the product documentation would be
#    appreciated but is not required.
# 2. Altered source versions must be plainly marked as such, and must not be
#    misrepresented as being the original software.
# 3. This notice may not be removed or altered from any source distribution.


# Code relating to treap operations is written in part according to
# opendatastructures.org, c++ edition (Oct 2020)


## This module implements a container for tuples that supports logarithmic time
## searching as well as ordered iteration along any of the tuple fields.
## 
## Basic usage
## -----------
##
## .. code-block::
##   import multiindex
##
##   var m: Multiindex[2, (int, string)]
##
##   m.incl((3, "defeat"))
##   m.incl((1, "elephants"))
##   m.incl((5, "bug"))
##   m.incl((2, "can"))
##   m.incl((4, "a"))
##
##   var it = m.first(0)
##   while not it.isNil:
##     echo it.value
##     it.next(0)
## 
##   # (1, "elephants")
##   # (2, "can")
##   # (3, "defeat")
##   # (4, "a")
##   # (5, "bug")
##
##   it = m.first(1)
##   while not it.isNil:
##     echo it.value
##     it.next(1)
## 
##   # (4, "a")
##   # (5, "bug")
##   # (2, "can")
##   # (3, "defeat")
##   # (1, "elephants")
## 
## Caveats
## -------
## 
## Elements can not be modified in the first ``K`` dimensions without breaking
## the container. The unindexed higher dimensions can be altered freely.
## If a modification is necessary in the indexed dimensions, 
## deleting and reinserting is the best option.
## 
## Performance in some operations scale not just with log(N), but also with 
## the number of equivalent elements. As tuple position 0 is used as default
## performance may improve by ensuring that position 0 is the one where all
## elements have the least amount of overlap.
##
## The container is not deterministic with regards to equivalent keys.
## It does not support multithreading
## and makes calls to the default instance of rand.
## 


import 
  macros, typetraits, random


proc macroReplaceRecursive(old, to: NimNode, ast: NimNode): NimNode =
  # recursively replace all instances of 'old' nimnodes with 'to'
  # in the AST given by 'ast'
  # implementation works for this case, but may be flawed in the general case
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
  # echo "-- Unrolled:", body.repr
  # echo "-- To:", result.repr, '\n'


type
  Header[K, T] = object
    parent, left, right: ptr Node[K, T]

  Node*[K: static int, T: tuple] = object
    ## Node of the internal treap.
    ## Node pointers are used to access elements
    ## similar to a C++ iterator.
    headers: array[K, Header[K, T]]
    priority: int
    value*: T

  Multiindex*[K: static int, T: tuple] = object
    ## Multiset type container for tuples.
    ## Supports searching and ordered iteration along any
    ## of the tuple dimensions.
    ## Only the first ``K`` dimensions are indexed, the rest
    ## are carried along and can be accessed, but not searched.
    roots: array[K, ptr Node[K, T]]
    counter: int


proc toString[K, T](node: ptr Node[K, T], k: static int): string =
  if node.isNil:
    return
  result = '[' & $node.headers[k].left.tostring(k) & ' ' & $node.value[k] & 
           ':' & $node.priority & ' ' & $node.headers[k].right.tostring(k) & ']'


proc `$`*[K, T](m: Multiindex[K, T]): string =
  result = "size: " & $m.counter & '\n'
  staticFor k, 0, K:
    result = result & $k & " tree: " & m.roots[k].toString(k) & '\n'


proc len*[K, T](m: Multiindex[K, T]): int =
  ## Returns the number of items in ``m``.
  m.counter


proc first*[K, T](m: Multiindex[K, T], k: static int): ptr Node[K, T] =
  ## Return a pointer to the leftmost (smallest) item in ``m`` along dimension ``k``.
  if m.roots[k].isNil:
    return nil

  result = m.roots[k]
  while not result.headers[k].left.isNil:
    result = result.headers[k].left


proc last*[K, T](m: Multiindex[K, T], k: static int): ptr Node[K, T] =
  ## Return a pointer to the rightmost (largest) item in ``m`` along dimension ``k``.
  if m.roots[k].isNil:
    return nil

  result = m.roots[k]
  while not result.headers[k].right.isNil:
    result = result.headers[k].right


proc next*[K, T](node: var ptr Node[K, T], k: static int) =
  ## Move pointer right (towards greater values) in dimension ``k``.
  if node.headers[k].right.isNil:
    while not node.headers[k].parent.isNil and node == node.headers[k].parent.headers[k].right:
      node = node.headers[k].parent
    node = node.headers[k].parent
  else:
    node = node.headers[k].right
    while not node.headers[k].left.isNil:
      node = node.headers[k].left


proc prev*[K, T](node: var ptr Node[K, T], k: static int) =
  ## Move pointer left (towards smaller values) in dimension ``k``.
  if node.headers[k].left.isNil:
    while not node.headers[k].parent.isNil and node == node.headers[k].parent.headers[k].left:
      node = node.headers[k].parent
    node = node.headers[k].parent
  else:
    node = node.headers[k].left
    while not node.headers[k].right.isNil:
      node = node.headers[k].right


proc rotateLeft[K, T](m: var Multiindex[K, T], k: static int, u: ptr Node[K, T]) =
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


proc rotateRight[K, T](m: var Multiindex[K, T], k: static int, u: ptr Node[K, T]) =
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


proc incl*[K, T](m: var Multiindex[K, T], x: T) =
  ## Add a tuple ``x`` to the container ``m``
  let node: ptr Node[K, T] = create(Node[K, T])
  node.value = x
  node.priority = rand(int.high)

  if m.roots[0].isNil:
    for k in 0..<K:
      m.roots[k] = node
    inc m.counter
    return

  # insert new node
  var walk: ptr Node[K, T]
  staticFor k, 0, K:
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


proc excl*[K, T](m: var Multiindex[K, T], node: ptr Node[K, T]) =
  ## Remove a tuple indicated by the pointer ``node`` from the container ``m``.
  ## Trying to remove a node not present in the container causes undefined behaviour.
  var walk: ptr Node[K, T]
  staticFor k, 0, K:
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


proc find*[K, T, U](m: Multiindex[K, T], k: static int, x: U): ptr Node[K, T] =
  ## Find an element with the value ``x`` in tuple dimension ``k``.
  ## The result is deterministic in the sense that calling it twice without
  ## modifying ``m`` in between will produce the same result.
  ## However, if the container changes, the element found may change as well
  ## so long as it fulfills ``result.value[k] == x``.
  if m.roots[k].isNil:
    return nil

  var walk = m.roots[k]
  while true:
    let rel = cmp(x, walk.value[k])
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


proc find*[K, T](m: Multiindex[K, T], x: T): ptr Node[K, T] =
  ## Find a node that exactly matches the tuple ``x``.
  ## The result is deterministic in the sense that calling it twice without
  ## modifying ``m`` in between will produce the same result.
  ## However, if the container changes, the element found may change as well
  ## so long as it fulfills ``result.value == x``.
  var up, down = m.find(0, x[0])
  if up.isNil:
    return nil
  while not down.isNil and down.value[0] == x[0]:
    if down.value == x:
      return down
    down.prev(0)
  up.next(0)
  while not up.isNil and up.value[0] == x[0]:
    if up.value == x:
      return up
    up.next(0)
  return nil


proc findFirst*[K, T, U](m: Multiindex[K, T], k: static int, x: U): ptr Node[K, T] =
  ## Similar to `find proc<#find,Multiindex[K, T],staticint,U>`_ but is guaranteed to
  ## the first one along the given dimension. In other words, the
  ## predecessor to the result is either smaller along dimension ``k``, 
  ## or ``nil``
  var walk = m.find(k, x)
  while not walk.isNil and walk.value[k] == x:
    result = walk
    walk.prev(k)


proc findFirst*[K, T](m: Multiindex[K, T], x: T): ptr Node[K, T] =
  ## Similar to `find proc<#find,Multiindex[K, T],T>`_ but is guaranteed to
  ## the first one along the given dimension.
  var walk = m.find(0, x[0])
  while not walk.isNil and walk.value == x:
    result = walk
    walk.prev(0)


proc findLast*[K, T, U](m: Multiindex[K, T], k: static int, x: U): ptr Node[K, T] =
  ## Similar to `find proc<#find,Multiindex[K, T],staticint,U>`_ but is guaranteed to
  ## the last one along the given dimension. In other words, the
  ## successor to the result is either smaller along dimension ``k``, 
  ## or ``nil``
  var walk = m.find(k, x)
  while not walk.isNil and walk.value[k] == x:
    result = walk
    walk.next(k)


proc findLast*[K, T](m: Multiindex[K, T], x: T): ptr Node[K, T] =
  ## Similar to `find proc<#find,Multiindex[K, T],T>`_ but is guaranteed to
  ## the last one along the given dimension.
  var walk = m.find(0, x[0])
  while not walk.isNil and walk.value == x:
    result = walk
    walk.next(0)


proc count*[K, T, U](m: Multiindex[K, T], k: static int, x: U): int =
  ## Count the number of elements that equal ``x`` in dimension ``k``.
  var first, last = m.find(k, x)
  if first.isNil:
    return 0
  last.next(k)
  while not first.isNil and first.value[k] == x:
    first.prev(k)
    inc result
  while not last.isNil and last.value[k] == x:
    last.next(k)
    inc result


proc count*[K, T](m: Multiindex[K, T], x: T): int =
  ## Count the number of elements that exactly equal ``x``.
  var first, last = m.find(x)
  if first.isNil:
    return 0
  last.next(0)
  while not first.isNil and first.value == x:
    first.prev(0)
    inc result
  while not last.isNil and last.value == x:
    last.next(0)
    inc result


proc clear*[K, T](m: var Multiindex[K, T]) =
  ## Remove all elements from the container.
  var 
    data: seq[ptr Node[K, T]]
    walk = m.first(0)

  while not walk.isNil:
    data.add(walk)
    walk.next(0)

  for i in 0..<data.len:
    `=destroy`(data[i])
    dealloc(data[i])
  
  m.counter = 0
  for k in 0..<K:
    m.roots[k] = nil


proc `=destroy`[K, T](m: var Multiindex[K, T]) =
  # in order traversal of the tree for field k
  m.clear()


# default version should work just the same
# proc `=sink`[K, T](a: var Multiindex[K, T], b: Multiindex[K, T]) =
#   `=destroy`(a)
#   wasMoved(a)
#   a.roots = b.roots
#   a.counter = b.counter


proc `=copy`[K, T](a: var Multiindex[K, T], b: Multiindex[K, T]) =
  if a.roots == b.roots:
    return
  `=destroy`(a)
  wasMoved(a)
  var walk = b.first(0)
  while not walk.isNil:
    a.incl(walk.value)
    walk.next(0)
