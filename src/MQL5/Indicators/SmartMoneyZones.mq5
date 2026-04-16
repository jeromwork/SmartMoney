#property strict
#property indicator_chart_window
#property indicator_plots 5
#property indicator_buffers 5

#property indicator_label1 "SM_Direction"
#property indicator_type1 DRAW_NONE
#property indicator_color1 clrNONE

#property indicator_label2 "SM_Score"
#property indicator_type2 DRAW_NONE
#property indicator_color2 clrNONE

#property indicator_label3 "SM_Invalidation"
#property indicator_type3 DRAW_NONE
#property indicator_color3 clrNONE

#property indicator_label4 "SM_BuySignal"
#property indicator_type4 DRAW_ARROW
#property indicator_color4 clrLime
#property indicator_style4 STYLE_SOLID
#property indicator_width4 1

#property indicator_label5 "SM_SellSignal"
#property indicator_type5 DRAW_ARROW
#property indicator_color5 clrTomato
#property indicator_style5 STYLE_SOLID
#property indicator_width5 1

input int InpTrendPeriod = 20;
input bool InpEnableVisualObjects = true;
input bool InpShowBuyArrows = true;
input bool InpShowSellArrows = true;
input double InpArrowOffsetPoints = 20.0;
input int InpBuyArrowCode = 233;
input int InpSellArrowCode = 234;

input bool InpShowSwingLevels = true;
input bool InpShowBosMssLabels = true;
input bool InpShowFvgZones = true;
input bool InpShowVisualDebugLabel = true;
input int InpSwingLookback = 3;
input int InpHistoryBarsToDraw = 400;
input int InpMaxFvgZones = 60;
input double InpMinFvgPoints = 2.0;
input color InpBullFvgColor = clrYellow;
input color InpBearFvgColor = clrDeepPink;
input color InpSwingHighColor = clrRed;
input color InpSwingLowColor = clrAqua;
input color InpBosColor = clrOrange;
input color InpMssColor = clrMagenta;

double DirectionBuffer[];
double ScoreBuffer[];
double InvalidationBuffer[];
double BuyArrowBuffer[];
double SellArrowBuffer[];

string SMZ_Prefix()
{
    return "SMZ_" + IntegerToString((int)ChartID()) + "_";
}

int SMZ_CountObjectsByPrefix(const string prefix)
{
    int count = 0;
    int total = ObjectsTotal(0, -1, -1);
    for (int i = 0; i < total; i++)
    {
        string name = ObjectName(0, i, -1, -1);
        if (StringFind(name, prefix) == 0)
        {
            count++;
        }
    }

    return count;
}

void SMZ_ClearObjects()
{
    string prefix = SMZ_Prefix();
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

bool SMZ_DrawText(const string name, const datetime t, const double price, const string text, const color clr)
{
    if (!ObjectCreate(0, name, OBJ_TEXT, 0, t, price))
    {
        return false;
    }
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
    return ObjectFind(0, name) >= 0;
}

bool SMZ_DrawSwingLine(const string name, const datetime t1, const datetime t2, const double price, const color clr)
{
    if (!ObjectCreate(0, name, OBJ_TREND, 0, t1, price, t2, price))
    {
        return false;
    }
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
    return ObjectFind(0, name) >= 0;
}

bool SMZ_DrawFvgRect(const string name, const datetime t1, const datetime t2, const double p1, const double p2, const color clr)
{
    datetime left = (t1 < t2) ? t1 : t2;
    datetime right = (t1 < t2) ? t2 : t1;
    double top = MathMax(p1, p2);
    double bottom = MathMin(p1, p2);
    if (!ObjectCreate(0, name, OBJ_RECTANGLE, 0, left, top, right, bottom))
    {
        return false;
    }
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetInteger(0, name, OBJPROP_FILL, true);
    return ObjectFind(0, name) >= 0;
}

bool SMZ_DrawBosVertical(const string name, const datetime t, const double lowPrice, const double highPrice, const color clr)
{
    if (!ObjectCreate(0, name, OBJ_TREND, 0, t, lowPrice, t, highPrice))
    {
        return false;
    }

    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
    return ObjectFind(0, name) >= 0;
}

bool SMZ_IsSwingHigh(const int i, const int rates_total, const double &high[])
{
    int lb = MathMax(2, InpSwingLookback);
    if (i - lb < 0 || i + lb >= rates_total)
    {
        return false;
    }

    for (int k = 1; k <= lb; k++)
    {
        if (high[i] <= high[i - k] || high[i] <= high[i + k])
        {
            return false;
        }
    }

    return true;
}

bool SMZ_IsSwingLow(const int i, const int rates_total, const double &low[])
{
    int lb = MathMax(2, InpSwingLookback);
    if (i - lb < 0 || i + lb >= rates_total)
    {
        return false;
    }

    for (int k = 1; k <= lb; k++)
    {
        if (low[i] >= low[i - k] || low[i] >= low[i + k])
        {
            return false;
        }
    }

    return true;
}

int OnInit()
{
    SetIndexBuffer(0, DirectionBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, ScoreBuffer, INDICATOR_DATA);
    SetIndexBuffer(2, InvalidationBuffer, INDICATOR_DATA);
    SetIndexBuffer(3, BuyArrowBuffer, INDICATOR_DATA);
    SetIndexBuffer(4, SellArrowBuffer, INDICATOR_DATA);

    PlotIndexSetInteger(3, PLOT_ARROW, InpBuyArrowCode);
    PlotIndexSetInteger(4, PLOT_ARROW, InpSellArrowCode);
    PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);

    IndicatorSetString(INDICATOR_SHORTNAME, "SmartMoneyZones Visual");
    return INIT_SUCCEEDED;
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    ArraySetAsSeries(time, true);
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);

    int start = (prev_calculated > 0) ? (prev_calculated - 1) : 0;
    int period = MathMax(2, InpTrendPeriod);

    for (int i = start; i < rates_total; i++)
    {
        if (i + period + 1 >= rates_total)
        {
            DirectionBuffer[i] = 0.0;
            ScoreBuffer[i] = 0.0;
            InvalidationBuffer[i] = 0.0;
            BuyArrowBuffer[i] = EMPTY_VALUE;
            SellArrowBuffer[i] = EMPTY_VALUE;
            continue;
        }

        double sma = 0.0;
        for (int j = 1; j <= period; j++)
        {
            sma += close[i + j];
        }

        sma /= period;
        double body = MathAbs(close[i] - open[i]);
        double range = MathMax(high[i] - low[i], _Point);
        double score = MathMin(100.0, (body / range) * 100.0);

        double direction = 0.0;
        if (close[i] > sma && close[i] > close[i + 1])
        {
            direction = 1.0;
            InvalidationBuffer[i] = low[i];
            BuyArrowBuffer[i] = InpShowBuyArrows ? (low[i] - (InpArrowOffsetPoints * _Point)) : EMPTY_VALUE;
            SellArrowBuffer[i] = EMPTY_VALUE;
        }
        else if (close[i] < sma && close[i] < close[i + 1])
        {
            direction = -1.0;
            InvalidationBuffer[i] = high[i];
            SellArrowBuffer[i] = InpShowSellArrows ? (high[i] + (InpArrowOffsetPoints * _Point)) : EMPTY_VALUE;
            BuyArrowBuffer[i] = EMPTY_VALUE;
        }
        else
        {
            InvalidationBuffer[i] = 0.0;
            BuyArrowBuffer[i] = EMPTY_VALUE;
            SellArrowBuffer[i] = EMPTY_VALUE;
        }

        DirectionBuffer[i] = direction;
        ScoreBuffer[i] = score;
    }

    if (!InpEnableVisualObjects)
    {
        return rates_total;
    }

    static datetime last_visual_bar = 0;
    if (prev_calculated > 0 && time[0] == last_visual_bar)
    {
        return rates_total;
    }
    last_visual_bar = time[0];

    SMZ_ClearObjects();

    int maxBars = MathMin(rates_total - 5, MathMax(50, InpHistoryBarsToDraw));
    double lastSwingHigh = 0.0;
    double lastSwingLow = 0.0;
    int structureDir = 0;
    int fvgCount = 0;
    int swingCount = 0;
    int bosCount = 0;
    int drawFailCount = 0;

    for (int i = maxBars; i >= 2; i--)
    {
        if (InpShowSwingLevels && SMZ_IsSwingHigh(i, rates_total, high))
        {
            lastSwingHigh = high[i];
            string ln = SMZ_Prefix() + "SW_H_" + IntegerToString(i);
            datetime t2 = (i - 1 >= 0) ? time[i - 1] : time[i];
            if (!SMZ_DrawSwingLine(ln, time[i], t2, high[i], InpSwingHighColor)) { drawFailCount++; }
            if (!SMZ_DrawText(SMZ_Prefix() + "SWH_TXT_" + IntegerToString(i), time[i], high[i], "SWH", InpSwingHighColor)) { drawFailCount++; }
            swingCount++;
        }

        if (InpShowSwingLevels && SMZ_IsSwingLow(i, rates_total, low))
        {
            lastSwingLow = low[i];
            string ln = SMZ_Prefix() + "SW_L_" + IntegerToString(i);
            datetime t2 = (i - 1 >= 0) ? time[i - 1] : time[i];
            if (!SMZ_DrawSwingLine(ln, time[i], t2, low[i], InpSwingLowColor)) { drawFailCount++; }
            if (!SMZ_DrawText(SMZ_Prefix() + "SWL_TXT_" + IntegerToString(i), time[i], low[i], "SWL", InpSwingLowColor)) { drawFailCount++; }
            swingCount++;
        }

        if (InpShowBosMssLabels)
        {
            if (lastSwingHigh > 0.0 && close[i] > lastSwingHigh && close[i + 1] <= lastSwingHigh)
            {
                bool isMss = (structureDir < 0);
                structureDir = 1;
                string label = isMss ? "MSS Up" : "BOS Up";
                color clr = isMss ? InpMssColor : InpBosColor;
                double y = high[i] + (InpArrowOffsetPoints * _Point);
                if (!SMZ_DrawText(SMZ_Prefix() + "BOSUP_" + IntegerToString(i), time[i], y, label, clr)) { drawFailCount++; }
                if (!SMZ_DrawBosVertical(SMZ_Prefix() + "BOSUP_V_" + IntegerToString(i), time[i], low[i], high[i], clr)) { drawFailCount++; }
                bosCount++;
            }

            if (lastSwingLow > 0.0 && close[i] < lastSwingLow && close[i + 1] >= lastSwingLow)
            {
                bool isMss = (structureDir > 0);
                structureDir = -1;
                string label = isMss ? "MSS Down" : "BOS Down";
                color clr = isMss ? InpMssColor : InpBosColor;
                double y = low[i] - (InpArrowOffsetPoints * _Point);
                if (!SMZ_DrawText(SMZ_Prefix() + "BOSDN_" + IntegerToString(i), time[i], y, label, clr)) { drawFailCount++; }
                if (!SMZ_DrawBosVertical(SMZ_Prefix() + "BOSDN_V_" + IntegerToString(i), time[i], low[i], high[i], clr)) { drawFailCount++; }
                bosCount++;
            }
        }

        if (InpShowFvgZones && fvgCount < InpMaxFvgZones && i + 2 < rates_total)
        {
            double minGap = InpMinFvgPoints * _Point;
            if (low[i] > high[i + 2] && (low[i] - high[i + 2]) >= minGap)
            {
                string name = SMZ_Prefix() + "FVG_B_" + IntegerToString(i);
                if (!SMZ_DrawFvgRect(name, time[i + 2], time[i], low[i], high[i + 2], InpBullFvgColor)) { drawFailCount++; }
                if (!SMZ_DrawText(name + "_TXT", time[i], low[i], "FVG Bull", InpBullFvgColor)) { drawFailCount++; }
                fvgCount++;
            }
            else if (high[i] < low[i + 2] && (low[i + 2] - high[i]) >= minGap)
            {
                string name = SMZ_Prefix() + "FVG_S_" + IntegerToString(i);
                if (!SMZ_DrawFvgRect(name, time[i + 2], time[i], low[i + 2], high[i], InpBearFvgColor)) { drawFailCount++; }
                if (!SMZ_DrawText(name + "_TXT", time[i], high[i], "FVG Bear", InpBearFvgColor)) { drawFailCount++; }
                fvgCount++;
            }
        }
    }

    if (InpShowVisualDebugLabel)
    {
        string dbg = SMZ_Prefix() + "DBG";
        ObjectCreate(0, dbg, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, dbg, OBJPROP_XDISTANCE, 12);
        ObjectSetInteger(0, dbg, OBJPROP_YDISTANCE, 20);
        ObjectSetInteger(0, dbg, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, dbg, OBJPROP_FONTSIZE, 9);
        int totalVisualObjects = SMZ_CountObjectsByPrefix(SMZ_Prefix());
        ObjectSetString(0, dbg, OBJPROP_TEXT, "SMZ visual: swings=" + IntegerToString(swingCount) + " bos/mss=" + IntegerToString(bosCount) + " fvg=" + IntegerToString(fvgCount) + " drawFail=" + IntegerToString(drawFailCount) + " objects=" + IntegerToString(totalVisualObjects));
    }

    ChartRedraw(0);

    static datetime lastLogBar = 0;
    if (time[0] != lastLogBar)
    {
        lastLogBar = time[0];
        Print("[SMZ] bars=", IntegerToString(rates_total),
              " swings=", IntegerToString(swingCount),
              " bosMss=", IntegerToString(bosCount),
              " fvg=", IntegerToString(fvgCount),
              " drawFail=", IntegerToString(drawFailCount));
    }

    return rates_total;
}
