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
input bool InpShowDashboard = true;
input int InpDashboardX = 15;
input int InpDashboardY = 70;
input int InpDashboardWidth = 420;
input int InpDashboardRowHeight = 20;
input bool InpShowChartSignalMarkers = true;
input int InpIndicatorTrendPeriod = 20;
input bool InpIndicatorShowBuyArrows = true;
input bool InpIndicatorShowSellArrows = true;
input double InpIndicatorArrowOffsetPoints = 20.0;
input int InpIndicatorBuyArrowCode = 233;
input int InpIndicatorSellArrowCode = 234;

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
string g_dash_prefix = "SM_DASH_";
int g_indicator_handles[];

struct SMScannerState
{
    string symbol;
    ENUM_TIMEFRAMES timeframe;
    string status;
    color status_color;
    double score;
    int direction;
    datetime last_update;
};

SMScannerState g_scanner_states[];

void SM_RegisterIndicatorHandle(const int handle)
{
    if (handle == INVALID_HANDLE)
    {
        return;
    }

    int next = ArraySize(g_indicator_handles);
    ArrayResize(g_indicator_handles, next + 1);
    g_indicator_handles[next] = handle;
}

bool SM_AttachIndicatorToChart(const long chart_id, const string symbol, const ENUM_TIMEFRAMES timeframe)
{
    int handle = iCustom(symbol,
                         timeframe,
                         "SmartMoneyZones",
                         InpIndicatorTrendPeriod,
                         true,
                         InpIndicatorShowBuyArrows,
                         InpIndicatorShowSellArrows,
                         InpIndicatorArrowOffsetPoints,
                         InpIndicatorBuyArrowCode,
                         InpIndicatorSellArrowCode);
    if (handle == INVALID_HANDLE)
    {
        SM_LogError("UI", GetLastError(), "Cannot create SmartMoneyZones handle for " + symbol + " " + SM_TimeframeToString(timeframe));
        return false;
    }

    bool attached = false;
    for (int attempt = 0; attempt < 10; attempt++)
    {
        if (ChartIndicatorAdd(chart_id, 0, handle))
        {
            attached = true;
            break;
        }

        Sleep(50);
    }

    if (!attached)
    {
        SM_LogError("UI", GetLastError(), "Cannot attach SmartMoneyZones to chart");
        IndicatorRelease(handle);
        return false;
    }

    SM_RegisterIndicatorHandle(handle);
    return true;
}

void SM_ClearObjectsByPrefix(const string prefix)
{
    int total = ObjectsTotal(0, -1, -1);
    for (int i = total - 1; i >= 0; i--)
    {
        string name = ObjectName(0, i, -1, -1);
        if (StringFind(name, prefix) == 0)
        {
            ObjectDelete(0, name);
        }
    }
}

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
    ObjectSetInteger(0, g_confirm_button, OBJPROP_XDISTANCE, InpDashboardX);
    ObjectSetInteger(0, g_confirm_button, OBJPROP_YDISTANCE, 30);
    ObjectSetInteger(0, g_confirm_button, OBJPROP_XSIZE, 190);
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

void SM_UpdateScannerState(const int index,
                           const string status,
                           const color status_color,
                           const int direction,
                           const double score)
{
    if (index < 0 || index >= ArraySize(g_scanner_states))
    {
        return;
    }

    g_scanner_states[index].status = status;
    g_scanner_states[index].status_color = status_color;
    g_scanner_states[index].direction = direction;
    g_scanner_states[index].score = score;
    g_scanner_states[index].last_update = TimeCurrent();
}

void SM_DrawDashboard()
{
    if (!InpShowDashboard)
    {
        SM_ClearObjectsByPrefix(g_dash_prefix);
        return;
    }

    SM_ClearObjectsByPrefix(g_dash_prefix);

    string headerName = g_dash_prefix + "HEADER";
    ObjectCreate(0, headerName, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, headerName, OBJPROP_XDISTANCE, InpDashboardX);
    ObjectSetInteger(0, headerName, OBJPROP_YDISTANCE, InpDashboardY);
    ObjectSetInteger(0, headerName, OBJPROP_COLOR, clrDeepSkyBlue);
    ObjectSetString(0, headerName, OBJPROP_TEXT, "SmartMoney Dashboard (click row to open chart)");

    int y = InpDashboardY + 18;
    for (int i = 0; i < ArraySize(g_scanner_states); i++)
    {
        string rowName = g_dash_prefix + "ROW_" + IntegerToString(i);
        string rowText = g_scanner_states[i].symbol + " " + SM_TimeframeToString(g_scanner_states[i].timeframe) +
            " | " + g_scanner_states[i].status +
            " | score=" + DoubleToString(g_scanner_states[i].score, 1);

        ObjectCreate(0, rowName, OBJ_BUTTON, 0, 0, 0);
        ObjectSetInteger(0, rowName, OBJPROP_XDISTANCE, InpDashboardX);
        ObjectSetInteger(0, rowName, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, rowName, OBJPROP_XSIZE, InpDashboardWidth);
        ObjectSetInteger(0, rowName, OBJPROP_YSIZE, InpDashboardRowHeight);
        ObjectSetInteger(0, rowName, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, rowName, OBJPROP_BGCOLOR, g_scanner_states[i].status_color);
        ObjectSetString(0, rowName, OBJPROP_TEXT, rowText);

        y += InpDashboardRowHeight + 2;
    }
}

void SM_DrawSignalMarker(const SM_SignalContext &context)
{
    if (!InpShowChartSignalMarkers)
    {
        return;
    }

    if (context.symbol != _Symbol || context.timeframe != _Period)
    {
        return;
    }

    datetime signal_time = iTime(_Symbol, _Period, 1);
    if (signal_time <= 0)
    {
        signal_time = TimeCurrent();
    }

    double price = 0.0;
    if (context.direction > 0)
    {
        price = iLow(_Symbol, _Period, 1) - (2.0 * _Point);
    }
    else
    {
        price = iHigh(_Symbol, _Period, 1) + (2.0 * _Point);
    }

    string markerName = "SM_SIGNAL_" + IntegerToString((int)signal_time) + "_" + IntegerToString(context.direction);
    if (ObjectFind(0, markerName) >= 0)
    {
        return;
    }

    ObjectCreate(0, markerName, OBJ_ARROW, 0, signal_time, price);
    ObjectSetInteger(0, markerName, OBJPROP_COLOR, (context.direction > 0) ? clrLime : clrTomato);
    ObjectSetInteger(0, markerName, OBJPROP_ARROWCODE, (context.direction > 0) ? 233 : 234);
    ObjectSetInteger(0, markerName, OBJPROP_WIDTH, 1);

    string textName = markerName + "_TXT";
    ObjectCreate(0, textName, OBJ_TEXT, 0, signal_time, price);
    ObjectSetString(0, textName, OBJPROP_TEXT, "SM " + DoubleToString(context.score, 1));
    ObjectSetInteger(0, textName, OBJPROP_COLOR, (context.direction > 0) ? clrLime : clrTomato);
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
    ArrayResize(g_scanner_states, 0);
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
                                   InpScoreThreshold,
                                   InpIndicatorTrendPeriod,
                                   InpIndicatorShowBuyArrows,
                                   InpIndicatorShowSellArrows,
                                   InpIndicatorArrowOffsetPoints,
                                   InpIndicatorBuyArrowCode,
                                   InpIndicatorSellArrowCode);
            if (!ok)
            {
                delete scanner;
                SM_Log("EA", "Provider init skipped for " + g_symbols[s] + " " + SM_TimeframeToString(g_timeframes[t]));
                continue;
            }

            int next = ArraySize(g_scanners);
            ArrayResize(g_scanners, next + 1);
            g_scanners[next] = scanner;

            ArrayResize(g_scanner_states, next + 1);
            g_scanner_states[next].symbol = g_symbols[s];
            g_scanner_states[next].timeframe = g_timeframes[t];
            g_scanner_states[next].status = "WAIT";
            g_scanner_states[next].status_color = clrDimGray;
            g_scanner_states[next].score = 0.0;
            g_scanner_states[next].direction = 0;
            g_scanner_states[next].last_update = 0;
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

void SM_OpenVisualChart(const int index)
{
    if (index < 0 || index >= ArraySize(g_scanner_states))
    {
        return;
    }

    string symbol = g_scanner_states[index].symbol;
    ENUM_TIMEFRAMES timeframe = g_scanner_states[index].timeframe;

    long chart_id = ChartOpen(symbol, timeframe);
    if (chart_id == 0)
    {
        SM_LogError("UI", GetLastError(), "ChartOpen failed for " + symbol + " " + SM_TimeframeToString(timeframe));
        return;
    }

    if (SM_AttachIndicatorToChart(chart_id, symbol, timeframe))
    {
        SM_Log("UI", "Opened visual chart: " + symbol + " " + SM_TimeframeToString(timeframe));
    }
}

void SM_ProcessScanners()
{
    string status = "";
    for (int i = 0; i < ArraySize(g_scanners); i++)
    {
        SM_SignalContext context;
        context.valid = false;
        bool bar_updated = false;
        bool has_signal = g_scanners[i].Scan(context, bar_updated);

        if (!bar_updated)
        {
            continue;
        }

        if (!has_signal)
        {
            SM_UpdateScannerState(i, "WAIT", clrDimGray, 0, 0.0);
            continue;
        }

        string filter_reason;
        if (!g_spread_filter.Allow(context, filter_reason))
        {
            SM_UpdateScannerState(i, "FILTER:" + filter_reason, clrGoldenrod, context.direction, context.score);
            SM_Log("FILTER", context.symbol + " " + SM_TimeframeToString(context.timeframe) + " rejected: " + filter_reason);
            continue;
        }

        string signal_state = (context.direction > 0) ? "SIGNAL_BUY" : "SIGNAL_SELL";
        color signal_color = (context.direction > 0) ? clrForestGreen : clrFireBrick;
        SM_UpdateScannerState(i, signal_state, signal_color, context.direction, context.score);

        status = "Last signal: " + context.symbol + " " + SM_TimeframeToString(context.timeframe) + " dir=" + IntegerToString(context.direction) + " score=" + DoubleToString(context.score, 1);
        SM_Log("SIGNAL", status + " reasons=" + context.reasons);
        SM_DrawSignalMarker(context);

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

    SM_DrawDashboard();
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
    SM_AttachIndicatorToChart(ChartID(), _Symbol, _Period);
    SM_DrawDashboard();
    SM_Log("EA", "Initialized orchestrator with scanners=" + IntegerToString(ArraySize(g_scanners)));
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    EventKillTimer();
    SM_DestroyConfirmButton();
    SM_ClearObjectsByPrefix(g_dash_prefix);
    SM_DestroyScanners();

    for (int i = 0; i < ArraySize(g_indicator_handles); i++)
    {
        if (g_indicator_handles[i] != INVALID_HANDLE)
        {
            IndicatorRelease(g_indicator_handles[i]);
        }
    }

    ArrayResize(g_indicator_handles, 0);
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
        return;
    }

    string row_prefix = g_dash_prefix + "ROW_";
    if (id == CHARTEVENT_OBJECT_CLICK && StringFind(sparam, row_prefix) == 0)
    {
        string idx_str = StringSubstr(sparam, StringLen(row_prefix));
        int index = (int)StringToInteger(idx_str);
        SM_OpenVisualChart(index);
    }
}
