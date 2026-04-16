#property strict
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_color1 DodgerBlue

double ZoneBuffer[];

int OnInit()
{
    SetIndexBuffer(0, ZoneBuffer);
    SetIndexStyle(0, DRAW_LINE);
    IndicatorShortName("SmartMoneyZones");
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
