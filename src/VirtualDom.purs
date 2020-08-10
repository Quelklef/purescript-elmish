module VirtualDom where

import Prelude
import Control.Monad.Maybe.Trans (MaybeT(..), runMaybeT)
import Control.Monad.Writer.Trans (WriterT, lift, runWriterT, tell)
import Data.Argonaut (Json, (.:))
import Data.Argonaut as A
import Data.Array as Array
import Data.Batchable (Batchable(..))
import Data.Either (Either(..))
import Data.Either.Nested (type (\/))
import Data.List (List, (:))
import Data.Maybe (Maybe(..), fromMaybe, maybe)
import Data.Foldable (intercalate)
import Data.Traversable (traverse, traverse_)
import Data.TraversableWithIndex (traverseWithIndex)
import Data.Tuple.Nested (type (/\), (/\))
import Debug as Debug
import Effect (Effect)
import Effect.Console (log)
import Effect.Ref (Ref)
import Effect.Ref as Ref
import Effect.Uncurried
import Effect.Unsafe (unsafePerformEffect)
import Foreign.Object (Object)
import Sub (Callback, Sub, SubBuilder)
import Sub as Sub
import Unsafe.Coerce (unsafeCoerce)
import Web.DOM.Document (Document, createElement, createTextNode)
import Web.DOM.Element (Element, setAttribute, tagName)
import Web.DOM.Element as Element
import Web.DOM.Node (Node, appendChild, firstChild, parentNode, removeChild)
import Web.DOM.Text as Text
import Web.HTML as HTML
import Web.HTML.Window as Window
import Web.HTML.HTMLDocument as HTMLDocument
import Web.HTML.HTMLElement as HTMLElement

-- TODO: switch all Array (VNode msg) signatures to VNode msg signatures
todo :: ∀ a. a
todo = unsafeCoerce unit

todoTag :: ∀ a. String -> a
todoTag = unsafeCoerce

data SingleVNode msg
  = VNode
    { tag :: String
    , attributes :: Array (Attribute msg)
    , children :: (VNode msg)
    , node :: Maybe Node
    }
  | VText
    { text :: String
    , node :: Maybe Node
    }

type VNode msg
  = Batchable (SingleVNode msg)

data SingleAttribute msg
  = Str String String
  | Listener (Element -> Sub msg)

instance eqSingleAttribute :: Eq (SingleAttribute a) where
  eq (Str p1 v1) (Str p2 v2) = p1 == v1 && p2 == v2
  eq (Listener _) (Listener _) = true
  eq _ _ = false

type Attribute msg
  = Batchable (SingleAttribute msg)

type Position
  = List (List Int)

render :: ∀ msg. Array (VNode msg) -> Array (VNode msg) -> Effect (Sub msg)
render oldVNodes newVNodes = do
  htmlDocument <- HTML.window >>= Window.document
  let
    document :: Document
    document = HTMLDocument.toDocument htmlDocument
  realNodes /\ sub <-
    runWriterT
      $ traverseWithIndex
          ( todoTag
              """
              test
              """
          )
          newVNodes
  {-- _ <- Sub.something [] sub callback --}
  {-- mbodyNode <- map HTMLElement.toNode <$> HTMLDocument.body htmlDocument --}
  pure sub

{-
diff :: ∀ msg. Document -> Node -> Position -> VNode msg -> VNode msg -> WriterT (Sub msg) Effect (VNode msg)
diff doc parent position = go 0 []
  where
  go :: Int -> VNode msg -> VNode msg -> VNode msg -> WriterT (Sub msg) Effect (VNode msg)
  go index acc oldNode newNode = case oldNode, newNode of
    Batch oldNodes, Batch newNodes -> case Array.uncons oldNodes, Array.uncons newNodes of
      Just o, Just n -> todoTag "check if old is the same as the new"
      Just _, Nothing -> do
        lift $ traverse_ removeNode $ getNodes oldNodes
        pure acc
      Nothing, Just { head, tail } -> do
        vnode <- addNode doc parent (pure index : position) head
        go
          (index + 1)
          (Array.snoc acc vnode)
          oldNodes
          tail
      Nothing, Nothing -> pure acc
    Single _, Single _ -> todo
    _, _ -> todo

addNode :: ∀ msg. Document -> Node -> Position -> SingleVNode msg -> WriterT (Sub msg) Effect (VNode msg)
addNode doc parent position = todo --case _ of

  VNode { tag, attributes, children } -> do
    element <- lift $ createElement tag doc
    let
      elementNode = Element.toNode element
    childNodes <- traverseWithIndex (\i -> addNode doc elementNode (i : position)) children
    tell =<< (lift $ setAttributes position attributes element)
    _ <- lift $ appendChild elementNode parent
    pure
      $ Single
      $ VNode
          { tag
          , attributes
          , children:  childNodes
          , node: Just elementNode
          }
  VText { text } -> do
    lift
      $ Text.toNode
      <$> createTextNode text doc
      <#> (\node -> Single $ VText { text, node: Just node })
-}
getNodes :: ∀ msg. Array (VNode msg) -> Array Node
getNodes = Array.catMaybes <<< go
  where
  go :: Array (VNode msg) -> Array (Maybe Node)
  go =
    ( _
        >>= case _ of
            Single vnode -> case vnode of
              VNode r -> [ r.node ]
              VText r -> [ r.node ]
            Batch vnodes -> go vnodes
    )

removeNode :: Node -> Effect Unit
removeNode node = do
  parentNode node
    >>= ifJust (removeChild node)

ifJust :: ∀ a b. (a -> Effect b) -> Maybe a -> Effect Unit
ifJust f = maybe (pure unit) (f >>> (_ *> pure unit))

removeAllChildren :: Node -> Effect Unit
removeAllChildren node =
  firstChild node
    >>= case _ of
        Just child -> do
          _ <- removeChild child node
          removeAllChildren node
        Nothing -> pure unit

{-
renderMaybeT :: ∀ msg. Callback msg -> Array (VNode msg) -> Array (VNode msg) -> Effect Unit
renderMaybeT callback oldVNodes newVNodes = do
  result <-
    runMaybeT do
      htmlDocument <- lift $ HTML.window >>= Window.document
      let
        document :: Document
        document = HTMLDocument.toDocument htmlDocument
      realNodes /\ sub <- lift $ runWriterT $ traverseWithIndex (\i -> toRealNode (pure i) document) newVNodes
      _ <- lift $ Sub.something [] sub callback
      body <- MaybeT $ map HTMLElement.toNode <$> HTMLDocument.body htmlDocument
      lift $ appendChildren realNodes body
  pure $ fromMaybe unit result

toRealNode :: ∀ msg. Node -> Position -> Document -> VNode msg -> WriterT (Sub msg) Effect (VNode msg)
toRealNode parent position doc = case _ of
  Single vnode -> case vnode of
    VNode { tag, attributes, children } -> do
      element <- lift $ createElement tag doc
      let
        elementNode = Element.toNode element
      childNodes <- traverseWithIndex (\i -> toRealNode elementNode (i : position) doc) children
      tell =<< (lift $ setAttributes position attributes element)
      -- lift $ appendChildren childNodes elementNode 
      pure
        $ Single
        $ VNode
            { tag
            , attributes
            , children: childNodes
            , node: Just elementNode
            }
    VText { text } -> do
      lift
        $ Text.toNode
        <$> createTextNode text doc
        <#> (\node -> Single $ VText { text, node: Just node })
  Batch vnodes -> todo
-}
setAttributes :: ∀ msg. Position -> Array (Attribute msg) -> Element -> Effect (Sub msg)
setAttributes position a element = todo --go 0 a mempty

{-- where --}
{-- go :: Int -> Array (Attribute msg) -> Sub msg -> Effect (Sub msg) --}
{-- go attributePosition attributes acc = case Array.uncons attributes of --}
{--   Just { head, tail } -> case head of --}
{--     Single sa -> case sa of --}
{--       Str prop value -> do --}
{--         setAttribute prop value element --}
{--         go (attributePosition + 1) tail acc --}
{--       Listener toSub -> do --}
{--         go (attributePosition + 1) --}
{--           tail --}
{--           $ acc --}
{--           <> ( toSub --}
{--                 (subIdPrefix (attributePosition : position)) --}
{--                 element --}
{--             ) --}
{--     Batch _ -> todo --}
{--   Nothing -> pure acc --}
subIdPrefix :: Position -> String
subIdPrefix = intercalate "-" <<< map show

appendChildren :: Array Node -> Node -> Effect Unit
appendChildren children node = case Array.uncons children of
  Just { head, tail } -> do
    _ <- appendChild head node
    appendChildren tail node
  Nothing -> pure unit

subIdRef :: Ref Int
subIdRef = unsafePerformEffect $ Ref.new 0

newSubId :: Effect String
newSubId = do
  currentId <- Ref.read subIdRef
  Ref.write (currentId + 1) subIdRef
  pure $ "dom sub " <> show currentId
