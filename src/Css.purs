module Css where

import MasonPrelude
import Data.Array as Array
import Data.Batchable (Batched(..), flatten, flattenMap)
import Data.List ((:))
import Data.List as List
import Data.Map (Map)
import Data.Map as Map
import Debug as Debug
import Murmur3 as Murmur3

data Style
  = Declaration StringOp String String

type Styles
  = Batched Style

process :: List Style -> Maybe { class :: String, css :: String }
process styles =
  if List.null styles then
    Nothing
  else
    toMap styles
      # foldlWithIndex
          ( \k acc v ->
              let
                declarations =
                  " {\n"
                    <> joinMap
                        ( \(Declaration _ prop value) ->
                            "\t" <> prop <> ": " <> value <> ";"
                        )
                        "\n"
                        v
                    <> "\n}"
              in
                case acc of
                  Id -> Id <> Const declarations
                  _ -> acc <> Const "\n\n" <> Id <> Const declarations
          )
          Id
      # Just
      <. makeHash

makeHash :: StringOp -> { class :: String, css :: String }
makeHash toCssOp =
  let
    toCss = Debug.debugger $ apply toCssOp
  in
    toCss "o"
      # hash
      # show
      # (<>) "_"
      # \c ->
          { "class": c
          , css: toCss $ "." <> c
          }

toMap :: List Style -> Map StringOp (List Style)
toMap =
  foldr
    ( \style@(Declaration op _ _) acc ->
        Map.alter
          ( case _ of
              Just list -> Just $ style : list
              Nothing -> Just $ pure $ style
          )
          op
          acc
    )
    mempty

hash :: String -> Int
hash = Murmur3.hash 0

joinMap :: ∀ a. (a -> String) -> String -> List a -> String
joinMap f sep list = case list of
  only : Nil -> f only
  first : rest -> f first <> sep <> joinMap f sep rest
  Nil -> ""

data StringOp
  = Id
  | Const String
  | Combine StringOp StringOp
  | Compose StringOp StringOp

derive instance eqStringOp :: Eq StringOp

derive instance ordStringOp :: Ord StringOp

instance semigroupStringOp :: Semigroup StringOp where
  append = Combine

apply :: StringOp -> String -> String
apply stringOp str = case stringOp of
  Id -> str
  Const s -> s
  Combine so1 so2 -> apply so1 str <> apply so2 str
  Compose so1 so2 -> apply so1 $ apply so2 str

append :: String -> StringOp
append s = Id <> Const s

prepend :: String -> StringOp
prepend s = Const s <> Id

duplicate :: String -> StringOp
duplicate s = Id <> Const s <> Id

declaration :: String -> String -> Styles
declaration = Single <.. Declaration Id

mapSelector :: StringOp -> Array Styles -> Styles
mapSelector op styles =
  Batch styles
    # flattenMap
        ( \(Declaration op' p v) ->
            Single $ Declaration (Compose op op') p v
        )
    # Array.fromFoldable
    # Batch
