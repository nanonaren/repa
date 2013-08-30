{-# LANGUAGE MagicHash #-}
module Main where
import Data.Array.Repa.Series           as R
import Data.Array.Repa.Series.Series    as S
import Data.Array.Repa.Series.Vector    as V
import Data.Array.Repa.Series.Ref       as Ref
import qualified Data.Vector.Unboxed    as U
import Data.Word
import GHC.Exts

---------------------------------------------------------------------
-- | Set the primitives used by the lowering transform.
repa_primitives :: R.Primitives
repa_primitives =  R.primitives


---------------------------------------------------------------------
main
 = do   v1      <- V.fromUnboxed $ U.enumFromN (1 :: Float) 10
        r1      <- Ref.new 0
        r2      <- Ref.new 1
        R.runSeries v1 (lower_rreduce (RateNat (int2Word# 10#)) r1 r2) 
                `seq` return ()


-- Double reduce fusion.
--  Computation of both reductions is interleaved.
lower_rreduce :: RateNat k -> Ref Float -> Ref Float -> Series k Float -> ()
lower_rreduce _ ref1 ref2 s
 =      R.reduce ref1 (+) 0 s 
 `seq`  R.reduce ref2 (*) 1 s
{-# NOINLINE lower_rreduce #-}