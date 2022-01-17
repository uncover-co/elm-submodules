module SubModule.SubCmd exposing (SubCmd(..))


type SubCmd msg effect
    = External effect
    | Internal (Cmd msg)
    | Batch (List (SubCmd msg effect))
