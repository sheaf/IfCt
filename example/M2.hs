
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

{-# OPTIONS_GHC -fplugin=IfCt.Plugin #-}

module M2 where

import M1

instance Show ( Bool -> Bool ) where
  show f = show [ f False, f True ]

test2 :: ( a -> a ) -> String
test2 fun = showFun fun

test3 :: ( Bool -> Bool ) -> String
test3 fun = showFun fun

test :: String
test =
  unlines
    [ test1 not
    , test2 not
    , test3 not
    , showFun not
    ]