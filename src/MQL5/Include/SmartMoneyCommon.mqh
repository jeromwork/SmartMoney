#property strict

bool SM_IsNewBar()
{
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(_Symbol, _Period, 0);
    if (currentBarTime == 0)
    {
        return false;
    }

    if (currentBarTime != lastBarTime)
    {
        lastBarTime = currentBarTime;
        return true;
    }

    return false;
}

void SM_Log(string scope, string message)
{
    Print("[SM][", scope, "] ", message);
}

void SM_LogError(string scope, int code, string message)
{
    Print("[SM][", scope, "][ERROR] code=", IntegerToString(code), " message=", message);
}

double SM_NormalizeLots(double lots)
{
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    if (lotStep <= 0.0)
    {
        lotStep = 0.01;
    }

    lots = MathMax(minLot, MathMin(maxLot, lots));
    lots = MathFloor(lots / lotStep) * lotStep;
    return NormalizeDouble(lots, 2);
}

bool SM_IsSpreadAcceptable(double maxSpreadPoints)
{
    long spread = 0;
    if (!SymbolInfoInteger(_Symbol, SYMBOL_SPREAD, spread))
    {
        return false;
    }

    return (double)spread <= maxSpreadPoints;
}
