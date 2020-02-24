module Crypt0 where

import Data.Map 

-- State of program is the value of all of the variables
-- Semantic domain = State -> State

-- TODO (Feb 27th)
--    - CMDs: Sub, Call, If, While/For
--    - VARs: Int, Bool, String, (Maybe float)
--    - Features: Start on static typing, 

type State = Map Name Var
type Prog  = [Cmd]
type Name  = String

data Cmd = Declare Name Var
         | Add Name Name Name
      -- | Sub Name Name
      -- | Call Function [Var] OR Call Function [Name] (value or reference?)
      -- | TODO: More cmds
    deriving (Eq,Show)

-- Var = Name + Value
data Var = Int Int
         | Bool Bool
      -- | String String
      -- | TODO: More types
    deriving (Eq,Show)

-- TODO: Function = String (name of function) -> [String OR Var] (variables) -> Prog (code) -> State -> State
-- Based on other parts of the code, it seems like we only want to pass by reference. Function scope may be hard

-- Stretch goal: classes

run :: Prog -> State -> State
run (c:cs) s = run cs (cmd c s)
run [] s = s 

cmd :: Cmd -> State -> State
cmd c s = case c of
    Declare ref v  -> set ref v s
    Add r v1 v2 -> add r v1 v2 s
    -- Other commands

-- Goes through stack and gets specific variable's value by reference
get :: Name -> State -> Var 
get key s = s ! key
-- TODO: Variable does not exist case

-- Changes the value of a variable on the stack
-- Have to think about what restrictions we want on variable manipulation - do we want variables to-
   -- be autodeclared like python if they don't already exist? Or more C-like strict typing?
set :: Name -> Var -> State -> State
set key v s = (insert key v s)

-- Removes a variable from scope
removeVar :: Name -> State -> State
removeVar key s = delete key s

-- Adds together two variables
-- TODO: Type checking
add :: Name -> Name -> Name -> State -> State
add result a1 a2 s = set result (Int (x + y)) s
    where
      x = case get a1 s of
        Int v -> v
        ----
      y = case get a2 s of
        Int v -> v
        ----

-- Testing 
-- TODO: Doctests
s0 :: State
s0 = empty

--run prog s0
prog = [Declare "num1" (Int 1), Declare "num2" (Int 3), Add "sum" "num1" "num2"]
