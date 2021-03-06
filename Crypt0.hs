module Crypt0 where

import Data.Map 
import Data.List(isPrefixOf)

-- =============================================================================
--                              ABSTRACT SYNTAX
-- =============================================================================

-- State of program is the value of all of the variables
-- Semantic domain = State -> State = (Map Name Var) -> (Map Name Var)

type State  = Map Name Var
type Prog   = [Smt]
type Name   = String

-- Commands change the program's state
data Smt = Declare Name Expr
         | If Expr Prog Prog
         | While Expr Prog
         | Return Expr
    deriving (Eq,Show)

-- Expressions perform operations and return variables
data Expr = BinOp Op Expr Expr
          | Lit Var
          | Get Name
          | Lt Expr Expr 
          | Gt Expr Expr 
          | Eq Expr Expr
          | Call Name [Expr]
    deriving (Eq,Show)

data Var = Int Int
         | Dbl Double
         | Bul Bool
         | Str String
         | Fun Type [(Type, Name)] Prog
    deriving (Eq,Show)

-- The arithmetic operators that we support
data Op = Add | Sub | Mul | Div
    deriving (Eq,Show)

--            Int  | Double |  Bool  | String | Function
data Type = Int_ty | Dbl_ty | Bul_ty | Str_ty | Fun_ty
    deriving (Eq,Show)

-- =============================================================================
--                                  SEMANTICS
-- =============================================================================

-- Type checks a program and then passes it to the driver if it is valid
run :: Prog -> State -> (Either String State)
run p s = case (typeCheck p empty) of
    (Just s)  -> Left s
    (Nothing) -> Right (driver p s)

-- Actually handles the running of a program
driver :: Prog -> State -> State
driver (c:cs) s = driver cs (smt c s)
driver [] s = s 

-- Modifies state according to commands
smt :: Smt -> State -> State
smt command s = case command of
    -- Variable declaration
    Declare ref e -> set ref (expr e s) s
    -- If statement
    If e c1 c2    -> case expr e s of
        (Bul b)       -> if b then driver c1 s else driver c2 s
    -- While loop 
    While e c     -> while e c s
    -- Return (unexpected)
    Return e      -> error "Unexpected return statement"

-- Performs operations and returns variables
expr :: Expr -> State -> Var
expr e s = case e of
    -- Addition
    BinOp o e1 e2 -> case (expr e1 s, expr e2 s) of
        (v1, v2) -> binOp o v1 v2
    -- Less than check
    Lt e1 e2  -> case (expr e1 s, expr e2 s) of
        (Int v1, Int v2) -> Bul (v1 < v2)
        (Dbl v1, Dbl v2) -> Bul (v1 < v2)
    -- Greater than check
    Gt e1 e2  -> case (expr e1 s, expr e2 s) of
        (Int v1, Int v2) -> Bul (v1 > v2)
        (Dbl v1, Dbl v2) -> Bul (v1 > v2)
    -- Equality check
    Eq e1 e2  -> case (expr e1 s, expr e2 s) of
        (Int v1, Int v2) -> Bul (v1 == v2)
        (Dbl v1, Dbl v2) -> Bul (v1 == v2)
        (Bul v1, Bul v2) -> Bul (v1 == v2)
        (Str v1, Str v2) -> Bul (v1 == v2)
    -- Call function
    Call ref es -> call ref es s
    -- Lit
    Lit v   -> v
    -- Get existing variable
    Get ref   -> get ref s

-- =============================================================================
--                                TYPE CHECKING
-- =============================================================================

-- Static type checking for each smt, returns a string if there is an error
typeCheck :: Prog -> (Map Name Type) -> Maybe String
typeCheck [] s = Nothing
typeCheck (c:cs) s = case c of
    -- Variable Declaration
    (Declare ref e) -> case typeExpr e s of
        (Just Fun_ty)   -> case typeFunc e of
            (Just ty)       -> typeCheck cs (insert ref ty s)
            Nothing         -> Just ("TError in Function Declaration: "++show e)
        (Just ty)    -> typeCheck cs (insert ref ty s)
        Nothing     -> tError e
    -- If statement
    (If e p1 p2)    -> if ((typeExpr e s) == (Just Bul_ty)) then
            case (typeCheck p1 s, typeCheck p2 s) of
                (Nothing, Nothing) -> typeCheck cs s
                (Just s, Nothing)  -> Just s
                (Nothing, Just s)  -> Just s
                (Just s1, Just s2) -> Just (s1 ++ ", " ++ s2)
        else tError e
    -- While loop
    (While e p)     -> if ((typeExpr e s) == (Just Bul_ty))
        then case (typeCheck p s) of
            Nothing  -> typeCheck cs s
            (Just s) -> Just s
        else tError e
    -- Return statement
    (Return e)      -> case typeExpr e s of
        Nothing         -> tError e
        otherwise       -> typeCheck cs s

-- Finds the eventual type of an expression
-- Returns Nothing if there is a type error
typeExpr :: Expr -> (Map Name Type) -> Maybe Type
typeExpr (Lit v) s           = Just (typeOf v)
typeExpr (Get ref) s         = Data.Map.lookup ref s
typeExpr (Lt e1 e2) s        = case (typeExpr e1 s, typeExpr e2 s) of
    (Just Int_ty, Just Int_ty) -> Just Bul_ty
    (Just Dbl_ty, Just Dbl_ty) -> Just Bul_ty
    otherwise                  -> Nothing
typeExpr (Gt e1 e2) s        = case (typeExpr e1 s, typeExpr e2 s) of
    (Just Int_ty, Just Int_ty) -> Just Bul_ty
    (Just Dbl_ty, Just Dbl_ty) -> Just Bul_ty
    otherwise                  -> Nothing
typeExpr (Eq e1 e2) s        = case (typeExpr e1 s, typeExpr e2 s) of
    (Just Int_ty, Just Int_ty) -> Just Bul_ty
    (Just Dbl_ty, Just Dbl_ty) -> Just Bul_ty
    (Just Str_ty, Just Str_ty) -> Just Bul_ty
    (Just Bul_ty, Just Bul_ty) -> Just Bul_ty
    otherwise                  -> Nothing
typeExpr (BinOp Add e1 e2) s = case (typeExpr e1 s, typeExpr e2 s) of
    (Just Int_ty, Just Int_ty) -> Just Int_ty
    (Just Dbl_ty, Just Dbl_ty) -> Just Dbl_ty
    (Just Int_ty, Just Dbl_ty) -> Just Dbl_ty
    (Just Dbl_ty, Just Int_ty) -> Just Dbl_ty
    (Just Str_ty, Just Str_ty) -> Just Str_ty
    otherwise                  -> Nothing
typeExpr (BinOp Sub e1 e2) s = case (typeExpr e1 s, typeExpr e2 s) of
    (Just Int_ty, Just Int_ty) -> Just Int_ty
    (Just Dbl_ty, Just Dbl_ty) -> Just Dbl_ty
    (Just Str_ty, Just Str_ty) -> Just Str_ty
    (Just Int_ty, Just Dbl_ty) -> Just Dbl_ty
    (Just Dbl_ty, Just Int_ty) -> Just Dbl_ty
    otherwise                  -> Nothing
typeExpr (BinOp Mul e1 e2) s = case (typeExpr e1 s, typeExpr e2 s) of
    (Just Int_ty, Just Int_ty) -> Just Int_ty
    (Just Dbl_ty, Just Dbl_ty) -> Just Dbl_ty
    otherwise                  -> Nothing
typeExpr (BinOp Div e1 e2) s = case (typeExpr e1 s, typeExpr e2 s) of
    (Just Int_ty, Just Int_ty) -> Just Int_ty
    (Just Dbl_ty, Just Dbl_ty) -> Just Dbl_ty
    otherwise                  -> Nothing
typeExpr (Call ref es) s     = Data.Map.lookup ref s

-- Checks that a function returns the correct type and that its body is valid
typeFunc :: Expr -> Maybe Type
typeFunc (Lit (Fun reTy prms p)) = 
    if typeCheck p s' == Nothing
    && Just reTy == checkReturnType p s'
    then Just reTy
    else Nothing
        where s' = typeParams prms empty

-- Helper function that loads the types of each function param into a map
-- This allows type checking against function parameters inside the body
typeParams :: [(Type, Name)] -> (Map Name Type) -> (Map Name Type)
typeParams [] s              = s
typeParams ((ty, ref):tns) s = typeParams tns (insert ref ty s)

-- Helper function that gets the return type of a function
checkReturnType :: Prog -> (Map Name Type) -> Maybe Type
checkReturnType [] s     = Nothing
checkReturnType (c:cs) s = case c of
    (Declare ref e) -> case typeExpr e s of
        (Just Fun_ty)   -> case typeFunc e of
            (Just ty)       -> checkReturnType cs (insert ref ty s)
            Nothing         -> Nothing
        (Just ty)       -> checkReturnType cs (insert ref ty s)
    (Return e)      -> typeExpr e s
    otherwise       -> checkReturnType cs s
    
-- Gets type of a variable
typeOf :: Var -> Type
typeOf (Int _)     = Int_ty
typeOf (Dbl _)     = Dbl_ty
typeOf (Bul _)     = Bul_ty
typeOf (Str _)     = Str_ty
typeOf (Fun _ _ _) = Fun_ty

-- Type error message
tError :: Expr -> Maybe String
tError e = Just ("ERROR: Type error in expression: " ++ (show e))

-- =============================================================================
--                                BINARY OPERATORS
-- =============================================================================

-- Function Type [(Type, Name)] Prog
binOp :: Op -> Var -> Var -> Var
-- Addition
binOp Add (Int s1) (Int s2) = Int (s1 + s2)
binOp Add (Dbl s1) (Dbl s2) = Dbl (s1 + s2)
binOp Add (Int s1) (Dbl s2) = Dbl ((fromIntegral s1) + s2)
binOp Add (Dbl s1) (Int s2) = Dbl (s1 + (fromIntegral s2))
binOp Add (Str s1) (Str s2) = Str (s1 ++ s2)
-- Subtraction
binOp Sub (Int s1) (Int s2) = Int (s1 - s2)
binOp Sub (Dbl s1) (Dbl s2) = Dbl (s1 - s2)
binOp Sub (Int s1) (Dbl s2) = Dbl ((fromIntegral s1) - s2)
binOp Sub (Dbl s1) (Int s2) = Dbl (s1 - (fromIntegral s2))
binOp Sub (Str s1) (Str s2) = Str (strSub s1 s2)
-- Multiplication
binOp Mul (Int s1) (Int s2) = Int (s1 * s2)
binOp Mul (Dbl s1) (Dbl s2) = Dbl (s1 * s2)
-- Division
binOp Div (Int s1) (Int s2) = if s2 /= 0
    then Int (s1 `div` s2) else error "ERROR: attempt to divide by 0"
binOp Div (Dbl s1) (Dbl s2) = if s2 /= 0 
    then Dbl (s1 / s2) else error "ERROR: attempt to divide by 0"

-- Subtracts a string from another string
strSub :: String -> String -> String
strSub [] s2     = []
strSub (c:cs) s2 = case s2 `isPrefixOf` (c:cs) of
    True  -> strSub (Prelude.drop (length s2) (c:cs)) s2
    False -> c:(strSub cs s2)

-- =============================================================================
--                            VARIABLE MANIPULATION
-- =============================================================================

-- Returns a variable by name
get :: Name -> State -> Var 
get ref s = case Data.Map.lookup ref s of
    (Just v) -> v
    Nothing  -> error ("ERROR: variable not in scope: " ++ ref) 

-- Changes the value of a variable on the stack
set :: Name -> Var -> State -> State
set key v s = (insert key v s)

-- Removes a variable from scope
removeVar :: Name -> State -> State
removeVar key s = delete key s

-- Pulls the value out of a bool variable
valBool :: Var -> Bool
valBool (Bul b) = b

-- =============================================================================
--                                   LOOPS
-- =============================================================================

-- NOTE: loops have no inherent scope
-- A while loop of the form `while (condition) {body}`
while :: Expr -> Prog -> State -> State
while e p s = if valBool (expr e s) then while e p (driver p s) else s

-- =============================================================================
--                                 FUNCTIONS
-- =============================================================================

-- First create a state with the function's parameters and then run the function
-- Our functions have static scoping and are pass by value
call :: Name -> [Expr] -> State -> Var
call ref prms s = case get ref s of
    (Fun _ fVars body) ->
        let s' = getParams fVars prms s
        in doFunc body s' 

-- Actually run the function body - similar to the prog function
doFunc :: Prog -> State -> Var
doFunc (c:cs) s' = case c of 
    Return e  -> expr e s'
    otherwise -> doFunc cs (smt c s')  
doFunc [] s'= error "ERROR: No return statement in function body"

-- Binds the params passed to the function to the function's expected variables
-- This creates a sub-state with only the function's passed-in variables
getParams :: [(Type, Name)] -> [Expr] -> State -> State
getParams (fv:fvs) (p:ps) s = case fv of
    (ty, ref) -> if typeOf (expr p s) == ty 
        then set ref (expr p s) empty `union` getParams fvs ps s
        else error "ERROR: Invalid paramer types to function"
getParams [] [] s       = s
getParams [] (p:ps) s   = error "ERROR: Too many parameters passed to function"
getParams (fv:fvs) [] s = error "ERROR: Too few parameters passed to function" 

-- =============================================================================
--                              SYNTACTIC SUGAR
-- =============================================================================

-- S0 is the empty state
s0 :: State
s0 = empty

-- for loop: (declaration; condition; expression) {body}
for :: Name -> Expr -> Expr -> Expr -> Prog -> Prog
for ref dec con e body =
    [Declare ref dec, 
    While con ((Declare ref e):body)]

-- Increments a number
increment :: Name -> Smt
increment ref = Declare ref (BinOp Add (Get ref) (Lit (Int 1)))

-- Decrements a number
decrement :: Name -> Smt
decrement ref = Declare ref (BinOp Sub (Get ref) (Lit (Int 1)))

-- =============================================================================
--                         LIBRARY-LEVEL DEFINITIONS
-- =============================================================================

-- Our language does not have any library-level definitions

-- =============================================================================
--                                EXAMPLES
-- =============================================================================

-- Good example programs:

binOpProg = run [Declare "num" (Lit (Int 23)), 
               Declare "num2" (Lit (Int 24)), 
               Declare "Result" (BinOp Add (Get "num") (Get "num2")),
               Declare "Result" (BinOp Sub (Get "Result") (Get "num2")),
               Declare "Result" (BinOp Mul (Get "Result") (Get "num2")),
               Declare "Result" (BinOp Div (Get "Result") (Get "num2"))] s0

addStrProg = run [Declare "str" (Lit (Str "asd")), 
               Declare "str2" (Lit (Str "123")), 
               Declare "Result" (BinOp Add (Get "str") (Get "str2"))] s0
         
subStrProg = run [Declare "str" (Lit (Str "asdqwe")), 
               Declare "str2" (Lit (Str "dq")), 
               Declare "Result" (BinOp Sub (Get "str") (Get "str2"))] s0
           

iterProg = run [Declare "i" (Lit (Dbl 0)),
             increment "i",
             increment "i", 
             decrement "i"] s0

forProg = run (for "i" (Lit (Int 0)) 
                  (Lt (Get "i") (Lit (Int 10)))
                  (BinOp Add (Get "i") (Lit (Int 1))) 
                  [Declare "z" (Lit (Dbl 0))]) s0
         
funProg = run [Declare "fun" (Lit (Fun Int_ty [(Int_ty, "x")]
                   [Return (BinOp Add (Get "x") (Lit (Int 3)))])),
               Declare "result" (Call "fun" [(Lit (Int 5))])] s0

-- Bad example programs:

divZeroProg = run [Declare "num" (Lit (Int 23)), 
                   Declare "num2" (Lit (Int 0)), 
                   Declare "Result" (BinOp Div (Get "num") (Get "num2"))] s0        

nullVarProg = run [Declare "i" (Get "null")] s0

typeErrProg = run [Declare "int" (Lit (Int 10)),
                   Declare "Bul" (Lit (Bul True)),
                   Declare "result" (BinOp Add (Get "int") (Get "Bul"))] s0

funTerrorProg = run [Declare "fun" (Lit (Fun Int_ty [(Int_ty, "x")]
                   [Return (BinOp Add (Get "x") (Lit (Dbl 3)))])),
               Declare "result" (Call "fun" [(Lit (Int 5))])] s0

