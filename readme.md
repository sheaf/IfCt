# if-instance <a href="https://hackage.haskell.org/package/if-instance" alt="Hackage"><img src="https://img.shields.io/hackage/v/if-instance.svg" /></a>

This library provides a way to branch on whether a constraint is satisfied:

```haskell
{-# OPTIONS_GHC -fplugin=IfSat.Plugin #-}

module MyModule where

import Data.Constraint.If ( IfSat(ifSat) )

hypot :: forall a. ( Floating a, IfSat (FMA a) ) => a -> a -> a
hypot = ifSat @(FMA a) withFMA withoutFMA
  where
    withFMA :: FMA a => a -> a -> a
    withFMA x y =
      let
        h = sqrt $ fma x x (y * y)
        h² = h * h
        x² = x * x
        u = fma (-y) y (h² - x²) + fma h h (-h²) - fma x x (-x²)
      in
        h - u / ( 2 * h )
    withoutFMA :: a -> a -> a
    withoutFMA x y = sqrt ( x * x + y * y )
```

`hypot x y` computes the value of `sqrt( x² + y² )` in a different way
depending on whether a fused multiply-add operation `fma` is available
for the type `a`.

## When does branch selection occur?

What is important to understand is that the branch selection happens
precisely when we need to solve the `IfSat ct` constraint.

```haskell
{-# OPTIONS_GHC -fplugin=IfSat.Plugin #-}
module M1 where

showFun :: forall (a :: Type). IfSat ( Show ( a -> a ) ) => ( a -> a ) -> String
showFun = ifSat @( Show (a -> a) ) show ( \ _ -> "<<function>>" )

test1 :: ( Bool -> Bool ) -> String
test1 fun = showFun fun

----------------------------------------

{-# OPTIONS_GHC -fplugin=IfSat.Plugin #-}
module M2 where

import M1

instance Show ( Bool -> Bool ) where
  show f = show [ f False, f True ]

test2 :: ( a -> a ) -> String
test2 fun = showFun fun

test3 :: ( Bool -> Bool ) -> String
test3 fun = showFun fun
```

After loading `M2`, we get the following results:

```haskell
test1 not
```
> `"<<function>>"`

In this example, to typecheck `test1` we need to solve `IfSat (Show (Bool -> Bool))`
inside module `M1`.  
As no instance for `Show (Bool -> Bool)` is available in `M1`, we pick the second branch,
resulting in `"<<function>>"`.

```haskell
test2 not
```
> `"<<function>>"`

In this example, we must solve `IfSat (Show (a -> a))` within `M2`.
There is no such instance in `M2`, so we pick the second branch.  
It doesn't matter that we are calling `test2` with a function of type
`Bool -> Bool`: we had to solve `IfSat (Show (a -> a))` when type-checking
the type signature of `test2`.

```haskell
test3 not
```
> `"[True, False]"`

In this last example, we must solve `IfSat (Show (Bool -> Bool))`, but as we're in `M2`,
such an instance is available, so we choose the first branch.

Note in particular that `test1` and `test3` have the exact same definition
(same type signature, same body), but produce a different result.
This is because the satisfiability check happens in different contexts.

## A type-family too!

If you prefer working at the type-level, this library has got you covered, with the `IsSat` type family.  
To reduce `IsSat ct`, GHC will first attempt to solve `ct`. If it succeeds, then `IsSat ct` reduces to `True`;
otherwise, it reduces to `False`. This means that the satisfiability check is performed precisely at the time of type-family reduction.

# Doesn't this library already exist?

Yes. Mike Izbicki's [`ifCxt` library](https://github.com/mikeizbicki/ifcxt) inspired this library.

What's the difference? `ifCxt` requires users to manually declare `IfCxt` instances
for all the typeclasses they want to work with, e.g. by using Template Haskell.  
On the other hand, this library only requires users to enable the plugin,
which directly hooks into GHC to solve the `IfSat` instances, without requiring
large amounts of instances to be defined by hand.  
This also means that users have more flexibility: as we saw above, branch selection occurs
when the `IfSat ct` constraint is discharged, looking at all the information
that is available at that point. This includes instance declarations,
Given constraints, local evidence (e.g. from GADT pattern matches), etc.

Furthermore, this library isn't limited to working with typeclasses and their instances: any constraint
can be passed to `IfSat`, e.g. an equality constraint involving a type family, which might only be satisfied
in the presence of further type-family equations.
