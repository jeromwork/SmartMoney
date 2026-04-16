#property strict

bool SM_IsNewBar()
{
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(Symbol(), Period(), 0);
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
    Print("[SM][", scope, "][ERROR] code=", code, " message=", message);
}

double SM_NormalizeLots(double lots)
{
    double minLot = MarketInfo(Symbol(), MODE_MINLOT);
    double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
    double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);

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
    double spread = MarketInfo(Symbol(), MODE_SPREAD);
    return spread <= maxSpreadPoints;
}
