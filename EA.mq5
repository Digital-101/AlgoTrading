//+------------------------------------------------------------------+
//|                                            EA with SubWindow.mq5 |
//|                                                      Daniel Jose |
//| 			                                    							|
//+------------------------------------------------------------------+
#property copyright "Daniel Jose"
#property icon "Resources\\Robot.ico"
#property version   "1.06"
#property description "Nano Expert Advisor"
#property description "Adjust the desired leverage level."
#property description "To facilitate TakeProfit and StopLoss are financial values."
#property description "Press SHIFT to buy using mouse."
#property description "Press CTRL to sell using the mouse."
//+------------------------------------------------------------------+
#define def_Resource "Resources\\SubSupport.ex5"
//+------------------------------------------------------------------+
#resource def_Resource
//+------------------------------------------------------------------+
#include <NanoEA-SIMD\SubWindow\C_SubWindow.mqh>
#include <NanoEA-SIMD\Trade Control\C_OrderView.mqh>
#include <NanoEA-SIMD\Auxiliar\C_Wallpaper.mqh>
#include <NanoEA-SIMD\Tape Reading\C_VolumeAtPrice.mqh>
//+------------------------------------------------------------------+
input group "Window Indicators"
input string 						user01 = "";							//Indicadores a usar
input string 						user02 = "";  							//Ativos a acompanhar
input group "WallPaper"
input string 						user03 = "Wallpaper_01";			//BitMap a ser usado
input char							user04 = 60;							//Transparencia (0 a 100)
input C_WallPaper::eTypeImage	user05 = C_WallPaper::IMAGEM;		//Tipo de imagem de fundo
input group "Chart Trader"
input int   						user06   = 1;                 	//Fator de alavancagem
input int   						user07   = 100;               	//Take Profit ( FINANCEIRO )
input int   						user08   = 75;                	//Stop Loss ( FINANCEIRO )
input color 						user09   = clrBlue;           	//Cor da linha de Preço
input color 						user10   = clrForestGreen;    	//Cor da linha Take Profit
input color 						user11   = clrFireBrick;      	//Cor da linha Stop
input bool  						user12   = true;              	//Day Trade ?
input group "Volume At Price"
input color							user15	= clrBlack;					//Cor das barras
input	char							user16	= 20;							//Transparencia (0 a 100 )
//+------------------------------------------------------------------+
C_SubWindow 		SubWin;
C_WallPaper 		WallPaper;
C_VolumeAtPrice 	VolumeAtPrice;
//+------------------------------------------------------------------+		
int OnInit()
{
	Terminal.Init();
	WallPaper.Init(user03, user05, user04);
	if ((user01 == "") && (user02 == "")) SubWin.Close(); else if (SubWin.Init())
	{
		SubWin.ClearTemplateChart();
		SubWin.AddThese(C_TemplateChart::SYMBOL, user02);
		SubWin.AddThese(C_TemplateChart::INDICATOR, user01);
	}
	SubWin.InitilizeChartTrade(user06, user07, user08, user09, user10, user11, user12);
	VolumeAtPrice.Init(user10, user11, user15, user16);
   OnTrade();
	EventSetTimer(1);
   
	return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
	EventKillTimer();
	SubWin.ClearTemplateChart();
	SubWin.Close();
}
//+------------------------------------------------------------------+
void OnTick()
{
	SubWin.DispatchMessage(CHARTEVENT_CHART_CHANGE, C_Chart_IDE::szMsgIDE[C_Chart_IDE::eRESULT], NanoEA.CheckPosition());
}
//+------------------------------------------------------------------+
void OnTrade()
{
	SubWin.DispatchMessage(CHARTEVENT_CHART_CHANGE, C_Chart_IDE::szMsgIDE[C_Chart_IDE::eROOF_DIARY], NanoEA.UpdateRoof());
	NanoEA.UpdatePosition();
}
//+------------------------------------------------------------------+
void OnTimer()
{
	VolumeAtPrice.Update();
}
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
	VolumeAtPrice.DispatchMessage(id, sparam);
	switch (id)
	{
		case CHARTEVENT_OBJECT_ENDEDIT:
		case CHARTEVENT_OBJECT_CLICK:
			SubWin.DispatchMessage(id, sparam);
			break;
		case CHARTEVENT_CHART_CHANGE:
			Terminal.Resize();
      	SubWin.Resize();
			WallPaper.Resize();
			VolumeAtPrice.Resize();
      	break;
		case CHARTEVENT_MOUSE_MOVE:
			NanoEA.MoveTo((int)lparam, (int)dparam, (uint)sparam);
			ChartRedraw();
			break;
	}
}
//+------------------------------------------------------------------+
