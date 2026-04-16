#property strict

bool SM_ParseCsv(const string csv, string &items[])
{
    string sanitized = csv;
    StringReplace(sanitized, " ", "");

    string raw[];
    int count = StringSplit(sanitized, ',', raw);
    if (count <= 0)
    {
        ArrayResize(items, 0);
        return false;
    }

    ArrayResize(items, 0);
    for (int i = 0; i < count; i++)
    {
        if (raw[i] == "")
        {
            continue;
        }

        int next = ArraySize(items);
        ArrayResize(items, next + 1);
        items[next] = raw[i];
    }

    return ArraySize(items) > 0;
}

bool SM_ParseTimeframesCsv(const string csv, ENUM_TIMEFRAMES &timeframes[])
{
    string names[];
    if (!SM_ParseCsv(csv, names))
    {
        ArrayResize(timeframes, 0);
        return false;
    }

    ArrayResize(timeframes, 0);
    for (int i = 0; i < ArraySize(names); i++)
    {
        ENUM_TIMEFRAMES tf;
        if (!SM_ParseTimeframe(names[i], tf))
        {
            continue;
        }

        int next = ArraySize(timeframes);
        ArrayResize(timeframes, next + 1);
        timeframes[next] = tf;
    }

    return ArraySize(timeframes) > 0;
}

bool SM_ParseTimeframe(const string text, ENUM_TIMEFRAMES &timeframe)
{
    string normalized = text;
    StringToUpper(normalized);

    if (normalized == "M1")
    {
        timeframe = PERIOD_M1;
        return true;
    }

    if (normalized == "M5")
    {
        timeframe = PERIOD_M5;
        return true;
    }

    if (normalized == "M15")
    {
        timeframe = PERIOD_M15;
        return true;
    }

    if (normalized == "M30")
    {
        timeframe = PERIOD_M30;
        return true;
    }

    if (normalized == "H1")
    {
        timeframe = PERIOD_H1;
        return true;
    }

    if (normalized == "H4")
    {
        timeframe = PERIOD_H4;
        return true;
    }

    if (normalized == "D1")
    {
        timeframe = PERIOD_D1;
        return true;
    }

    return false;
}

string SM_TimeframeToString(const ENUM_TIMEFRAMES timeframe)
{
    if (timeframe == PERIOD_M1)
    {
        return "M1";
    }

    if (timeframe == PERIOD_M5)
    {
        return "M5";
    }

    if (timeframe == PERIOD_M15)
    {
        return "M15";
    }

    if (timeframe == PERIOD_M30)
    {
        return "M30";
    }

    if (timeframe == PERIOD_H1)
    {
        return "H1";
    }

    if (timeframe == PERIOD_H4)
    {
        return "H4";
    }

    if (timeframe == PERIOD_D1)
    {
        return "D1";
    }

    return "UNKNOWN";
}

void SM_Log(const string scope, const string message)
{
    Print("[SM][", scope, "] ", message);
}

void SM_LogError(const string scope, const int code, const string message)
{
    Print("[SM][", scope, "][ERROR] code=", IntegerToString(code), " message=", message);
}

bool SM_EnsureSymbol(const string symbol)
{
    if (!SymbolSelect(symbol, true))
    {
        return false;
    }

    return true;
}
