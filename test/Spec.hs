import Test.Hspec
import ParsEd
import Lib
import State
import Data.Map
import Eval


dummyState :: State
dummyState = State ["l1", "l2", "l3", "l4"] 0 (fromList [('a', Line 1), ('b', Line 2), ('p', Line 2)]) NormalMode

main :: IO ()
main = hspec $ do
  describe "Test tokenize" $ do
    it "parses registers" $ do
      tokenize "'ap3'c" `shouldBe` [TokReg 'a', TokChar 'p', TokNum 3, TokReg 'c']
    it "Tokenizes offset targets" $ do
      tokenize "+p" `shouldBe` [TokOffset 1, TokChar 'p']
      tokenize "-p" `shouldBe` [TokOffset (-1), TokChar 'p']
      tokenize "+1p" `shouldBe` [TokOffset 1, TokChar 'p']
      tokenize "-1p" `shouldBe` [TokOffset (-1), TokChar 'p']
      tokenize "+12345p" `shouldBe` [TokOffset 12345, TokChar 'p']
      tokenize "-12345p" `shouldBe` [TokOffset (-12345), TokChar 'p']
  describe "Parse Target" $ do
    it "Parses numeric range" $ do
      parseTarget [TokNum 1, TokKey Comma, TokNum 2] emptyState `shouldBe` Left ((Line 1, Line 2), [])
      parseTarget [TokNum 10, TokKey Comma, TokNum 2] emptyState `shouldBe` Left ((Line 10, Line 2), [])

    it "Parses alpha and numeric tokens" $ do
      parseTarget [TokNum 1, TokKey  Comma, TokChar 'a'] emptyState `shouldBe` Right "Invalid right hand target"
      parseTarget [TokChar 'a', TokKey Comma, TokNum 1] emptyState `shouldBe` Right "Invalid left hand target"

    it "Parses single numgers" $ do
      parseTarget [TokNum 1, TokChar 'p'] emptyState `shouldBe` Left ((Line 1, Line 1), [TokChar 'p'])
      parseTarget [TokChar 'a', TokChar 'p'] emptyState `shouldBe` Right "Invalid target"

    it "Parses the dollar as last line" $
      parseTarget [TokChar '$'] dummyState `shouldBe` Left ((Line 3, Line 3), [])
    xit "Parses the comma as first through last lines" $
      parseTarget [TokChar ','] dummyState `shouldBe` Left ((Line 0, Line 3), [])

  describe "Parse with reg table" $
    it "" $ do
      parseTarget [TokNum 2, TokKey  Comma, TokChar 'a'] dummyState `shouldBe` Left ((Line 2, Line 1), [])
      parseTarget [TokChar 'a', TokKey  Comma, TokNum 2] dummyState `shouldBe` Left ((Line 1, Line 2), [])
      parseTarget [TokChar 'a', TokKey  Comma, TokChar 'b'] dummyState `shouldBe` Left ((Line 1, Line 2), [])

  describe "Print command" $ do
    it "Prints the target" $ do -- this is the mark command...
      ee "3kx" emptyState `shouldBe` (
        (Left (Command (Line 3, Line 3) Mark [TokChar 'x']))
        , emptyState)
      ee "bp" dummyState `shouldBe` (
        (Left (Command (Line 2, Line 2) Print []))
        , dummyState)
      ee "+3p" dummyState `shouldBe` (
        (Left (Command (Line 3, Line 3) Print []))
        , dummyState)
      ee "-3p" dummyState `shouldBe` (
        (Left (Command (Line (-3), Line (-3)) Print []))
        , dummyState)
      ee "$p" dummyState `shouldBe` (
        (Left (Command (Line 3, Line 3) Print []))
        , dummyState)
      ee ",p" dummyState `shouldBe` (
        (Left (Command (Line 0, Line 3) Print []))
        , dummyState)
      ee ";p" dummyState `shouldBe` (
        (Left (Command (Line 0, Line 3) Print []))
        , dummyState)

    it "Should accept registers with names conflicting with functions" $ do
      ee "3ka" emptyState `shouldBe` (
        (Left (Command (Line 3, Line 3) Mark [TokChar 'a']))
        , emptyState)
    it "Should accept register notation in otherwise ambiguous commands" $ do
      ee "'pp" dummyState `shouldBe` (
        (Left (Command (Line 2, Line 2) Print []))
        , dummyState)

  describe "After command" $ do
    it "evaluates" $ do
      evaluate (Command {target = (Line 3,Line 3), op = After, params = []}) dummyState `shouldBe` (
        State {buffer = ["l1","l2","l3","l4"], position = 4, registers = registers dummyState, mode = InsertMode},">")
  describe "Insert command" $ do
    it "evaluates" $ do
      evaluate (Command {target = (Line 3,Line 3), op = Insert, params = []}) dummyState `shouldBe` (
        State {buffer = ["l1","l2","l3","l4"], position = 3, registers = registers dummyState, mode = InsertMode},">")
  describe "Change command" $ do
    it "evaluates" $ do
      -- TODO how does deleting/changing a range move the current target?
      evaluate (Command {target = (Line 3,Line 3), op = Change, params = []}) dummyState `shouldBe` (
        State {buffer = ["l1","l2","l3"], position = position dummyState, registers = registers dummyState, mode = InsertMode},">")
  describe "Delete command" $ do
    it "evaluates" $ do
      evaluate (Command {target = (Line 3,Line 3), op = Delete, params = []}) dummyState `shouldBe` (
        State {buffer = ["l1","l2","l3"], position = position dummyState, registers = registers dummyState, mode = NormalMode},"OK")
  describe "Join command" $ do
    it "evaluates" $ do
      evaluate (Command {target = (Line 0,Line 1), op = Join, params = []}) dummyState `shouldBe` (
        State {buffer = ["l1l2","l3","l4"], position = position dummyState, registers = registers dummyState, mode = NormalMode},"OK")

  describe "Test evaluation" $ do
    it "prints" $ do
      evaluate (Command (Line 3, Line 3) Print []) dummyState `shouldBe` (dummyState, "l4\n")
    xit "Really it should index from 1 like ed. I will write no more\
        \ tests for the correct offset. These tests need to be updated when\
        \ I fix the offset" $ do
      evaluate (Command (Line 3, Line 3) Print []) dummyState `shouldBe` (dummyState, "l3\n")


