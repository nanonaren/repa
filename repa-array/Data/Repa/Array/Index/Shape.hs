
-- | Class of types that can be used as array shapes and indices.
module Data.Repa.Array.Index.Shape
        ( Shape(..)
        , inShape
        , showShape )
where
#include "repa-array.h"


-- | Class of types that can be used as array shapes and indices.
class Eq sh => Shape sh where

        -- | Get the number of dimensions in a shape.
        rank           :: sh -> Int

        -- | The shape of an array of size zero, with a particular
        --  dimensionality.
        zeroDim        :: sh

        -- | The shape of an array with size one,
        --   with a particular dimensionality.
        unitDim        :: sh

        -- | Compute the intersection of two shapes.
        intersectDim   :: sh -> sh -> sh

        -- | Add the coordinates of two shapes componentwise
        addDim         :: sh -> sh -> sh

        -- | Get the total number of elements in an array with this shape.
        size           :: sh -> Int

        -- | Given a starting and ending index, check if some index is with
        --  that range.
        inShapeRange   :: sh -> sh -> sh -> Bool

        -- | Convert a shape into its list of dimensions.
        listOfShape    :: sh -> [Int]

        -- | Convert a list of dimensions to a shape
        shapeOfList    :: [Int] -> Maybe sh


-------------------------------------------------------------------------------
instance Shape Int where
        rank _                  = 1
        zeroDim                 = 0
        unitDim                 = 1
        intersectDim s1 s2      = max s1 s2
        addDim       s1 s2      = s1 + s2
        size s                  = s
        inShapeRange i1 i2 i    = i >= i1 && i <= i2
        listOfShape  i          = [i]
        shapeOfList  [i]        = Just i
        shapeOfList  _          = Nothing
        {-# INLINE rank         #-}
        {-# INLINE zeroDim      #-}
        {-# INLINE unitDim      #-}
        {-# INLINE intersectDim #-}
        {-# INLINE addDim       #-}
        {-# INLINE size         #-}
        {-# INLINE inShapeRange #-}
        {-# INLINE listOfShape  #-}
        {-# INLINE shapeOfList  #-}


-------------------------------------------------------------------------------
-- | Given an array shape and index, check whether the index is in the shape.
inShape ::  Shape sh => sh -> sh -> Bool
inShape sh ix
        = inShapeRange zeroDim sh ix
{-# INLINE_ARRAY inShape #-}


-- | Nicely format a shape as a string
showShape :: Shape sh => sh -> String
showShape = foldr (\sh str -> str ++ " :. " ++ show sh) "Z" . listOfShape
{-# NOINLINE showShape #-}
