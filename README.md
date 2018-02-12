# crypto-bot-hs - beta

[![Build Status](https://travis-ci.org/epicallan/crypto-bot-hs.svg?branch=master)](https://travis-ci.org/epicallan/crypto-bot-hs)

For identifying crypto coins that have dipped (fallen in price) and are starting to recover in the past few days.
I use the coins daily [RSI](http://stockcharts.com/school/doku.php?id=chart_school:technical_indicators:relative_strength_index_rsi) to identify whether the coin has already dipped and there after do some more analysis.

This bot runs as a cron job, writing results to a mongodb. The results will be picked up by a web app for display & possibly a twitter bot.
