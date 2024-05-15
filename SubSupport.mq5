//+------------------------------------------------------------------+
//|                                                      Support.mq5 |
//|                                                      Daniel Jose |
//+------------------------------------------------------------------+
#property copyright "Daniel Jose 25-01-2021 (A)"
#property version   "1.00"
#property description "Este arquivo serve apenas como Suporte ao Indicador em SubWin"
#property indicator_chart_window
#property indicator_plots 0
//+------------------------------------------------------------------+
int OnInit()
{
	return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const int begin, const double &price[])
{
	return rates_total;
}
//+------------------------------------------------------------------+
