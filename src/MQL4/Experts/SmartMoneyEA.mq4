#property strict

#include <SmartMoneyCommon.mqh>

input double InpLots = 0.10;
input int InpStopLossPoints = 300;
input int InpTakeProfitPoints = 600;
input int InpMaxSpreadPoints = 30;
input int InpMagicNumber = 9100416;

int OnInit()
{
    SM_Log("EA", "Initialized");
    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
    SM_Log("EA", "Deinitialized");
}

void OnTick()
{
    if (!SM_IsNewBar())
    {
        return;
    }

    if (!SM_IsSpreadAcceptable(InpMaxSpreadPoints))
    {
        SM_Log("EA", "Spread filter rejected the bar");
        return;
    }

    // TODO: Replace this placeholder with the currently discussed strategy rules.
}
