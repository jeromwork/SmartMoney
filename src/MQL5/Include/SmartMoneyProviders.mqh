#property strict

#include "SmartMoneyContracts.mqh"

class CICustomIndicatorProvider : public IIndicatorProvider
{
private:
    string m_symbol;
    ENUM_TIMEFRAMES m_timeframe;
    string m_indicator_name;
    int m_handle;
    string m_state;

public:
    CICustomIndicatorProvider()
    {
        m_symbol = "";
        m_timeframe = PERIOD_CURRENT;
        m_indicator_name = "SmartMoneyZones";
        m_handle = INVALID_HANDLE;
        m_state = "not-initialized";
    }

    void Setup(const string indicator_name)
    {
        m_indicator_name = indicator_name;
    }

    virtual bool Init(const string symbol, const ENUM_TIMEFRAMES timeframe)
    {
        m_symbol = symbol;
        m_timeframe = timeframe;
        m_handle = iCustom(m_symbol, m_timeframe, m_indicator_name);
        if (m_handle == INVALID_HANDLE)
        {
            m_state = "handle-error";
            return false;
        }

        m_state = "ready";
        return true;
    }

    virtual bool Refresh()
    {
        if (m_handle == INVALID_HANDLE)
        {
            m_state = "invalid-handle";
            return false;
        }

        m_state = "ready";
        return true;
    }

    virtual double GetValue(const int buffer_id, const int shift)
    {
        if (m_handle == INVALID_HANDLE)
        {
            return 0.0;
        }

        double values[];
        if (CopyBuffer(m_handle, buffer_id, shift, 1, values) != 1)
        {
            m_state = "copy-buffer-failed";
            return 0.0;
        }

        return values[0];
    }

    virtual string GetState()
    {
        return m_state;
    }

    virtual string Name()
    {
        return "icustom:" + m_indicator_name;
    }

    virtual void Deinit()
    {
        if (m_handle != INVALID_HANDLE)
        {
            IndicatorRelease(m_handle);
            m_handle = INVALID_HANDLE;
        }

        m_state = "released";
    }
};

class CEngineIndicatorProvider : public IIndicatorProvider
{
private:
    string m_symbol;
    ENUM_TIMEFRAMES m_timeframe;
    string m_state;
    double m_direction;
    double m_score;
    double m_invalidation;

public:
    CEngineIndicatorProvider()
    {
        m_symbol = "";
        m_timeframe = PERIOD_CURRENT;
        m_state = "not-initialized";
        m_direction = 0.0;
        m_score = 0.0;
        m_invalidation = 0.0;
    }

    virtual bool Init(const string symbol, const ENUM_TIMEFRAMES timeframe)
    {
        m_symbol = symbol;
        m_timeframe = timeframe;
        m_state = "ready";
        return true;
    }

    virtual bool Refresh()
    {
        MqlRates rates[];
        int copied = CopyRates(m_symbol, m_timeframe, 0, 40, rates);
        if (copied < 25)
        {
            m_state = "not-enough-rates";
            m_direction = 0.0;
            m_score = 0.0;
            m_invalidation = 0.0;
            return false;
        }

        ArraySetAsSeries(rates, true);

        double sum = 0.0;
        for (int i = 1; i <= 20; i++)
        {
            sum += rates[i].close;
        }

        double sma = sum / 20.0;
        double current = rates[1].close;
        double previous = rates[2].close;

        if (current > sma && current > previous)
        {
            m_direction = 1.0;
        }
        else if (current < sma && current < previous)
        {
            m_direction = -1.0;
        }
        else
        {
            m_direction = 0.0;
        }

        double body = MathAbs(rates[1].close - rates[1].open);
        double range = MathMax(rates[1].high - rates[1].low, SymbolInfoDouble(m_symbol, SYMBOL_POINT));
        m_score = MathMin(100.0, (body / range) * 100.0);

        if (m_direction > 0.0)
        {
            m_invalidation = rates[1].low;
        }
        else if (m_direction < 0.0)
        {
            m_invalidation = rates[1].high;
        }
        else
        {
            m_invalidation = 0.0;
        }

        m_state = "ready";
        return true;
    }

    virtual double GetValue(const int buffer_id, const int shift)
    {
        if (shift != 0)
        {
            return 0.0;
        }

        if (buffer_id == 0)
        {
            return m_direction;
        }

        if (buffer_id == 1)
        {
            return m_score;
        }

        if (buffer_id == 2)
        {
            return m_invalidation;
        }

        return 0.0;
    }

    virtual string GetState()
    {
        return m_state;
    }

    virtual string Name()
    {
        return "engine:baseline";
    }

    virtual void Deinit()
    {
        m_state = "released";
    }
};

class CThresholdSignalProvider : public ISignalProvider
{
private:
    IIndicatorProvider *m_provider;
    string m_name;
    string m_symbol;
    ENUM_TIMEFRAMES m_timeframe;
    double m_min_score;

public:
    CThresholdSignalProvider()
    {
        m_provider = NULL;
        m_name = "threshold";
        m_symbol = "";
        m_timeframe = PERIOD_CURRENT;
        m_min_score = 50.0;
    }

    void Setup(IIndicatorProvider *provider, const string name, const string symbol, const ENUM_TIMEFRAMES timeframe, const double min_score)
    {
        m_provider = provider;
        m_name = name;
        m_symbol = symbol;
        m_timeframe = timeframe;
        m_min_score = min_score;
    }

    virtual bool BuildSignal(SM_SignalContext &context)
    {
        if (m_provider == NULL)
        {
            return false;
        }

        if (!m_provider.Refresh())
        {
            return false;
        }

        double direction = m_provider.GetValue(0, 0);
        double score = m_provider.GetValue(1, 0);
        double invalidation = m_provider.GetValue(2, 0);

        context.symbol = m_symbol;
        context.timeframe = m_timeframe;
        context.direction = (int)MathRound(direction);
        context.score = score;
        context.reasons = m_name + ";state=" + m_provider.GetState();
        context.invalidation = invalidation;
        context.sl = 0.0;
        context.tp = 0.0;
        context.valid = (context.direction != 0 && context.score >= m_min_score);
        return true;
    }

    virtual string Name()
    {
        return m_name;
    }

    virtual void Deinit()
    {
    }
};
