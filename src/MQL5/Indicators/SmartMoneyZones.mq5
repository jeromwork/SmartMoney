#property strict
#property indicator_chart_window
#property indicator_plots 3
#property indicator_buffers 3

#property indicator_label1 "SM_Direction"
#property indicator_type1 DRAW_NONE
#property indicator_color1 clrNONE

#property indicator_label2 "SM_Score"
#property indicator_type2 DRAW_NONE
#property indicator_color2 clrNONE

#property indicator_label3 "SM_Invalidation"
#property indicator_type3 DRAW_NONE
#property indicator_color3 clrNONE

double DirectionBuffer[];
double ScoreBuffer[];
double InvalidationBuffer[];

int OnInit()
{
    SetIndexBuffer(0, DirectionBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, ScoreBuffer, INDICATOR_DATA);
    SetIndexBuffer(2, InvalidationBuffer, INDICATOR_DATA);

    IndicatorSetString(INDICATOR_SHORTNAME, "SmartMoneyZonesFeatures");
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
    int start = (prev_calculated > 0) ? (prev_calculated - 1) : 0;

    for (int i = start; i < rates_total; i++)
    {
        if (i + 21 >= rates_total)
        {
            DirectionBuffer[i] = 0.0;
            ScoreBuffer[i] = 0.0;
            InvalidationBuffer[i] = 0.0;
            continue;
        }

        double sma = 0.0;
        for (int j = 1; j <= 20; j++)
        {
            sma += close[i + j];
        }

        sma /= 20.0;
        double body = MathAbs(close[i] - open[i]);
        double range = MathMax(high[i] - low[i], _Point);
        double score = MathMin(100.0, (body / range) * 100.0);

        double direction = 0.0;
        if (close[i] > sma && close[i] > close[i + 1])
        {
            direction = 1.0;
            InvalidationBuffer[i] = low[i];
        }
        else if (close[i] < sma && close[i] < close[i + 1])
        {
            direction = -1.0;
            InvalidationBuffer[i] = high[i];
        }
        else
        {
            InvalidationBuffer[i] = 0.0;
        }

        DirectionBuffer[i] = direction;
        ScoreBuffer[i] = score;
    }

    return rates_total;
}
