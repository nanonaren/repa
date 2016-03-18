
-- | Interface with chain fusion.
module Data.Repa.Eval.Chain
        ( chainOfArray
        , unchainToArray
        , unchainToArrayIO)
where
import Data.Repa.Chain                 (Chain(..), Step(..))
import Data.Repa.Array.Generic.Index                    as A
import Data.Repa.Array.Internals.Bulk                   as A
import Data.Repa.Array.Internals.Target                 as A
import qualified Data.Vector.Fusion.Stream.Monadic      as S
import qualified Data.Vector.Fusion.Stream.Size         as S
import qualified Data.Vector.Fusion.Util                as S
import System.IO.Unsafe
#include "repa-array.h"


-------------------------------------------------------------------------------
-- | Produce a `Chain` for the elements of the given array.
--   The order in which the elements appear in the chain is
--   determined by the layout of the array.
chainOfArray
        :: (Monad m, Bulk l a)
        => Array l a -> Chain m Int a

chainOfArray !arr
 = Chain (S.Exact len) 0 step
 where
        !len  = A.length arr

        step !i
         | i >= len     = return $ Done  i
         | otherwise
         = return $ Yield (A.index arr $ A.fromIndex (A.layout arr) i) (i + 1)
        {-# INLINE_INNER step #-}
{-# INLINE_STREAM chainOfArray #-}


-- | Lift a pure chain to a monadic chain.
liftChain :: Monad m => Chain S.Id s a -> Chain m s a
liftChain (Chain sz s step)
        = Chain sz s (return . S.unId . step)
{-# INLINE_STREAM  liftChain #-}


-------------------------------------------------------------------------------
-- | Compute the elements of a pure `Chain`,
--   writing them into a new array `Array`.
unchainToArray
        :: Target l a
        => Name l -> Chain S.Id s a -> (Array l a, s)
unchainToArray nDst c
        = unsafePerformIO
        $ unchainToArrayIO nDst
        $ liftChain c
{-# INLINE_STREAM unchainToArray #-}


-- | Compute the elements of an `IO` `Chain`,
--   writing them to a new `Array`.
unchainToArrayIO
        :: Target l a
        => Name l -> Chain IO s a -> IO (Array l a, s)

unchainToArrayIO nDst (Chain sz s0 step)
 = case sz of
        S.Exact i       -> unchainToArrayIO_max     i
        S.Max i         -> unchainToArrayIO_max     i
        S.Unknown       -> unchainToArrayIO_unknown 32

        -- unchain when we known the maximum size of the vector.
 where  unchainToArrayIO_max !nMax
         = do   !vec0   <- unsafeNewBuffer  (create nDst zeroDim)
                !vec    <- unsafeGrowBuffer vec0 nMax

                let go_unchainIO_max !sPEC !i !s
                     =  step s >>= \m
                     -> case m of
                         Yield e s'
                          -> do  unsafeWriteBuffer vec i e
                                 go_unchainIO_max sPEC (i + 1) s'

                         Skip s'
                          ->     go_unchainIO_max sPEC i s'

                         Done s'
                          -> do  buf'    <- unsafeSliceBuffer  0 i vec
                                 arr     <- unsafeFreezeBuffer buf'
                                 return  (arr, s')
                    {-# INLINE_INNER go_unchainIO_max #-}

                go_unchainIO_max S.SPEC 0 s0
        {-# INLINE_INNER unchainToArrayIO_max #-}

        -- unchain when we don't know the maximum size of the vector.
        unchainToArrayIO_unknown !nStart
         = do   !vec0   <- unsafeNewBuffer  (create nDst zeroDim)
                !vec1   <- unsafeGrowBuffer vec0 nStart

                let go_unchainIO_unknown !uvec !i !n !s 
                     = go_unchainIO_unknown1 uvec i n s
                         (\vec' i' n' s' -> go_unchainIO_unknown vec' i' n' s')
                         (\result        -> return result)

                    go_unchainIO_unknown1 !vec !i !n !s cont done
                     =  step s >>= \r
                     -> case r of
                         Yield e s'
                          -> do (vec', n')
                                 <- if i >= n
                                        then do vec' <- unsafeGrowBuffer vec n
                                                return (vec', n + n)
                                        else    return (vec,  n)
                                unsafeWriteBuffer vec' i e
                                cont vec' (i + 1) n' s'

                         Skip s'
                          ->    cont vec i n s'

                         Done s'
                          -> do
                                vec' <- unsafeSliceBuffer  0 i vec
                                arr  <- unsafeFreezeBuffer vec'
                                done (arr, s')

                go_unchainIO_unknown vec1 0 nStart s0
        {-# INLINE_INNER unchainToArrayIO_unknown #-}
{-# INLINE_STREAM unchainToArrayIO #-}

