# Elm-Submodules

Elm is _not_ a "component based" framework and this is not a problem. There are different strategies for reusing parts of your application and these start out as being way simpler than what you would usually expect from "components".

That being said, sometimes you do need something more "stateful" but you shouldn't need to lose the simplicity of Elm when that time comes. This module aims to help you to do just that.

## Creating a Submodule

Let's call those nested "stateful" components "submodules" from now on. When you're working with a submodule you need to define one extra type alongside your usual `Model` and `Msg`.

```elm
type alias Model
    = { value : String }

type Msg
    = UpdateValue String
    | Submit

type Effect
    = SendValue String
```

As you can guess, the `Effect` type serves as a way to "send" a "msg" to the host of your submodule. What is great about it is that this make it a hard requirement for the host module to handle that msg (and, as you will see, there is absolutely no pain in setting it up on the host as well).

To use the `Effect` you would create a slightly different `update` function:

```elm
update : Msg -> Model -> ( Model, SubCmd Msg Effect )
update msg model =
    case msg of
        UpdateValue value ->
            ( { value = value }, SubCmd.none )

        Submit ->
            ( model, SubCmd.effect (SendValue model.value) )
```

Done! Your submodule uses the `SubCmd` module to send both `cmd`'s and `effect`'s and it Just Works®.

## Plugging it into a "host" module

Well, how would I actually plug this submodule into my application?

Imagine you have a submodule called `Widget`. Using it would be as simple as doing this in the host module:

```elm
import Widget


type alias Model =
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
                    , toModel = \widget -> { model | widget = widget }
                    }

        GotWidgetEffect widgetEffect ->
            case widgetEffect of
                Widget.SendValue value ->
                    ( { model | valueFromWidget = Just value }
                    , Cmd.none
                    )


view : Html Msg
view =
    div []
        [ Widget.view
            |> Html.map GotWidgetMsg
        ]
```

Note that your submodule could also send effects on their `init`. In fact, they could send effects _only_ on their init or update and that would be ok!

## Documentation

- Checkout [SubCmd](https://package.elm-lang.org/packages/uncover-co/elm-submodules/latest/SubCmd) if you're creating a submodule.
- Checkout [SubModule](https://package.elm-lang.org/packages/uncover-co/elm-submodules/latest/SubModule) if you're plugging a submodule into a host module.
