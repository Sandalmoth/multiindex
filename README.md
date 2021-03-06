# multiindex
This library implements a datastructure for tuples that is ordered in every dimension. 
Insertion, deletion, and searching are all O(log(N)) on average.

### Example
```nim
import multiindex

var m: Multiindex[2, (int, string)]

m.incl((3, "defeat"))
m.incl((1, "elephants"))
m.incl((5, "bug"))
m.incl((2, "can"))
m.incl((4, "a"))

var it = m.first(0)
while not it.isNil:
  echo it.value
  it.next(0)

# (1, "elephants")
# (2, "can")
# (3, "defeat")
# (4, "a")
# (5, "bug")

for x in m.items(1):
  echo x

# (4, "a")
# (5, "bug")
# (2, "can")
# (3, "defeat")
# (1, "elephants")

it = m.find(0, 3)
echo it.value
it.next(1)
echo it.value
it.next(0)
echo it.value

# (3, "defeat")
# (1, "elephants")
# (2, "can")
```
