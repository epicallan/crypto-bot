module Dip (runAnalysis) where

import           Bittrex.API
import           Bittrex.Types
import           Control.Concurrent.Async
import           Control.Exception.Safe
import           Data.Maybe
import qualified Data.Text                as Text
import           Protolude                hiding (onException)
import           System.Exit              (ExitCode (..), exitWith)
import           TA.RSI                   (rsi)
import           Types
import           Utils.DB                 (addCoinDipRecord, runDb)
import           Utils.Stats              (baseStats)

-- | get coins that have dipped & are possibly in consolidation

-- | get actvie btc based altcoins
btcAlts :: IO (Maybe [Market])
btcAlts = getCoins `onException` exitWith (ExitFailure 500)
    where
        getCoins = do
            eMarkets <- getMarkets
            case eMarkets of
                Left err      -> print err >> pure Nothing
                Right markets -> pure $ Just $ requiredMarkets markets
        requiredMarkets =
            filter (\m -> marketIsActive m && marketBaseCurrency m == "BTC")

-- | get candles for a coin above a certain btc volume
btcAltCandles :: MarketName -> IO (Maybe[Candle])
btcAltCandles alt =  getBtcAltCandles `onException` pure Nothing
    where
        getBtcAltCandles = do
            (eSummary, eCandles) <- concurrently (getMarketSummary alt) (getCandles Day alt)
            case eSummary of
                Left err      -> print err >> pure Nothing
                Right summary' -> do
                    let summary = head summary'
                    let isAboveVolumeCap = maybe False (\x -> marketSummaryBaseVolume x > 80) summary
                    case eCandles of
                        Left err -> print err >> pure Nothing
                        Right candles ->
                            if isAboveVolumeCap then pure $ Just candles else pure Nothing


-- |  Anlyse coin and write results to DB if below a certain RSI
analyse :: MarketName -> IO ()
analyse alt = do
    candles <- btcAltCandles alt
    let closePrices = maybe [] (fmap close) candles :: [Double]
    let rsi' = fromMaybe 0 $ rsi 14 closePrices :: Double
    let stats' = baseStats closePrices :: Maybe BasicStats
    case stats' of
        Nothing -> pure ()
        Just stats'' -> do
            let dipState = DipState alt stats''
            when (rsi' < 45 && rsi' > 0) (void $ runDb (addCoinDipRecord dipState))


runAnalysis :: IO ()
runAnalysis = do
    alts <- btcAlts
    case alts of
        Nothing    -> pure ()
        Just coins -> mapM_ (analyse . marketName) coins
