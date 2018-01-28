{-# LANGUAGE ExtendedDefaultRules  #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
module Utils.DB where
import           Data.Dates
import           Data.Maybe
import qualified Data.String        as S (String, fromString)
import qualified Data.Text          as T
import           Data.Time.Calendar
import           Data.Time.Clock
import           Database.MongoDB
import           Protolude
import qualified Text.Parsec        as P
import           Types              (BasicStats (..), DipState (..))

-- | This module has db methods we use to save the script results in a db

cryptoDB :: Database
cryptoDB = "crypto"

dipCol :: Collection
dipCol = "dip"

type Coin = Text

newtype ValDate = ValDate DateTime deriving (Eq, Show) -- for making dateTime an instance of Val

instance Val (ValDate, ValDate) where
    val (x, y) = String $ showValDate x <> ","
     <> showValDate y
    cast' (String x )= parseValDates (T.unpack x)


showValDate :: ValDate -> Text
showValDate (ValDate d) =
    let year'  = show $ year d
        month' = show $ month d
        date'  = show $ day d
    in T.pack (year' ++ "/" ++ month' ++ "/" ++ date')

parseValDateStr :: P.Parsec S.String () ValDate
parseValDateStr = do
    (d, m) <- liftA2 (,) pDigits pDigits
    y <-  P.many P.digit
    return $ ValDate $ DateTime (fromIntegral $ value' y) (value' m :: Int) (value' d :: Int) 0 0 0
    where
        value' = fromMaybe 0 . readMaybe
        pDigits = P.many P.digit <* P.space

splitValDateStr:: P.Parsec S.String () (S.String, S.String)
splitValDateStr= (,) <$> pDigitSpaces <*> (P.char ','  *> pDigitSpaces)
    where
        pDigitSpaces = P.many (P.digit <|> P.space)

parseValDates :: S.String -> Maybe (ValDate, ValDate)
parseValDates dateStr =
    let eResult = parse splitValDateStr dateStr
        getMaybeD = either (const Nothing) Just
    in case eResult of
            Right (x, y) ->
                let d1 = getMaybeD (parse parseValDateStr x) -- this  is repition, how can i improve this
                    d2 = getMaybeD (parse parseValDateStr y) --- this is repition
                in (,) <$> d1  <*> d2
            Left _       -> Nothing

parse :: P.Stream s Identity t => P.Parsec s () a -> s -> Either P.ParseError a
parse rule = P.parse rule "(source)"

runDb :: Action IO a -> IO a
runDb action = do
    pipe <- connect (host "localhost")
    result <- access pipe master cryptoDB action
    close pipe
    return result

-- | we insert records on a weekly basis
-- | hence we have a week field which is a date range i.e 22-01-2018 - 28-01-2018
getDate :: IO DateTime
getDate =  (toDate .toGregorian . utctDay) <$> getCurrentTime
    where
        toDate :: (Integer, Int, Int) -> DateTime
        toDate (year', month', day') = DateTime (fromIntegral year') month' day' 0 0 0


getDateRange :: IO (DateTime, DateTime) -- tuple of 2 dates
getDateRange = (\currentDate -> (currentDate, newDate currentDate)) <$> getDate
    where
        newDate :: DateTime -> DateTime
        newDate now =  addInterval now (Days 7)


addRecord :: DipState -> Action IO Value
addRecord dip = do
    range <- liftIO getDateRange
    insert dipCol (fields range)
    where
        stats' = stats dip
        toValDate (x, y) = (ValDate x, ValDate y)
        fields range' = [
                "coinName" =: coinName dip
            ,   "mean" =: mean stats'
            ,   "std" =: std stats'
            ,   "date range" =: toValDate range'
            ]

-- getRecord :: Action IO Value

-- getWeeksRecords :: Action IO Value