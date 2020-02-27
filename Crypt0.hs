module Crypt0 where

import Data.Map 

-- State of program is the value of all of the variables
-- Semantic domain = State -> State = (Map Name Var) -> (Map Name Var)

-- TODO (Feb 27th)
--    - CMDs: Call, While/For
--    - Features: Start on static typing, 

-- TYPE DECLARATIONS

type State = Map Name Var
type Prog  = [Cmd]
type Name  = String

data Cmd = Declare Name Var
         | Add Name Name Name
         | Sub Name Name Name
         | Mul Name Name Name
         | Div Name Name Name
         | If Name Cmd Cmd
         | Call Name [Name]
         | Return Name 
      --  TODO: More cmds
    deriving (Eq,Show)

-- Var = Name + Value
data Var = Int Int
         | Double Double
         | Bool Bool
         | String String
         | Function Type [(Type, Name)] Prog
    deriving (Eq,Show)

data Op = Plus | Minus | Mult | Divi
    deriving (Eq,Show)

-- Int | Double | Bool | String | Function
data Type = Int_ty | Dbl_ty | Bul_ty | Str_ty | Fun_ty
    deriving (Eq,Show)

-- TODO: Function = String (name of function) -> [String OR Var] (variables) -> Prog (code) -> State -> State
-- Based on other parts of the code, it seems like we only want to pass by reference. Function scope may be hard

-- Stretch goal: classes

--
-- SEMANTICS
--

run :: Prog -> State -> State
run (c:cs) s = run cs (cmd c s)
run [] s = s 

cmd :: Cmd -> State -> State
cmd c s = case c of
    -- Variable declaration
    Declare ref v -> set ref v s
    -- Addition
    Add r v1 v2   -> 
      case typeOf v1 s of
        Int_ty    -> set r (Int (performOpInt Plus (valInt v1 s) (valInt v2 s) )) s
        Dbl_ty    -> set r (Double (performOpDbl Plus (valDbl v1 s) (valDbl v2 s))) s
        Str_ty    -> set r (String (performOpStr Plus (valStr v1 s) (valStr v2 s))) s
        otherwise -> error ("Invalid variable type passed to 'Add': " ++ show (typeOf v1 s))
    -- Subtraction
    Sub r v1 v2   ->
      case typeOf v1 s of
        Int_ty    -> set r (Int (performOpInt Minus (valInt v1 s) (valInt v2 s))) s
        Dbl_ty     -> set r (Double (performOpDbl Minus (valDbl v1 s) (valDbl v2 s))) s
        -- TODO: "Str"     -> set r (String (performOpStr (valStr v1 s) (valStr v2 s) Minus)) s
        otherwise -> error ("Invalid variable type passed to 'Sub': " ++ show (typeOf v1 s)) 
    -- Multiplication
    Mul r v1 v2   ->
      case typeOf v1 s of
        Int_ty    -> set r (Int (performOpInt Mult (valInt v1 s) (valInt v2 s))) s
        Dbl_ty     -> set r (Double (performOpDbl Mult (valDbl v1 s) (valDbl v2 s))) s
        otherwise -> error ("Invalid variable type passed to 'Add': " ++ show (typeOf v1 s))    
    -- Division
    Div r v1 v2   ->
      case typeOf v1 s of
        Int_ty     -> set r (Int (performOpInt Divi (valInt v1 s) (valInt v2 s))) s
        Dbl_ty     -> set r (Double (performOpDbl Divi (valDbl v1 s) (valDbl v2 s))) s
        otherwise -> error ("Invalid variable type passed to 'Add': " ++ show (typeOf v1 s))    
    -- If statement
    If b c1 c2    -> 
        if (valBool b s)
        then cmd c1 s
        else cmd c2 s
    -- Other commands

expr :: Expr -> State -> Var

--
-- MATH OPERATIONS
--

performOpInt :: Op -> Int -> Int -> Int
performOpInt o x y = 
    case o of
      Plus  -> x + y
      Minus -> x - y
      Mult  -> x * y
      Divi  -> x `div` y

valInt :: Name -> State -> Int
valInt v s = 
    case get v s of
      Int x -> x

performOpDbl :: Op -> Double -> Double -> Double
performOpDbl o x y = 
    case o of
      Plus  -> x + y
      Minus -> x - y
      Mult  -> x * y
      Divi  -> x / y

valDbl :: Name -> State -> Double
valDbl v s = 
    case get v s of
      Double x -> x

performOpStr :: Op -> String -> String -> String
performOpStr o x y = 
    case o of
      Plus  -> x ++ y
      --TODO: Minus -> x - y

valStr :: Name -> State -> String
valStr v s = 
    case get v s of
      String x -> x

valBool :: Name -> State -> Bool
valBool v s = 
    case get v s of
      Bool x -> x

--
-- VARIABLE MANIPULATION
--

get :: Name -> State -> Var 
get key s = s ! key
-- TODO: Variable does not exist case

-- Changes the value of a variable on the stack
-- Have to think about what restrictions we want on variable manipulation - do we want variables to-
   -- be autodeclared like python if they don't already exist? Or more C-like strict typing?
set :: Name -> Var -> State -> State
set key v s = (insert key v s)

-- Returns type of a variable
typeOf :: Name -> State -> Type
typeOf key s = case get key s of 
    (Int _)    -> Int_ty
    (Double _) -> Dbl_ty
    (Bool _)   -> Bul_ty
    (String _) -> Str_ty

-- Removes a variable from scope
removeVar :: Name -> State -> State
removeVar key s = delete key s

-- TESTING

-- | Add together two vars
--
-- >>> prog = [Declare "num1" (Int 5), Declare "num2" (Int 15), Add "sum" "num1" "num2"]
-- >>> s1 = run prog s0 
-- >>> get "sum" s1
-- Int 20
--
-- >>> prog = [Declare "num1" (Double 8.20), Declare "num2" (Double 3.60), Add "sum" "num1" "num2"]
-- >>> s1 = run prog s0
-- >>> get "sum" s1
-- Double 11.799999999999999
--
-- NOTE: We deal with the same inherent issues with floating point arithmetic as languages like Python
--
-- >>> prog = [Declare "str1" (String "asd"), Declare "str2" (String "123"), Add "str3" "str1" "str2"]
-- >>> s1 = run prog s0
-- >>> get "str3" s1
-- String "asd123"
--
-- | Subtract two vars
--
-- >>> prog = [Declare "num1" (Int 5), Declare "num2" (Int 15), Sub "sum" "num1" "num2"]
-- >>> s1 = run prog s0 
-- >>> get "sum" s1
-- Int (-10)
--
-- >>> prog = [Declare "num1" (Double 8.20), Declare "num2" (Double 3.60), Sub "sum" "num1" "num2"]
-- >>> s1 = run prog s0
-- >>> get "sum" s1
-- Double 4.6
--
-- | Multiplies two vars
--
-- >>> prog = [Declare "num1" (Int 2), Declare "num2" (Int 15), Mul "sum" "num1" "num2"]
-- >>> s1 = run prog s0 
-- >>> get "sum" s1
-- Int 30
--
-- >>> prog = [Declare "num1" (Double 8.20), Declare "num2" (Double 2.0), Mul "sum" "num1" "num2"]
-- >>> s1 = run prog s0
-- >>> get "sum" s1
-- Double 16.4
--
-- | Divide two vars
--
-- >>> prog = [Declare "num1" (Int 30), Declare "num2" (Int 15), Div "sum" "num1" "num2"]
-- >>> s1 = run prog s0 
-- >>> get "sum" s1
-- Int 2
--
-- >>> prog = [Declare "num1" (Double 8.20), Declare "num2" (Double 2.0), Div "sum" "num1" "num2"]
-- >>> s1 = run prog s0
-- >>> get "sum" s1
-- Double 4.1
--
-- | If statement
--
-- >>> prog1 = [Declare "bool1" (Bool True), If "bool1" (Declare "true" (Int 1)) (Declare "false" (Int 0))]
-- >>> s1 = run prog1 s0
-- >>> get "true" s1
-- Int 1
--
-- >>> prog1 = [Declare "bool1" (Bool False), If "bool1" (Declare "true" (Int 1)) (Declare "false" (Int 0))]
-- >>> s1 = run prog1 s0
-- >>> get "false" s1
-- Int 0
--

s0 :: State
s0 = empty

--
-- FUNCTIONS
--

-- Function [(Type, Name)] Prog
-- data Op = Plus | Minus | Mult | Divi

--call :: Var -> State -> Var
--call t  s = case t of
--    Int_ty -> undefined
--    Dbl_ty -> undefined
--    Bul_ty -> undefined
--   Str_ty -> undefined
--    Fun_ty -> undefined

-- Int | Double | Bool | String | Function
-- data Type = Int_ty | Dbl_ty | Bul_ty | Str_ty | Fun_ty

--run prog s0
prog = [Declare "num1" (Double 8.2), Declare "num2" (Double 3.3), Add "sum" "num1" "num2"]
prog1 = [Declare "bool1" (Bool True), If "bool1" (Declare "true" (Int 1)) (Declare "false" (Int 0))]
prog2 = [Declare "f" (Function Int_ty [(Int_ty, "num1"), (Int_ty, "num2")] [Add "sum" "num1" "num2"])]
