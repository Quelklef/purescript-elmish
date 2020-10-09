module Main (main) where

import MasonPrelude
import Attribute as A
import Control.Monad.Trans.Class (lift)
import Control.Monad.Writer.Class (tell)
import Css as C
import Data.Array ((..))
import Data.Array as Array
import Data.Batchable (Batched(..))
import Data.DateTime.Instant as Instant
import Data.Newtype (unwrap)
import Data.String (Pattern(..))
import Data.String as String
import Debug as Debug
import Effect.Class.Console (log, logShow)
import Effect.Now (now)
import Html (Html)
import Html as H
import HTML.All as HA
import Platform (Cmd, Program, Update, attemptTask)
import Platform as Platform
import Task
import Sub (Sub(..), SubBuilder)
import Sub as Sub
import VirtualDom

people :: Array String
people = [ "Mason", "Belle", "Luke", "Nic" ]

main :: Program Unit Model Msg
main =
  Platform.app
    { init
    , update
    , subscriptions
    , view
    }

-- MODEL
type Model
  = { input :: String
    , counter :: Int
    , showingInput :: Boolean
    , time :: Number
    , people :: Array String
    , newPerson :: String
    , mousePosition :: Number /\ Number
    }

init :: Unit -> Update Model Msg
init _ = do
  currentTime <- lift $ now <#> Instant.unInstant >>> unwrap
  pure
    { input: ""
    , counter: 0
    , showingInput: true
    , time: currentTime
    , people: Array.sort people
    , newPerson: ""
    , mousePosition: 0.0 /\ 0.0
    }

-- UPDATE
data Msg
  = Increment
  | Decrement
  | InputChanged String
  | ToggleShowingInput
  | UpdateTime Number
  | Delete String
  | AddPerson
  | UpdateNewPerson String
  | MouseMoved (Number /\ Number)
  | NoOp

update :: Model -> Msg -> Update Model Msg
update model msg = do
  case msg of
    MouseMoved pos -> pure $ model { mousePosition = pos }
    UpdateNewPerson str -> pure $ model { newPerson = str }
    AddPerson ->
      if model.newPerson == "" then
        pure model
      else do
        pure $ model { people = Array.insert model.newPerson model.people }
    Delete person -> pure $ model { people = Array.delete person model.people }
    UpdateTime time -> pure $ model { time = time }
    ToggleShowingInput -> pure $ model { showingInput = not model.showingInput }
    InputChanged str -> pure $ model { input = str }
    Increment -> pure $ model { counter = model.counter + 1 }
    Decrement -> pure $ model { counter = model.counter - 1 }
    NoOp -> pure $ model

-- SUBSCRIPTIONS
subscriptions :: Model -> Sub Msg
subscriptions model = mempty --Sub.every (if model.showingInput then 1000.0 else 2000.0) UpdateTime

-- VIEW
view ::
  Model ->
  { head :: Array (Html Msg)
  , body :: Array (Html Msg)
  }
view model =
  { head:
      [ H.title model.newPerson
      , H.keyed "style" []
          [ "style"
              /\ H.element "style" []
                  [ H.text
                      """
  body {
    background: red;
  }
"""
                  ]
          ]
      ]
  , body:
      [ H.divS
          [ C.background "green"
          , C.border "1px solid black"
          , C.mapSelector
              (C.append " > div")
              [ C.fontWeight "bold"
              , C.fontFamily "serif"
              ]
          ]
          [] --A.onMouseMove MouseMoved ]
          [ H.divS
              [ C.fontSize "20px"
              , C.position "absolute"
              , C.top $ show (snd model.mousePosition) <> "px"
              , C.left $ "calc(" <> show (fst model.mousePosition) <> "px + 2px)"
              , C.width "20px"
              , C.height "20px"
              , C.background "black"
              ]
              []
              -- [ A.attribute "style" $ "position: absolute; top: "
              --     <> show (snd model.mousePosition)
              --     <> "px; left: calc("
              --     <> show (fst model.mousePosition)
              --     <> "px + 1px); width: 20px; height: 20px; background: black"
              -- ]
              []
          , H.div []
              [ H.text $ "("
                  <> show (fst model.mousePosition)
                  <> ","
                  <> show (snd model.mousePosition)
                  <> ")"
              ]
          , H.div []
              [ H.button [ A.onClick AddPerson ] [ H.text "Add Person" ]
              , H.input
                  [ A.value $ model.newPerson
                  , A.onInput UpdateNewPerson
                  ]
              ]
          , H.keyed "div" [] $ model.people
              <#> \person ->
                  person
                    /\ H.div []
                        [ H.text $ person <> " "
                        , H.button [ A.onClick $ Delete person ] [ H.text "x" ]
                        ]
          , H.div [] [ H.text $ show model.time ]
          , H.div []
              [ H.button [ A.onClick ToggleShowingInput ] [ H.text "Toggle Input" ]
              , if model.showingInput then
                  H.input
                    [ A.value model.input
                    , A.onInput InputChanged
                    ]
                else
                  mempty
              , H.div [] [ H.text model.input ]
              ]
          , (if model.showingInput then H.button else H.div) [ A.onClick Increment ] [ H.text "+" ]
          , H.button [ A.onClick Decrement ] [ H.text "-" ]
          , Batch $ 0 .. model.counter <#> \i -> H.div [] [ H.text $ show i ]
          ]
      ]
  }

handler :: HA.Event -> Effect Msg
handler =
  HA.toMaybeMouseEvent
    .> maybe (pure NoOp)
        ( \e -> do
            x <- HA.clientX e
            y <- HA.clientY e
            pure $ MouseMoved $ x /\ y
        )
