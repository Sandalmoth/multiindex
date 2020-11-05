# To run these tests, simply execute `nimble test`.

import algorithm, random, sequtils, unittest


import multiindex


test "inserting and ordered iteration":
  var 
    m: Multiindex[2, (int, float)]
    v1: seq[int]
    v2: seq[float]
  for i in 0..<100:
    m.clear()
    v1.setLen(0)
    v2.setLen(0)
    for j in 0..<100:
      let
        x = rand(999)
        y = rand(1.0)
      v1.add(x)
      v2.add(y)
      m.incl((x, y))
    v1.sort()
    v2.sort()
    var
      it1 = m.first(0)
      it2 = m.first(1)
    for j in 0..<100:
      check it1.value[0] == v1[j]
      check it2.value[1] == v2[j]
      it1.next(0)
      it2.next(1)
        

test "searching, erasing and reverse iteration":
  var 
    m: Multiindex[2, (int, float)]
    v1: seq[int]
    v2: seq[float]
    v3: seq[(int, float)]
  for i in 0..<100:
    m.clear()
    v1.setLen(0)
    v2.setLen(0)
    v3.setLen(0)
    for j in 0..<100:
      let
        x = rand(999)
        y = rand(1.0)
      m.incl((x, y))
      if rand(1.0) > 0.5:
        v3.add((x, y))
      else:
        v1.add(x)
        v2.add(y)
    v1.sort()
    v2.sort()
    v3.shuffle()
    for x in v3:
      m.excl(m.find(x))
    var
      it1 = m.last(0)
      it2 = m.last(1)
    for j in countdown(v1.len - 1, 0):
      check it1.value[0] == v1[j]
      check it2.value[1] == v2[j]
      it1.prev(0)
      it2.prev(1)
        
test "counting":
  var 
    m: Multiindex[2, (int, int)]
    v1: seq[int]
    v2: seq[int]
    v3: seq[(int, int)]
  for i in 0..<100:
    m.clear()
    v1.setLen(0)
    v2.setLen(0)
    v3.setLen(0)
    for j in 0..<100:
      let
        x = rand(99)
        y = rand(99)
      m.incl((x, y))
      v1.add(x)
      v2.add(y)
      v3.add((x, y))
    for j in 0..<100:
      let z = rand(99)
      check m.count(0, z) == v1.count(z)
      check m.count(1, z) == v2.count(z)
      check m.count((z, z)) == v3.count((z, z))


test "iterator":
  var 
    m: Multiindex[2, (int, float)]
    v1: seq[int]
    v2: seq[float]
  for i in 0..<100:
    m.clear()
    v1.setLen(0)
    v2.setLen(0)
    for j in 0..<100:
      let
        x = rand(999)
        y = rand(1.0)
      v1.add(x)
      v2.add(y)
      m.incl((x, y))
    v1.sort()
    v2.sort()
    var k = 0
    for x in m.items(0):
      check x[0] == v1[k]
      inc k
    k = 0
    for x in m.items(1):
      check x[1] == v2[k]
      inc k


test "modifyable iterator":
  var 
    m: Multiindex[2, (int, float, int)]
    v1: seq[int]
    v2: seq[float]
    v3: seq[int]
  for i in 0..<100:
    m.clear()
    v1.setLen(0)
    v2.setLen(0)
    v3.setLen(0)
    for j in 0..<100:
      let
        x = rand(999)
        y = rand(1.0)
        z = rand(999)
      v1.add(x)
      v2.add(y)
      m.incl((x, y, z))
    v1.sort()
    v2.sort()
    for x in m.mitems(0):
      let z = rand(999)
      v3.add(z)
      x[2] = z
    for x in m.mitems(1):
      x[2] *= x[2]
    var k = 0
    for x in m.items():
      check x[2] == v3[k]*v3[k]
      inc k