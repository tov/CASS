#!/usr/bin/env runghc

import Text.CSV

columns_before_rubric = 7
columns_after_rubric  = 4

main :: IO ()
main  = do
  csv <- getContents >>= either (fail . show) return . parseCSV "-"
  let header:records = takeWhile (not . null) csv
  let rubric         = drop columns_before_rubric .
                         take (length header - columns_after_rubric) $
                           header
  mapM_ (transform rubric) records

transform :: [String] -> [String] -> IO ()
transform rubric (_:_:_:netid:_:score:_:rest)
  | not (null netid) 
  , _:_:comment:bools <- reverse rest = do
    putStr $ netid++" "++score
    mapM_ showComment
      [ com | (com, "true") <- zip rubric (reverse bools) ]
    showComment comment
    putChar '\n'
transform _ _ = return ()

showComment :: String -> IO ()
showComment "\"\""  = return ()
showComment comment = do
  putStr $ "  " ++ shellQuote comment

shellQuote :: String -> String
shellQuote s = "\"" ++ escape s ++ "\"" where
  escape [] = ""
  escape (c:cs)
    | c `elem` "\\`$\"" = '\\' : c : escape cs
    | otherwise         = c : escape cs
