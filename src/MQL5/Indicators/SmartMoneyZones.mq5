#property strict
#property indicator_chart_window
#property indicator_plots 1
#property indicator_buffers 1
#property indicator_label1 "SmartMoneyZones"
#property indicator_type1 DRAW_LINE
#property indicator_color1 clrDodgerBlue

double ZoneBuffer[];

int OnInit()
{
    SetIndexBuffer(0, ZoneBuffer, INDICATOR_DATA);
    PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_LINE);
    IndicatorSetString(INDICATOR_SHORTNAME, "SmartMoneyZones");
    return(INIT_SUCCEEDED);
}

int OnCalculate(
    const int rates_total,
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
    int start = prev_calculated > 0 ? prev_calculated - 1 : 0;
    for (int i = start; i < rates_total; i++)
    {
        ZoneBuffer[i] = close[i];
    }

    return(rates_total);
}
