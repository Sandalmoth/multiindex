# The treap requires random numbers.
# Nim's random is not default initialized, hence would required
# an initialization step, which is bad for the multiindex interface.
# Thus, here is a rng that initializes to a random state

import times

type
  Lcg* = object
    s: uint64

const
  a: uint64 = 0xd1342543de82ef95'u64 # see arXiv:2001.05304

proc rand*(rng: var Lcg): uint32

proc seed*(rng: var Lcg, s: uint64) =
  rng.s = ((0xb345341e570d3083'u64 xor s) shl 1'u64) or 1'u64 # odd state
  rng.s = ((rng.rand().uint64 shl 32'u64) or rng.rand().uint64) xor s
  rng.s = (rng.s shl 1'u64) or 1'u64 # odd state

proc randomize(rng: var Lcg) =
  let now = getTime()
  rng.seed((now.toUnix * 1_000_000_000 + now.nanosecond).uint64)

proc rand*(rng: var Lcg): uint32 =
  if rng.s == 0:
    # initialize if unused
    rng.randomize()

  rng.s = a * rng.s # odd*odd = odd hence cannot become 0 == uinitialized
  (rng.s shr 16'u64).uint32
