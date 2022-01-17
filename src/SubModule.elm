module SubModule exposing
    ( initWithEffect, updateWithEffect
    , init, update
    )

{-| This module is used for plugging submodules into a host module. If you're working on the submodule itself, check out `SubCmd`.

@docs initWithEffect, updateWithEffect


## Modules without effect

We also provide a few functions to help you deal with modules that can't send effects so you have a similar API across your host module. Note that the same could be achieved without this package at all.

@docs init, update

-}

import SubModule.SubCmd exposing (SubCmd(..))
import Task



-- Init


{-| Enables you to initialize multiple submodules that **cannot send effects**.

    let
        ( widget, initWidget ) =
            Widget.init
                |> SubModule.init
                    { toMsg = GotWidgetMsg
                    }

        ( otherWidget, initOtherWidget ) =
            OtherWidget.init
                |> SubModule.init
                    { toMsg = GotOtherWidgetMsg
                    }
    in
    ( { widget = widget, otherWidget = otherWidget }, Cmd.none )
        |> initWidget
        |> initOtherWidget

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
        ( widget, initWidget ) =
            Widget.init
                |> SubModule.init
                    { toMsg = GotWidgetMsg
                    }

        -- But this one can!
        ( superWidget, initSuperWidget ) =
            SuperWidget.init
                |> SubModule.initWithEffect
                    { toMsg = GotSuperWidgetMsg
                    , effectToMsg = GotSuperWidgetEffect
                    }
    in
    ( { widget = widget
      , superWidget = superWidget
      }
    , Cmd.none
    )
        |> initWidget
        |> initSuperWidget

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
        = GotWidgetMsg Widget.Msg
        | ...

    update : Msg -> Model -> ( Model, Cmd Msg )
    update msg model =
        case msg of
            GotWidgetMsg widgetMsg ->
                Widget.update widgetMsg model.widget
                    |> SubModule.update
                        { toMsg = GotWidgetMsg
                        , toModel = \widget -> { model | widget = widget }
                        }
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

    type Model =
        { widget : Widget.Model
        , valueFromWidget : Maybe String
        }

    type Msg
        = GotWidgetMsg Widget.Msg
        | GotWidgetEffect Widget.Effect

    update : Msg -> Model -> ( Model, Cmd Msg )
    update msg model =
        case msg of
            GotWidgetMsg widgetMsg ->
                Widget.update widgetMsg model.widget
                    |> SubModule.updateWithEffect
                        { toMsg = GotWidgetMsg
                        , effectToMsg = GotWidgetEffect
                        , toModel =
                            \widget -> { model | widget = widget }
                        }

            GotWidgetEffect widgetEffect ->
                case widgetEffect of
                    Widget.SendValue value ->
                        ( { model | valueFromWidget = Just value }
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
