-- |
-- Module: Optics.AffineFold
-- Description: A 'Optics.Fold.Fold' that contains at most one element.
--
-- An 'AffineFold' is a 'Optics.Fold.Fold' that contains at most one
-- element, or a 'Optics.Getter.Getter' where the function may be
-- partial.
--
module Optics.AffineFold
  (
  -- * Formation
    AffineFold

  -- * Introduction
  , afolding

  -- * Elimination
  , preview
  , previews

  -- * Computation
  -- |
  --
  -- @
  -- 'preview' ('afolding' f) ≡ f
  -- @

  -- * Additional introduction forms
  , afoldVL
  , filtered

  -- * Additional elimination forms
  , atraverseOf_
  , isn't

    -- * Semigroup structure
  , afailing

  -- * Subtyping
  , An_AffineFold
  -- | <<diagrams/AffineFold.png AffineFold in the optics hierarchy>>
  ) where

import Data.Maybe

import Data.Profunctor.Indexed

import Optics.Internal.Bi
import Optics.Internal.Optic

-- | Type synonym for an affine fold.
type AffineFold s a = Optic' An_AffineFold NoIx s a

-- | Obtain an 'AffineFold' by lifting 'traverse_' like function.
--
-- @
-- 'afoldVL' '.' 'atraverseOf_' ≡ 'id'
-- 'atraverseOf_' '.' 'afoldVL' ≡ 'id'
-- @
afoldVL
  :: (forall f. Functor f => (forall r. r -> f r) -> (a -> f u) -> s -> f v)
  -> AffineFold s a
afoldVL f = Optic (rphantom . visit f . rphantom)
{-# INLINE afoldVL #-}

-- | Retrieve the value targeted by an 'AffineFold'.
--
-- >>> let _Right = prism Right $ either (Left . Left) Right
--
-- >>> preview _Right (Right 'x')
-- Just 'x'
--
-- >>> preview _Right (Left 'y')
-- Nothing
--
preview :: Is k An_AffineFold => Optic' k is s a -> s -> Maybe a
preview o = previews o id
{-# INLINE preview #-}

-- | Retrieve a function of the value targeted by an 'AffineFold'.
previews :: Is k An_AffineFold => Optic' k is s a -> (a -> r) -> s -> Maybe r
previews o = \f -> runForgetM $
  getOptic (castOptic @An_AffineFold o) $ ForgetM (Just . f)
{-# INLINE previews #-}

-- | Traverse over the target of an 'AffineFold', computing a 'Functor'-based
-- answer, but unlike 'Optics.AffineTraversal.atraverseOf' do not construct a
-- new structure.
atraverseOf_
  :: (Is k An_AffineFold, Functor f)
  => Optic' k is s a
  -> (forall r. r -> f r) -> (a -> f u) -> s -> f ()
atraverseOf_ o point f s = case preview o s of
  Just a  -> () <$ f a
  Nothing -> point ()

-- | Create an 'AffineFold' from a partial function.
--
-- >>> preview (afolding listToMaybe) "foo"
-- Just 'f'
--
afolding :: (s -> Maybe a) -> AffineFold s a
afolding f = Optic (contrabimap (\s -> maybe (Left s) Right (f s)) Left . right')
{-# INLINE afolding #-}

-- | Filter result(s) of a fold that don't satisfy a predicate.
filtered :: (a -> Bool) -> AffineFold a a
filtered p = afoldVL (\point f a -> if p a then f a else point a)
{-# INLINE filtered #-}

-- | Try the first 'AffineFold'. If it returns no entry, try the second one.
--
-- >>> preview (ix 1 % re _Left `afailing` ix 2 % re _Right) [0,1,2,3]
-- Just (Left 1)
--
-- >>> preview (ix 42 % re _Left `afailing` ix 2 % re _Right) [0,1,2,3]
-- Just (Right 2)
--
-- /Note:/ There is no 'Optics.Fold.summing' equivalent, because @asumming = afailing@.
--
afailing
  :: (Is k An_AffineFold, Is l An_AffineFold)
  => Optic' k is s a
  -> Optic' l js s a
  -> AffineFold s a
afailing a b = afolding $ \s -> maybe (preview b s) Just (preview a s)
infixl 3 `afailing` -- Same as (<|>)
{-# INLINE afailing #-}

-- | Check to see if this 'AffineFold' doesn't match.
--
-- >>> isn't _Just Nothing
-- True
--
isn't :: Is k An_AffineFold => Optic' k is s a -> s -> Bool
isn't k s = not (isJust (preview k s))
{-# INLINE isn't #-}

-- $setup
-- >>> import Optics.Core
