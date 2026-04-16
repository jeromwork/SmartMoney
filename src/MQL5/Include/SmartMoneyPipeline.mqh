#property strict

#include <Trade/Trade.mqh>
#include "SmartMoneyContracts.mqh"
#include "SmartMoneyCommon.mqh"
#include "SmartMoneyProviders.mqh"

class CSpreadFilterProvider : public IFilterProvider
{
private:
    double m_max_spread_points;

public:
    CSpreadFilterProvider()
    {
        m_max_spread_points = 30.0;
    }

    void Setup(const double max_spread_points)
    {
        m_max_spread_points = max_spread_points;
    }

    virtual bool Allow(const SM_SignalContext &context, string &reason)
    {
        long spread = 0;
        if (!SymbolInfoInteger(context.symbol, SYMBOL_SPREAD, spread))
        {
            reason = "spread-unavailable";
            return false;
        }

        if ((double)spread > m_max_spread_points)
        {
            reason = "spread-too-wide";
            return false;
        }

        reason = "ok";
        return true;
    }

    virtual string Name()
    {
        return "spread-filter";
    }
};

class CTradeExecutionPolicy : public IExecutionPolicy
{
private:
    CTrade m_trade;
    int m_magic;
    int m_sl_points;
    int m_tp_points;
    double m_risk_percent;

    bool HasOpenPosition(const string symbol)
    {
        int total = PositionsTotal();
        for (int i = 0; i < total; i++)
        {
            ulong ticket = PositionGetTicket(i);
            if (!PositionSelectByTicket(ticket))
            {
                continue;
            }

            string position_symbol = PositionGetString(POSITION_SYMBOL);
            long position_magic = PositionGetInteger(POSITION_MAGIC);
            if (position_symbol == symbol && position_magic == m_magic)
            {
                return true;
            }
        }

        return false;
    }

    double NormalizeVolume(const string symbol, double volume)
    {
        double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
        double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

        if (step <= 0.0)
        {
            step = 0.01;
        }

        volume = MathMax(min_lot, MathMin(max_lot, volume));
        volume = MathFloor(volume / step) * step;
        return NormalizeDouble(volume, 2);
    }

public:
    CTradeExecutionPolicy()
    {
        m_magic = 9100416;
        m_sl_points = 300;
        m_tp_points = 600;
        m_risk_percent = 0.5;
    }

    void Setup(const int magic, const int sl_points, const int tp_points, const double risk_percent)
    {
        m_magic = magic;
        m_sl_points = sl_points;
        m_tp_points = tp_points;
        m_risk_percent = risk_percent;
        m_trade.SetExpertMagicNumber(m_magic);
    }

    virtual bool BuildOrder(const SM_SignalContext &context, double &volume, double &entry_price, double &sl, double &tp)
    {
        double point = SymbolInfoDouble(context.symbol, SYMBOL_POINT);
        if (point <= 0.0)
        {
            return false;
        }

        MqlTick tick;
        if (!SymbolInfoTick(context.symbol, tick))
        {
            return false;
        }

        if (context.direction > 0)
        {
            entry_price = tick.ask;
            sl = entry_price - ((double)m_sl_points * point);
            tp = entry_price + ((double)m_tp_points * point);
        }
        else if (context.direction < 0)
        {
            entry_price = tick.bid;
            sl = entry_price + ((double)m_sl_points * point);
            tp = entry_price - ((double)m_tp_points * point);
        }
        else
        {
            return false;
        }

        double equity = AccountInfoDouble(ACCOUNT_EQUITY);
        double risk_money = equity * (m_risk_percent / 100.0);
        double tick_size = SymbolInfoDouble(context.symbol, SYMBOL_TRADE_TICK_SIZE);
        double tick_value = SymbolInfoDouble(context.symbol, SYMBOL_TRADE_TICK_VALUE);
        double stop_price_distance = (double)m_sl_points * point;

        if (tick_size <= 0.0 || tick_value <= 0.0 || stop_price_distance <= 0.0)
        {
            return false;
        }

        double loss_per_lot = (stop_price_distance / tick_size) * tick_value;
        if (loss_per_lot <= 0.0)
        {
            return false;
        }

        volume = NormalizeVolume(context.symbol, risk_money / loss_per_lot);
        return volume > 0.0;
    }

    virtual bool CanSend(const SM_SignalContext &context, string &reason)
    {
        if (!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
        {
            reason = "trade-disabled";
            return false;
        }

        if (HasOpenPosition(context.symbol))
        {
            reason = "position-exists";
            return false;
        }

        reason = "ok";
        return true;
    }

    virtual bool Send(const SM_SignalContext &context, const double volume, const double entry_price, const double sl, const double tp, string &result)
    {
        bool sent = false;
        if (context.direction > 0)
        {
            sent = m_trade.Buy(volume, context.symbol, entry_price, sl, tp, "SM-Composer");
        }
        else if (context.direction < 0)
        {
            sent = m_trade.Sell(volume, context.symbol, entry_price, sl, tp, "SM-Composer");
        }

        if (!sent)
        {
            result = "trade-failed:" + IntegerToString((int)m_trade.ResultRetcode());
            return false;
        }

        result = "ticket=" + IntegerToString((int)m_trade.ResultOrder());
        return true;
    }

    virtual string Name()
    {
        return "trade-execution";
    }
};

class CSignalComposer
{
private:
    ISignalProvider *m_providers[];
    int m_count;
    ENUM_SM_COMPOSITION m_mode;
    double m_score_threshold;

public:
    CSignalComposer()
    {
        m_count = 0;
        m_mode = SM_COMPOSITION_AND;
        m_score_threshold = 120.0;
    }

    void Configure(const ENUM_SM_COMPOSITION mode, const double score_threshold)
    {
        m_mode = mode;
        m_score_threshold = score_threshold;
    }

    bool Add(ISignalProvider *provider)
    {
        int next = m_count + 1;
        ArrayResize(m_providers, next);
        m_providers[m_count] = provider;
        m_count = next;
        return true;
    }

    void Reset()
    {
        m_count = 0;
        ArrayResize(m_providers, 0);
    }

    bool Compose(SM_SignalContext &context)
    {
        context.valid = false;
        context.direction = 0;
        context.score = 0.0;
        context.reasons = "";

        if (m_count == 0)
        {
            return false;
        }

        int valid_count = 0;
        int buy_votes = 0;
        int sell_votes = 0;
        double buy_score = 0.0;
        double sell_score = 0.0;
        double total_score = 0.0;

        for (int i = 0; i < m_count; i++)
        {
            SM_SignalContext one;
            one.valid = false;
            if (!m_providers[i].BuildSignal(one))
            {
                continue;
            }

            if (!one.valid)
            {
                continue;
            }

            valid_count++;
            if (one.direction > 0)
            {
                buy_votes++;
                buy_score += one.score;
            }
            else if (one.direction < 0)
            {
                sell_votes++;
                sell_score += one.score;
            }

            total_score += one.score;
            if (context.symbol == "")
            {
                context.symbol = one.symbol;
                context.timeframe = one.timeframe;
            }

            if (context.reasons != "")
            {
                context.reasons += "|";
            }

            context.reasons += m_providers[i].Name() + ":" + one.reasons;
            context.invalidation = one.invalidation;
        }

        if (valid_count == 0)
        {
            return false;
        }

        if (buy_votes == sell_votes)
        {
            return false;
        }

        context.direction = (buy_votes > sell_votes) ? 1 : -1;

        if (m_mode == SM_COMPOSITION_AND)
        {
            context.valid = (valid_count == m_count);
            context.score = total_score / (double)valid_count;
        }
        else if (m_mode == SM_COMPOSITION_OR)
        {
            context.valid = true;
            context.score = total_score / (double)valid_count;
        }
        else
        {
            double side_score = (context.direction > 0) ? buy_score : sell_score;
            context.valid = side_score >= m_score_threshold;
            context.score = side_score;
        }

        return context.valid;
    }
};

class CProviderRegistry
{
public:
    bool BuildProviders(const string profile,
                        const string symbol,
                        const ENUM_TIMEFRAMES timeframe,
                        const double min_score,
                        const int trend_period,
                        const bool show_buy_arrows,
                        const bool show_sell_arrows,
                        const double arrow_offset_points,
                        const int buy_arrow_code,
                        const int sell_arrow_code,
                        IIndicatorProvider *&indicator_providers[],
                        ISignalProvider *&signal_providers[])
    {
        ArrayResize(indicator_providers, 0);
        ArrayResize(signal_providers, 0);

        CICustomIndicatorProvider *icustom = new CICustomIndicatorProvider();
        icustom.Setup("SmartMoneyZones",
                      trend_period,
                      false,
                      show_buy_arrows,
                      show_sell_arrows,
                      arrow_offset_points,
                      buy_arrow_code,
                      sell_arrow_code);
        if (icustom.Init(symbol, timeframe))
        {
            int idx = ArraySize(indicator_providers);
            ArrayResize(indicator_providers, idx + 1);
            indicator_providers[idx] = icustom;

            CThresholdSignalProvider *signal_from_icustom = new CThresholdSignalProvider();
            signal_from_icustom.Setup(indicator_providers[idx], "icustom-threshold", symbol, timeframe, min_score);
            int sig_idx = ArraySize(signal_providers);
            ArrayResize(signal_providers, sig_idx + 1);
            signal_providers[sig_idx] = signal_from_icustom;
        }
        else
        {
            delete icustom;
        }

        // Engine fallback is always available and keeps profile swap compatible.
        CEngineIndicatorProvider *engine = new CEngineIndicatorProvider();
        if (engine.Init(symbol, timeframe))
        {
            int idx = ArraySize(indicator_providers);
            ArrayResize(indicator_providers, idx + 1);
            indicator_providers[idx] = engine;

            double engine_score = min_score;
            if (StringFind(profile, "strict") >= 0)
            {
                engine_score = MathMax(min_score, 65.0);
            }

            CThresholdSignalProvider *signal_from_engine = new CThresholdSignalProvider();
            signal_from_engine.Setup(indicator_providers[idx], "engine-threshold", symbol, timeframe, engine_score);
            int sig_idx = ArraySize(signal_providers);
            ArrayResize(signal_providers, sig_idx + 1);
            signal_providers[sig_idx] = signal_from_engine;
        }
        else
        {
            delete engine;
        }

        return ArraySize(signal_providers) > 0;
    }
};

class CPairScanner
{
private:
    string m_symbol;
    ENUM_TIMEFRAMES m_timeframe;
    datetime m_last_bar_time;
    IIndicatorProvider *m_indicator_providers[];
    ISignalProvider *m_signal_providers[];
    CSignalComposer m_composer;

public:
    CPairScanner()
    {
        m_symbol = "";
        m_timeframe = PERIOD_CURRENT;
        m_last_bar_time = 0;
    }

    bool Init(CProviderRegistry &registry,
              const string profile,
              const string symbol,
              const ENUM_TIMEFRAMES timeframe,
              const ENUM_SM_COMPOSITION composition_mode,
              const double min_score,
              const double score_threshold,
              const int trend_period,
              const bool show_buy_arrows,
              const bool show_sell_arrows,
              const double arrow_offset_points,
              const int buy_arrow_code,
              const int sell_arrow_code)
    {
        m_symbol = symbol;
        m_timeframe = timeframe;
        m_last_bar_time = 0;

        if (!registry.BuildProviders(profile,
                                     symbol,
                                     timeframe,
                                     min_score,
                                     trend_period,
                                     show_buy_arrows,
                                     show_sell_arrows,
                                     arrow_offset_points,
                                     buy_arrow_code,
                                     sell_arrow_code,
                                     m_indicator_providers,
                                     m_signal_providers))
        {
            return false;
        }

        m_composer.Reset();
        m_composer.Configure(composition_mode, score_threshold);
        for (int i = 0; i < ArraySize(m_signal_providers); i++)
        {
            m_composer.Add(m_signal_providers[i]);
        }

        return true;
    }

    bool Scan(SM_SignalContext &context, bool &bar_updated)
    {
        bar_updated = false;
        datetime bar_time = iTime(m_symbol, m_timeframe, 0);
        if (bar_time <= 0 || bar_time == m_last_bar_time)
        {
            return false;
        }

        m_last_bar_time = bar_time;
        bar_updated = true;
        context.symbol = m_symbol;
        context.timeframe = m_timeframe;
        context.valid = false;
        return m_composer.Compose(context);
    }

    string Symbol()
    {
        return m_symbol;
    }

    ENUM_TIMEFRAMES Timeframe()
    {
        return m_timeframe;
    }

    void Deinit()
    {
        for (int i = 0; i < ArraySize(m_signal_providers); i++)
        {
            if (m_signal_providers[i] != NULL)
            {
                m_signal_providers[i].Deinit();
                delete m_signal_providers[i];
            }
        }

        for (int i = 0; i < ArraySize(m_indicator_providers); i++)
        {
            if (m_indicator_providers[i] != NULL)
            {
                m_indicator_providers[i].Deinit();
                delete m_indicator_providers[i];
            }
        }

        ArrayResize(m_signal_providers, 0);
        ArrayResize(m_indicator_providers, 0);
    }
};
