

module Data.Array.Repa.Repr.Partitioned
        ( P, Array (..)
        , Range(..)
        , inRange)
where
import Data.Array.Repa.Base
import Data.Array.Repa.Shape
import Data.Array.Repa.Eval
import Data.Array.Repa.Repr.Delayed


-- | Partitioned arrays.
--   The last partition takes priority
--
--   These are produced by Repa's support functions and allow arrays to be defined
--   using a different element function for each partition.
--
--   The basic idea is described in ``Efficient Parallel Stencil Convolution'',
--   Ben Lippmeier and Gabriele Keller, Haskell 2011 -- though the underlying
--   array representation has changed since this paper was published.
--
data P r1 r2

data instance Array (P r1 r2) sh e
        = APart !sh                          -- size of the whole array
                !(Range sh) !(Array r1 sh e) -- if in range use this array
                !(Array r2 sh e)             -- otherwise use this array

data Range sh
        = Range !sh !sh                      -- indices defining the range
                (sh -> Bool)                 -- predicate to check whether were in range

-- | Check whether an index is within the given range.
inRange :: Range sh -> sh -> Bool
inRange (Range _ _ p) ix
        = p ix
{-# INLINE inRange #-}


-- Repr -----------------------------------------------------------------------
-- | Read elements from a partitioned array.
instance (Repr r1 e, Repr r2 e) => Repr (P r1 r2) e where
 index (APart _ range arr1 arr2) ix
   | inRange range ix   = index arr1 ix
   | otherwise          = index arr2 ix
 {-# INLINE index #-}

 linearIndex arr@(APart sh _ _ _) ix
        = index arr $ fromIndex sh ix
 {-# INLINE linearIndex #-}

 extent (APart sh _ _ _) 
        = sh
 {-# INLINE extent #-}

 deepSeqArray (APart sh range arr1 arr2) y
  = sh `deepSeq` range `deepSeqRange` arr1 `deepSeqArray` arr2 `deepSeqArray` y
 {-# INLINE deepSeqArray #-}


deepSeqRange :: Shape sh => Range sh -> b -> b
deepSeqRange (Range ix sz f) y
        = ix `deepSeq` sz `deepSeq` f `seq` y
{-# INLINE deepSeqRange #-}


-- Fill -----------------------------------------------------------------------
instance ( FillRange r1 r3 sh e, Fill r2 r3 sh e
         , Fillable r3 e)
        => Fill (P r1 r2) r3 sh e where
 fillP (APart _ (Range ix sz _) arr1 arr2) marr
  = do  fillRangeP arr1 marr ix sz
        fillP arr2 marr
 {-# INLINE fillP #-}

 fillS (APart _ (Range ix sz _) arr1 arr2) marr
  = do  fillRangeS arr1 marr ix sz
        fillS arr2 marr
 {-# INLINE fillS #-}
