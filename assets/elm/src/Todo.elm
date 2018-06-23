port module Todo exposing (..)

{-| TodoMVC implemented in Elm, using plain HTML and CSS for rendering.

This application is broken up into three key parts:

1.  Model - a full definition of the application's state
2.  Update - a way to step the application state forward
3.  View - a way to visualize our application state with HTML

This clean division of concerns is a core part of Elm. You can read more about
this in <http://guide.elm-lang.org/architecture/index.html>

-}

import Dom
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Keyed as Keyed
import Html.Lazy exposing (lazy, lazy2)
import Json.Decode as Json
import Json.Decode.Pipeline as Pipeline
import Json.Encode as Encode
import Dict exposing (Dict)
import Task
import Time exposing (Time)
import Phoenix
import Phoenix.Socket as Socket exposing (Socket, AbnormalClose)
import Phoenix.Channel as Channel exposing (Channel)
import Phoenix.Presence as Presence exposing (Presence)
import Phoenix.Push as Push
import Uuid exposing (Uuid)
import Random.Pcg exposing (Seed, initialSeed, step)


{-| State is passed in from JavaScript local storage if found at startup. See js/app.js.
-}
main : Program (Maybe State) Model Msg
main =
    Html.programWithFlags
        { init = init
        , view = view
        , update = updateWithStorage
        , subscriptions = subscriptions
        }


{-| Implemntation in js/app.js.
-}
port setStorage : State -> Cmd msg


{-| We want to `setStorage` on every update. This function adds the setStorage
command for every step of the update function.
-}
updateWithStorage : Msg -> Model -> ( Model, Cmd Msg )
updateWithStorage msg model =
    let
        ( newModel, cmds ) =
            update msg model
    in
        ( newModel
        , Cmd.batch [ setStorage newModel.state, cmds ]
        )



-- MODEL
-- The full application state of our todo app.


type SocketStatus
    = SocketInitializing
    | SocketConnected
    | SocketDisconnected { code : Int, reason : String, wasClean : Bool }
    | ScheduledReconnect { time : Time }


type ChannelStatus
    = ChannelInitializing
    | Joining
    | Joined Json.Value
    | Rejoined Json.Value
    | JoinError Json.Value
    | Leaving
    | LeaveError Json.Value
    | Left Json.Value
    | Crashed
    | ChannelDisconnected


type alias Presence =
    Dict String (List Json.Value)


type ReplyStatus
    = ReplyOk
    | ReplyErr


{-| UI state.
-}
type alias State =
    { entries : List Entry
    , field : String
    , visibility : String
    }


type alias Model =
    { state : State
    , seed : Maybe Seed
    , currentTime : Time
    , socketStatus : SocketStatus
    , channelStatus : ChannelStatus
    , presence : Presence
    }


{-| Frontend version of a todo item.
-}
type alias Entry =
    { description : String
    , completed : Bool
    , editing : Bool
    , id : String
    }


{-| Backend version of a todo item.
-}
type alias BackendEntry =
    { id : String
    , title : String
    , order : Int
    , completed : Bool
    }


emptyState : State
emptyState =
    { entries = []
    , visibility = "All"
    , field = ""
    }


newEntry : String -> String -> Entry
newEntry desc id =
    { description = desc
    , completed = False
    , editing = False
    , id = id
    }


initModel : State -> Model
initModel state =
    { state = state
    , seed = Nothing
    , currentTime = 0
    , socketStatus = SocketInitializing
    , channelStatus = ChannelInitializing
    , presence = Dict.empty
    }


init : Maybe State -> ( Model, Cmd Msg )
init savedState =
    initModel (Maybe.withDefault emptyState savedState)
        ! []



-- UPDATE


{-| Users of our app can trigger messages by clicking and typing. These
messages are fed into the `update` function as they occur, letting us react
to them.
-}
type Msg
    = NoOp
    | UpdateField String
    | EditingEntry String Bool
    | UpdateEntry String String
    | Add
    | Delete String
    | DeleteComplete
    | Check String Bool
    | CheckAll Bool
    | ChangeVisibility String
    | Tick Time
    | SocketClosedAbnormally AbnormalClose
    | SocketStatusChanged SocketStatus
    | ChannelStatusChanged ChannelStatus
    | PresenceChanged Presence
    | CreateItemReply ReplyStatus Json.Value
    | UpdateBatchReply ReplyStatus Json.Value
    | DeleteBatchReply ReplyStatus Json.Value
    | ItemsCreated Json.Value
    | ItemsUpdated Json.Value
    | ItemsDeleted Json.Value



-- How we update our Model on a given Msg?


update : Msg -> Model -> ( Model, Cmd Msg )
update msg ({ state } as model) =
    case msg of
        NoOp ->
            model ! []

        UpdateField str ->
            let
                newState =
                    { state | field = str }
            in
                { model | state = newState }
                    ! []

        EditingEntry id isEditing ->
            let
                updateEntry t =
                    if t.id == id then
                        { t | editing = isEditing }
                    else
                        t

                focus =
                    Dom.focus ("todo-" ++ id)

                newState =
                    { state | entries = List.map updateEntry state.entries }
            in
                { model | state = newState }
                    ! [ Task.attempt (\_ -> NoOp) focus ]

        ChangeVisibility visibility ->
            let
                newState =
                    { state | visibility = visibility }
            in
                { model | state = newState }
                    ! []

        Add ->
            if String.isEmpty state.field then
                model ! []
            else
                let
                    ( newModel, uid ) =
                        makeUuid model

                    newTodo =
                        newEntry state.field (Uuid.toString uid)

                    newState =
                        { state
                            | field = ""
                            , entries = state.entries ++ [ newTodo ]
                        }
                in
                    { newModel | state = newState }
                        ! [ createItemMutation newTodo ]

        UpdateEntry id task ->
            let
                updateEntry t =
                    if t.id == id then
                        { t | description = task }
                    else
                        t

                newState =
                    { state | entries = List.map updateEntry state.entries }
            in
                { model | state = newState }
                    ! [ updateTitleMutation id task ]

        Check id isCompleted ->
            let
                updateEntry t =
                    if t.id == id then
                        { t | completed = isCompleted }
                    else
                        t

                newState =
                    { state | entries = List.map updateEntry state.entries }
            in
                { model | state = newState }
                    ! [ updateCompletedMutation [ id ] isCompleted ]

        CheckAll isCompleted ->
            let
                updateEntry t =
                    { t | completed = isCompleted }

                newState =
                    { state | entries = List.map updateEntry state.entries }
            in
                { model | state = newState }
                    ! [ updateCompletedMutation (List.map .id newState.entries) isCompleted ]

        Delete id ->
            let
                newState =
                    { state | entries = List.filter (\t -> t.id /= id) state.entries }
            in
                { model | state = newState }
                    ! [ deleteBatchMutation [ id ] ]

        DeleteComplete ->
            let
                ( completed, uncompleted ) =
                    List.partition .completed state.entries

                newState =
                    { state | entries = uncompleted }
            in
                { model | state = newState }
                    ! [ deleteBatchMutation (List.map .id completed) ]

        Tick time ->
            { model | currentTime = time }
                ! []

        SocketClosedAbnormally abnormalClose ->
            let
                _ =
                    Debug.log "SocketClosedAbnormally" abnormalClose
            in
                { model
                    | socketStatus =
                        ScheduledReconnect
                            { time = roundDownToSecond (model.currentTime + abnormalClose.reconnectWait)
                            }
                }
                    ! []

        SocketStatusChanged status ->
            { model | socketStatus = Debug.log "Socket" status }
                ! []

        ChannelStatusChanged state ->
            { model | channelStatus = Debug.log "Channel" state }
                ! []

        PresenceChanged state ->
            { model | presence = Debug.log "Presence" state }
                ! []

        CreateItemReply status reply ->
            let
                _ =
                    Debug.log "CreateItemReply" reply
            in
                model ! []

        UpdateBatchReply status reply ->
            let
                _ =
                    Debug.log "UpdateBatchReply" reply
            in
                model ! []

        DeleteBatchReply status reply ->
            let
                _ =
                    Debug.log "DeleteBatchReply" reply
            in
                model ! []

        ItemsCreated payload ->
            case Json.decodeValue todoUpdateDecoder (Debug.log "ItemsCreated" payload) of
                Ok entries ->
                    model ! []

                Err err ->
                    model ! []

        ItemsUpdated payload ->
            case Json.decodeValue todoUpdateDecoder (Debug.log "ItemsUpdated" payload) of
                Ok entries ->
                    model ! []

                Err err ->
                    model ! []

        ItemsDeleted payload ->
            case Json.decodeValue todoUpdateDecoder (Debug.log "ItemsDeleted" payload) of
                Ok entries ->
                    model ! []

                Err err ->
                    model ! []


makeUuid : Model -> ( Model, Uuid )
makeUuid model =
    let
        seed =
            case model.seed of
                Just s ->
                    s

                Nothing ->
                    model.currentTime |> truncate |> initialSeed

        ( newUuid, newSeed ) =
            Random.Pcg.step Uuid.uuidGenerator seed
    in
        ( { model | seed = Just newSeed }, newUuid )


roundDownToSecond : Time -> Time
roundDownToSecond ms =
    (ms / 1000) |> truncate |> (*) 1000 |> toFloat


todoUpdateDecoder : Json.Decoder (List BackendEntry)
todoUpdateDecoder =
    Pipeline.decode BackendEntry
        |> Pipeline.required "id" Json.string
        |> Pipeline.required "title" Json.string
        |> Pipeline.required "order" Json.int
        |> Pipeline.required "completed" Json.bool
        |> Json.list



-- SENDING GRAPHQL


{-| Append "/websocket" to the address defined in the Elixir
TodoAbsintheWeb.Endpoint module.
-}
socketAddress : String
socketAddress =
    "ws://localhost:4000/socket/websocket"


{-| This must match the topic for the Phoenix channel on the Elixir side.
We use the same topic for configuring and returning GraphQL subscription messages.
-}
channelTopic : String
channelTopic =
    "*"


{-| To send a GraphQL query or mutation, use the event "doc" on the topic "*".
The payload, as in GraphQL HTTP GET or POST has two components, "variables"
and "query".
-}
pushDoc : List ( String, Json.Value ) -> String -> (ReplyStatus -> Json.Value -> Msg) -> Cmd Msg
pushDoc vars query replyHandler =
    let
        payload =
            Encode.object
                [ ( "variables", Encode.object vars )
                , ( "query", Encode.string query )
                ]
    in
        Push.init channelTopic "doc"
            |> Push.withPayload payload
            |> Push.onOk (replyHandler ReplyOk)
            |> Push.onError (replyHandler ReplyErr)
            |> Phoenix.push socketAddress


createItemMutation : Entry -> Cmd Msg
createItemMutation { id, description, completed } =
    let
        input =
            Encode.object
                [ ( "id", Encode.string id )
                , ( "title", Encode.string description )
                , ( "completed", Encode.bool completed )
                ]

        query =
            "mutation CreateTodo($input:TodoInput!) {"
                ++ " createItem(input:$input) {"
                ++ " id title order completed insertedAt } }"
    in
        pushDoc [ ( "input", input ) ] query CreateItemReply


updateTitleMutation : String -> String -> Cmd Msg
updateTitleMutation id description =
    let
        encodeEntry =
            Encode.object
                [ ( "id", Encode.string id )
                , ( "title", Encode.string description )
                ]

        input =
            [ encodeEntry ]
                |> Encode.list

        query =
            "mutation UpdateTitle($input:TodoInput!) {"
                ++ " updateBatch(input:$input) {"
                ++ " id title order completed insertedAt } }"
    in
        pushDoc [ ( "input", input ) ] query UpdateBatchReply


updateCompletedMutation : List String -> Bool -> Cmd Msg
updateCompletedMutation idList completed =
    let
        encodeEntry id =
            Encode.object
                [ ( "id", Encode.string id )
                , ( "completed", Encode.bool completed )
                ]

        input =
            List.map encodeEntry idList
                |> Encode.list

        query =
            "mutation UpdateCompleted($input:[TodoInput]!) {"
                ++ " updateBatch(input:$input) {"
                ++ " id title order completed insertedAt } }"
    in
        pushDoc [ ( "input", input ) ] query UpdateBatchReply


deleteBatchMutation : List String -> Cmd Msg
deleteBatchMutation idList =
    let
        ids =
            List.map Encode.string idList
                |> Encode.list

        query =
            "mutation DeleteBatch($ids:[String]!) {"
                ++ " deleteBatch(ids:$ids) {"
                ++ " id title order completed insertedAt } }"
    in
        pushDoc [ ( "ids", ids ) ] query DeleteBatchReply



-- SUBSCRIPTIONS


absintheChannel : Channel Msg
absintheChannel =
    let
        presence =
            Presence.create
                |> Presence.onChange PresenceChanged
    in
        Channel.init channelTopic
            |> Channel.onRequestJoin (ChannelStatusChanged Joining)
            |> Channel.onJoin (ChannelStatusChanged << Joined)
            |> Channel.onRejoin (ChannelStatusChanged << Rejoined)
            |> Channel.onJoinError (ChannelStatusChanged << JoinError)
            |> Channel.onLeave (ChannelStatusChanged << Left)
            |> Channel.onLeaveError (ChannelStatusChanged << LeaveError)
            |> Channel.onError (ChannelStatusChanged Crashed)
            |> Channel.onDisconnect (ChannelStatusChanged ChannelDisconnected)
            |> Channel.withPresence presence
            |> Channel.on "itemsCreated" ItemsCreated
            |> Channel.on "itemsUpdated" ItemsUpdated
            |> Channel.on "itemsDeleted" ItemsDeleted
            |> Channel.withDebug


userSocket : Socket Msg
userSocket =
    Socket.init socketAddress
        |> Socket.onOpen (SocketStatusChanged SocketConnected)
        |> Socket.onClose (SocketStatusChanged << SocketDisconnected)
        |> Socket.onAbnormalClose SocketClosedAbnormally
        |> Socket.reconnectTimer (\backoffIteration -> (backoffIteration + 1) * 5000 |> toFloat)


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Time.every Time.second Tick
        , Phoenix.connect userSocket [ absintheChannel ]
        ]



-- VIEW


view : Model -> Html Msg
view { state } =
    div
        [ class "todomvc-wrapper"
        , style [ ( "visibility", "hidden" ) ]
        ]
        [ section
            [ class "todoapp" ]
            [ lazy viewInput state.field
            , lazy2 viewEntries state.visibility state.entries
            , lazy2 viewControls state.visibility state.entries
            ]
        , infoFooter
        ]


viewInput : String -> Html Msg
viewInput task =
    header
        [ class "header" ]
        [ h1 [] [ text "todos" ]
        , input
            [ class "new-todo"
            , placeholder "What needs to be done?"
            , autofocus True
            , value task
            , name "newTodo"
            , onInput UpdateField
            , onEnter Add
            ]
            []
        ]


onEnter : Msg -> Attribute Msg
onEnter msg =
    let
        isEnter code =
            if code == 13 then
                Json.succeed msg
            else
                Json.fail "not ENTER"
    in
        on "keydown" (Json.andThen isEnter keyCode)



-- VIEW ALL ENTRIES


viewEntries : String -> List Entry -> Html Msg
viewEntries visibility entries =
    let
        isVisible todo =
            case visibility of
                "Completed" ->
                    todo.completed

                "Active" ->
                    not todo.completed

                _ ->
                    True

        allCompleted =
            List.all .completed entries

        cssVisibility =
            if List.isEmpty entries then
                "hidden"
            else
                "visible"
    in
        section
            [ class "main"
            , style [ ( "visibility", cssVisibility ) ]
            ]
            [ input
                [ class "toggle-all"
                , type_ "checkbox"
                , name "toggle"
                , checked allCompleted
                , onClick (CheckAll (not allCompleted))
                ]
                []
            , label
                [ for "toggle-all" ]
                [ text "Mark all as complete" ]
            , Keyed.ul [ class "todo-list" ] <|
                List.map viewKeyedEntry (List.filter isVisible entries)
            ]



-- VIEW INDIVIDUAL ENTRIES


viewKeyedEntry : Entry -> ( String, Html Msg )
viewKeyedEntry todo =
    ( todo.id, lazy viewEntry todo )


viewEntry : Entry -> Html Msg
viewEntry todo =
    li
        [ classList [ ( "completed", todo.completed ), ( "editing", todo.editing ) ] ]
        [ div
            [ class "view" ]
            [ input
                [ class "toggle"
                , type_ "checkbox"
                , checked todo.completed
                , onClick (Check todo.id (not todo.completed))
                ]
                []
            , label
                [ onDoubleClick (EditingEntry todo.id True) ]
                [ text todo.description ]
            , button
                [ class "destroy"
                , onClick (Delete todo.id)
                ]
                []
            ]
        , input
            [ class "edit"
            , value todo.description
            , name "title"
            , id ("todo-" ++ todo.id)
            , onInput (UpdateEntry todo.id)
            , onBlur (EditingEntry todo.id False)
            , onEnter (EditingEntry todo.id False)
            ]
            []
        ]



-- VIEW CONTROLS AND FOOTER


viewControls : String -> List Entry -> Html Msg
viewControls visibility entries =
    let
        entriesCompleted =
            List.length (List.filter .completed entries)

        entriesLeft =
            List.length entries - entriesCompleted
    in
        footer
            [ class "footer"
            , hidden (List.isEmpty entries)
            ]
            [ lazy viewControlsCount entriesLeft
            , lazy viewControlsFilters visibility
            , lazy viewControlsClear entriesCompleted
            ]


viewControlsCount : Int -> Html Msg
viewControlsCount entriesLeft =
    let
        item_ =
            if entriesLeft == 1 then
                " item"
            else
                " items"
    in
        span
            [ class "todo-count" ]
            [ strong [] [ text (toString entriesLeft) ]
            , text (item_ ++ " left")
            ]


viewControlsFilters : String -> Html Msg
viewControlsFilters visibility =
    ul
        [ class "filters" ]
        [ visibilitySwap "#/" "All" visibility
        , text " "
        , visibilitySwap "#/active" "Active" visibility
        , text " "
        , visibilitySwap "#/completed" "Completed" visibility
        ]


visibilitySwap : String -> String -> String -> Html Msg
visibilitySwap uri visibility actualVisibility =
    li
        [ onClick (ChangeVisibility visibility) ]
        [ a [ href uri, classList [ ( "selected", visibility == actualVisibility ) ] ]
            [ text visibility ]
        ]


viewControlsClear : Int -> Html Msg
viewControlsClear entriesCompleted =
    button
        [ class "clear-completed"
        , hidden (entriesCompleted == 0)
        , onClick DeleteComplete
        ]
        [ text ("Clear completed (" ++ toString entriesCompleted ++ ")")
        ]


infoFooter : Html msg
infoFooter =
    footer [ class "info" ]
        [ p [] [ text "Double-click to edit a todo" ]
        , p []
            [ text "Written by "
            , a [ href "https://github.com/evancz" ] [ text "Evan Czaplicki" ]
            ]
        , p []
            [ text "Part of "
            , a [ href "http://todomvc.com" ] [ text "TodoMVC" ]
            ]
        ]
