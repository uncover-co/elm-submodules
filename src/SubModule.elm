module SubModule exposing (init, initWithEffect, update, updateWithEffect)

{-| This module is used for plugging submodules into a host module. If you're working on the submodule itself, check out `SubCmd`.

@docs init, initWithEffect, update, updateWithEffect

-}

import SubModule.SubCmd exposing (SubCmd(..))
import Task



-- Init


{-| Enables you to initialize multiple submodules that **cannot send effects**.

    let
        ( subModule, initSubModule ) =
            SubModule.init
                |> SubModule.init SubModuleMsg

        ( subModule2, initSubModule2 ) =
            SubModule2.init
                |> SubModule.init
                    { toMsg = SubModule2Msg
                    }
    in
    ( { subModule = subModule, subModule2 = subModule2 }, Cmd.none )
        |> initSubModule
        |> initSubModule2

**This only exists so you can use a similar strategy across modules that do and don't send effects.** If you're only working with modules that don't you could just use this strategy:

    let
        ( subModule, subModuleCmd ) =
            SubModule.init
                |> Tuple.mapSecond (Cmd.map SubModuleMsg)

        ( subModule2, subModule2Cmd ) =
            SubModule2.init
                |> Tuple.mapSecond (Cmd.map SubModule2Msg)
    in
    ( { subModule = subModule, subModule2 = subModule2 }
    , Cmd.batch [ subModuleCmd, subModule2Cmd ]
    )

-}
init :
    { toMsg : subMsg -> msg }
    -> ( subModel, Cmd subMsg )
    -> ( subModel, ( model, Cmd msg ) -> ( model, Cmd msg ) )
init config ( subModel, subCmd ) =
    ( subModel
    , Tuple.mapSecond
        (\cmd_ ->
            Cmd.batch
                [ cmd_
                , Cmd.map config.toMsg subCmd
                ]
        )
    )


{-| Enables you to initialize submodules that **can send effects**.

    let
        -- This submodule can't send effects
        ( subModule, initSubModule ) =
            SubModule.init
                |> SubModule.init
                    { toMsg = GotSubMsg
                    }

        -- But this one can!
        ( subModule2, initSubModule2 ) =
            SubModule2.init
                |> SubModule.initWithEffect
                    { toMsg = GotSubMsg2
                    , effectToMsg = GotSubEffect2
                    }
    in
    ( { subModule = subModule
      , subModule2 = subModule2
      }
    , Cmd.none
    )
        |> initSubModule
        |> initSubModule2

-}
initWithEffect :
    { toMsg : subMsg -> msg
    , effectToMsg : subEffect -> msg
    }
    -> ( subModel, SubCmd subMsg subEffect )
    -> ( subModel, ( model, Cmd msg ) -> ( model, Cmd msg ) )
initWithEffect config ( subModel, subCmd ) =
    ( subModel
    , Tuple.mapSecond
        (\cmd_ ->
            Cmd.batch
                [ cmd_
                , subCmdToMsg
                    config.toMsg
                    config.effectToMsg
                    subCmd
                ]
        )
    )



-- Update


{-| Enables you to handle the updates of submodules that **cannot send effects**.

    type Msg
        = GotSubMsg SubWidget.Msg
        | ...

    update : Msg -> Model -> ( Model, Cmd Msg )
    update msg model =
        case msg of
            GotSubMsg subMsg ->
                SubModule.update subMsg model.subModule
                    |> SubModule.update
                        { toMsg = GotSubMsg
                        , toModel = \subModule -> { model | subModule = subModule }
                        }
            ...

**This only exists so you can use a similar strategy across modules that do and don't send effects.** If you're only working with modules that don't you could just use this strategy:

    update : Msg -> Model -> ( Model, Cmd Msg )
    update msg model =
        case msg of
            GotSubMsg subMsg ->
                SubModule.update subMsg model.subModule
                    |> SubModule.update
                        |> Tuple.mapFirst \subModule -> { model | subModule = subModule }
                        |> Tuple.mapSecond (Cmd.map GotSubMsg)
            ...

-}
update :
    { toModel : subModel -> model
    , toMsg : subMsg -> msg
    }
    -> ( subModel, Cmd subMsg )
    -> ( model, Cmd msg )
update config ( subModel, subCmd ) =
    ( config.toModel subModel
    , Cmd.map config.toMsg subCmd
    )


{-| Enables you to handle the updates of submodules that **can send effects**.

    type Msg
        = GotSubMsg SubWidget.Msg
        | GotSubEffect SubWidget.Effect

    update : Msg -> Model -> ( Model, Cmd Msg )
    update msg model =
        case msg of
            GotSubMsg subMsg ->
                SubWidget.update subMsg model.subModel
                    |> SubWidget.updateWithEffect
                        { toMsg = GotSubMsg
                        , effectToMsg = GotSubEffect
                        , toModel =
                            \subModel -> { model | subModel = subModel }
                        }

            GotSubEffect subEffect ->
                case subEffect of
                    SubWidget.SendValue value ->
                        ( { model | subValue = Just value }
                        , Cmd.none
                        )

-}
updateWithEffect :
    { toModel : subModel -> model
    , toMsg : subMsg -> msg
    , effectToMsg : subEffect -> msg
    }
    -> ( subModel, SubCmd subMsg subEffect )
    -> ( model, Cmd msg )
updateWithEffect config ( subModel, subCmd ) =
    ( config.toModel subModel
    , subCmdToMsg config.toMsg config.effectToMsg subCmd
    )



-- Helpers


subCmdToMsg : (subMsg -> msg) -> (subEffect -> msg) -> SubCmd subMsg subEffect -> Cmd msg
subCmdToMsg toMsg effectToMsg subCmd =
    case subCmd of
        External subEffect ->
            Task.succeed (effectToMsg subEffect)
                |> Task.perform identity

        Internal subCmd_ ->
            Cmd.map toMsg subCmd_

        Batch subCmds ->
            subCmds
                |> List.foldl
                    (\subCmd_ acc ->
                        subCmdToMsg toMsg effectToMsg subCmd_ :: acc
                    )
                    []
                |> Cmd.batch
