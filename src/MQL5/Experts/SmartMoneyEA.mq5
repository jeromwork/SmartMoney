#property strict

#include "..\Include\SmartMoneyContracts.mqh"
#include "..\Include\SmartMoneyPipeline.mqh"

input string InpProvidersProfile = "sweep_mss_fvg_normal";
input string InpSymbolsCsv = "EURUSD,GBPUSD,USDJPY";
input string InpTimeframesCsv = "M1,M5,M15,H1,H4,D1";
input ENUM_SM_MODE InpRunMode = LiveManualConfirm;
input ENUM_SM_COMPOSITION InpCompositionMode = SM_COMPOSITION_AND;
input int InpScanIntervalSeconds = 5;
input double InpMinSignalScore = 55.0;
input double InpScoreThreshold = 120.0;
input int InpMaxSpreadPoints = 30;
input int InpStopLossPoints = 300;
input int InpTakeProfitPoints = 600;
input double InpRiskPerTradePercent = 0.5;
input int InpMagicNumber = 9100416;
input bool InpEnableTrading = true;

string g_symbols[];
ENUM_TIMEFRAMES g_timeframes[];
CPairScanner *g_scanners[];
CProviderRegistry g_registry;
CSpreadFilterProvider g_spread_filter;
CTradeExecutionPolicy g_execution;

SM_SignalContext g_pending_signal;
bool g_has_pending_signal = false;
bool g_confirm_requested = false;

string g_confirm_button = "SM_CONFIRM_BUTTON";

void SM_CreateConfirmButton()
{
    if (InpRunMode != LiveManualConfirm)
    {
        return;
    }

    if (ObjectFind(0, g_confirm_button) >= 0)
    {
        return;
    }

    ObjectCreate(0, g_confirm_button, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, g_confirm_button, OBJPROP_XDISTANCE, 15);
    ObjectSetInteger(0, g_confirm_button, OBJPROP_YDISTANCE, 30);
    ObjectSetInteger(0, g_confirm_button, OBJPROP_XSIZE, 170);
    ObjectSetInteger(0, g_confirm_button, OBJPROP_YSIZE, 24);
    ObjectSetInteger(0, g_confirm_button, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, g_confirm_button, OBJPROP_BGCOLOR, clrDarkGreen);
    ObjectSetString(0, g_confirm_button, OBJPROP_TEXT, "Confirm SmartMoney Trade");
}

void SM_DestroyConfirmButton()
{
    if (ObjectFind(0, g_confirm_button) >= 0)
    {
        ObjectDelete(0, g_confirm_button);
    }
}

void SM_DestroyScanners()
{
    for (int i = 0; i < ArraySize(g_scanners); i++)
    {
        if (g_scanners[i] != NULL)
        {
            g_scanners[i].Deinit();
            delete g_scanners[i];
        }
    }

    ArrayResize(g_scanners, 0);
}

bool SM_BuildScanners()
{
    SM_DestroyScanners();

    for (int s = 0; s < ArraySize(g_symbols); s++)
    {
        if (!SM_EnsureSymbol(g_symbols[s]))
        {
            SM_LogError("EA", GetLastError(), "Symbol is not available: " + g_symbols[s]);
            continue;
        }

        for (int t = 0; t < ArraySize(g_timeframes); t++)
        {
            CPairScanner *scanner = new CPairScanner();
            bool ok = scanner.Init(g_registry,
                                   InpProvidersProfile,
                                   g_symbols[s],
                                   g_timeframes[t],
                                   InpCompositionMode,
                                   InpMinSignalScore,
                                   InpScoreThreshold);
            if (!ok)
            {
                delete scanner;
                SM_Log("EA", "Provider init skipped for " + g_symbols[s] + " " + SM_TimeframeToString(g_timeframes[t]));
                continue;
            }

            int next = ArraySize(g_scanners);
            ArrayResize(g_scanners, next + 1);
            g_scanners[next] = scanner;
        }
    }

    return ArraySize(g_scanners) > 0;
}

bool SM_ExecuteSignal(const SM_SignalContext &context)
{
    if (!InpEnableTrading)
    {
        SM_Log("EXEC", "Trading disabled by input flag");
        return false;
    }

    string reason;
    if (!g_execution.CanSend(context, reason))
    {
        SM_Log("EXEC", "CanSend rejected: " + reason + " " + context.symbol + " " + SM_TimeframeToString(context.timeframe));
        return false;
    }

    double volume = 0.0;
    double entry = 0.0;
    double sl = 0.0;
    double tp = 0.0;
    if (!g_execution.BuildOrder(context, volume, entry, sl, tp))
    {
        SM_Log("EXEC", "BuildOrder failed for " + context.symbol);
        return false;
    }

    string result;
    if (!g_execution.Send(context, volume, entry, sl, tp, result))
    {
        SM_Log("EXEC", "Send failed: " + result);
        return false;
    }

    SM_Log("EXEC", "Trade sent " + result + " symbol=" + context.symbol + " tf=" + SM_TimeframeToString(context.timeframe));
    return true;
}

void SM_RenderStatus(const string extra)
{
    string mode = (InpRunMode == AutoTest) ? "AutoTest" : "LiveManualConfirm";
    string pending = g_has_pending_signal ? (g_pending_signal.symbol + "/" + SM_TimeframeToString(g_pending_signal.timeframe) + " score=" + DoubleToString(g_pending_signal.score, 1)) : "none";
    Comment("SmartMoney Orchestrator\n",
            "Mode: ", mode, "\n",
            "Profile: ", InpProvidersProfile, "\n",
            "Scanners: ", IntegerToString(ArraySize(g_scanners)), "\n",
            "Pending: ", pending, "\n",
            extra);
}

void SM_ProcessScanners()
{
    string status = "";
    for (int i = 0; i < ArraySize(g_scanners); i++)
    {
        SM_SignalContext context;
        context.valid = false;

        if (!g_scanners[i].Scan(context))
        {
            continue;
        }

        string filter_reason;
        if (!g_spread_filter.Allow(context, filter_reason))
        {
            SM_Log("FILTER", context.symbol + " " + SM_TimeframeToString(context.timeframe) + " rejected: " + filter_reason);
            continue;
        }

        status = "Last signal: " + context.symbol + " " + SM_TimeframeToString(context.timeframe) + " dir=" + IntegerToString(context.direction) + " score=" + DoubleToString(context.score, 1);
        SM_Log("SIGNAL", status + " reasons=" + context.reasons);

        if (InpRunMode == AutoTest)
        {
            SM_ExecuteSignal(context);
            continue;
        }

        g_pending_signal = context;
        g_has_pending_signal = true;
    }

    if (InpRunMode == LiveManualConfirm && g_confirm_requested)
    {
        g_confirm_requested = false;
        if (g_has_pending_signal)
        {
            SM_ExecuteSignal(g_pending_signal);
            g_has_pending_signal = false;
        }
        else
        {
            SM_Log("UI", "Confirm clicked but no pending signal");
        }
    }

    SM_RenderStatus(status);
}

int OnInit()
{
    if (!SM_ParseCsv(InpSymbolsCsv, g_symbols))
    {
        SM_LogError("EA", 0, "SymbolsCsv parsing failed");
        return INIT_PARAMETERS_INCORRECT;
    }

    if (!SM_ParseTimeframesCsv(InpTimeframesCsv, g_timeframes))
    {
        SM_LogError("EA", 0, "TimeframesCsv parsing failed");
        return INIT_PARAMETERS_INCORRECT;
    }

    if (!SM_BuildScanners())
    {
        SM_LogError("EA", 0, "No scanners were created");
        return INIT_FAILED;
    }

    g_spread_filter.Setup(InpMaxSpreadPoints);
    g_execution.Setup(InpMagicNumber, InpStopLossPoints, InpTakeProfitPoints, InpRiskPerTradePercent);

    int timer_seconds = MathMax(1, InpScanIntervalSeconds);
    EventSetTimer(timer_seconds);
    SM_CreateConfirmButton();
    SM_Log("EA", "Initialized orchestrator with scanners=" + IntegerToString(ArraySize(g_scanners)));
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    EventKillTimer();
    SM_DestroyConfirmButton();
    SM_DestroyScanners();
    Comment("");
    SM_Log("EA", "Deinitialized");
}

void OnTick()
{
    // Orchestrator runs on timer to support multi-symbol and multi-timeframe scanning.
}

void OnTimer()
{
    SM_ProcessScanners();
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if (id == CHARTEVENT_OBJECT_CLICK && sparam == g_confirm_button)
    {
        g_confirm_requested = true;
        SM_Log("UI", "Manual confirm requested");
    }
}
