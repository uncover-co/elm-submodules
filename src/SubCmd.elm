module SubCmd exposing
    ( SubCmd, none, cmd, effect, batch
    , mapCmd, mapEffect, mapBoth
    )

{-| When setting up a submodule, you should use `SubCmd.cmd` when you want the submodule itself to handle the messages. However, if you want the message to be "sent" to the host, just use `SubCmd.effect`.

    type alias Model =
        { value : String }

    type Msg
        = FetchFromServer
        | GotFromServer String
        | Submit

    type Effect
        = SendValue String

    update : Msg -> Model -> ( Model, SubCmd Msg Effect )
    update msg model =
        case msg of
            FetchFromServer ->
                ( model
                , SubCmd.cmd (fetchFromServer GotFromServer)
                )

            GotFromServer value ->
                ( { value = value }, SubCmd.none )

            Submit ->
                ( model, SubCmd.effect (SendValue model.value) )


## Functions

@docs SubCmd, none, cmd, effect, batch


## Transformations

@docs mapCmd, mapEffect, mapBoth

-}

import SubModule.SubCmd as S


{-| -}
type alias SubCmd msg effect =
    S.SubCmd msg effect


{-| -}
none : SubCmd msg effect
none =
    S.Internal Cmd.none


{-| -}
cmd : Cmd msg -> SubCmd msg effect
cmd =
    S.Internal


{-| -}
effect : effect -> SubCmd msg effect
effect =
    S.External


{-| With batch you can actually send `cmd`'s and `effect`'s at the same time!

    Submit ->
        ( model, SubCmd.batch
            [ SubCmd.effect (SendValue model.value)
            , SubCmd.cmd (fetchFromServer GotFromServer)
            ]
        )

-}
batch : List (SubCmd msg effect) -> SubCmd msg effect
batch =
    S.Batch


{-| Maps a `cmd` just like you would with `Cmd.map`.
-}
mapCmd : (msgA -> msgB) -> SubCmd msgA effect -> SubCmd msgB effect
mapCmd fn =
    mapBoth fn identity


{-| Maps an `effect` just like you would with `Cmd.map`.
-}
mapEffect : (effectA -> effectB) -> SubCmd msg effectA -> SubCmd msg effectB
mapEffect fn =
    mapBoth identity fn


{-| Maps both `cmd`'s and `effect`'s at the same time.
-}
mapBoth : (msgA -> msgB) -> (effectA -> effectB) -> SubCmd msgA effectA -> SubCmd msgB effectB
mapBoth cmdMap effectMap subCmd =
    case subCmd of
        S.Internal cmd_ ->
            S.Internal (Cmd.map cmdMap cmd_)

        S.External effect_ ->
            S.External (effectMap effect_)

        S.Batch subCmds ->
            subCmds
                |> List.map (mapBoth cmdMap effectMap)
                |> S.Batch
