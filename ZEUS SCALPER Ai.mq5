//+------------------------------------------------------------------+
//|                                              ZEUS SCALPER Ai.mq5 |
//|                                     Copyright 2026, CYCLONE POSH |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, CYCLONE POSH"
#property link      "https://www.mql5.com"
#property version   "1.03"
//+------------------------------------------------------------------+
//| Include                                                          |
//+------------------------------------------------------------------+
#include <Expert\Expert.mqh>
//--- available signals
#include <Expert\Signal\SignalMA.mqh>
#include <Expert\Signal\SignalBullsPower.mqh>
#include <Expert\Signal\SignalBearsPower.mqh>
#include <Expert\Signal\SignalStoch.mqh>
//--- available trailing
#include <Expert\Trailing\TrailingNone.mqh>
//--- available money management
#include <Expert\Money\MoneyFixedLot.mqh>
//--- Trade class
#include <Trade\Trade.mqh>
//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
//--- inputs for expert
input string             Expert_Title                 ="ZEUS SCALPER Ai"; // Document name
ulong                    Expert_MagicNumber           =53927483;          //
bool                     Expert_EveryTick             =false;             //
//--- inputs for dashboard
input bool               ShowDashboard                =true;              // Show trading dashboard
input color              DashboardColor               =clrWhite;          // Dashboard text color
input int                DashboardX                   =10;                // Dashboard X position
input int                DashboardY                   =20;                // Dashboard Y position
input int                DashboardFontSize            =10;                // Dashboard font size
//--- inputs for main signal - IMPROVED THRESHOLDS
input int                Signal_ThresholdOpen         =40;                // Signal threshold value to open [0...100] - INCREASED for quality
input int                Signal_ThresholdClose        =25;                // Signal threshold value to close [0...100]
input double             Signal_PriceLevel            =0.0;               // Price level to execute a deal
input double             Signal_StopLevel             =2550.0;              // Stop Loss level (in points)
input double             Signal_TakeLevel             =3550.0;              // Take Profit level (in points)
input int                Signal_Expiration            =4;                 // Expiration of pending orders (in bars)
//--- MA Filter 1 (Trend Direction - 200 EMA)
input int                Signal_0_MA_PeriodMA         =200;               // Moving Average(200,0,...) Period of averaging
input int                Signal_0_MA_Shift            =0;                 // Moving Average(200,0,...) Time shift
input ENUM_MA_METHOD     Signal_0_MA_Method           =MODE_EMA;          // Moving Average(200,0,...) Method of averaging
input ENUM_APPLIED_PRICE Signal_0_MA_Applied          =PRICE_CLOSE;       // Moving Average(200,0,...) Prices series
input double             Signal_0_MA_Weight           =0.28;              // Moving Average(200,0,...) Weight [0...1.0] - ADJUSTED
//--- MA Filter 2 (Entry Confirmation - 50 EMA)
input int                Signal_1_MA_PeriodMA         =50;                // Moving Average(50,0,...) Period of averaging
input int                Signal_1_MA_Shift            =0;                 // Moving Average(50,0,...) Time shift
input ENUM_MA_METHOD     Signal_1_MA_Method           =MODE_EMA;          // Moving Average(50,0,...) Method of averaging
input ENUM_APPLIED_PRICE Signal_1_MA_Applied          =PRICE_CLOSE;       // Moving Average(50,0,...) Prices series
input double             Signal_1_MA_Weight           =0.32;              // Moving Average(50,0,...) Weight [0...1.0] - INCREASED for entry confirmation
//--- Bulls Power (Uptrend Momentum)
input int                Signal_BullsPower_PeriodBulls=13;                // Bulls Power(13) Period of calculation
input double             Signal_BullsPower_Weight     =0.20;              // Bulls Power(13) Weight [0...1.0] - INCREASED
//--- Bears Power (Downtrend Momentum)
input int                Signal_BearsPower_PeriodBears=13;                // Bears Power(13) Period of calculation
input double             Signal_BearsPower_Weight     =0.20;              // Bears Power(13) Weight [0...1.0] - INCREASED
//--- Stochastic (Confirmation of Momentum)
input int                Signal_Stoch_PeriodK         =14;                // Stochastic(14,3,3,...) K-period
input int                Signal_Stoch_PeriodD         =3;                 // Stochastic(14,3,3,...) D-period
input int                Signal_Stoch_PeriodSlow      =3;                 // Stochastic(14,3,3,...) Period of slowing
input ENUM_STO_PRICE     Signal_Stoch_Applied         =STO_LOWHIGH;       // Stochastic(14,3,3,...) Prices to apply to
input double             Signal_Stoch_Weight          =0.20;              // Stochastic(14,3,3,...) Weight [0...1.0] - INCREASED
//--- money
input double             Money_FixLot_Percent         =10.0;              // Percent
input double             Money_FixLot_Lots            =0.1;               // Fixed volume
//+------------------------------------------------------------------+
//| Global expert object                                             |
//+------------------------------------------------------------------+
CExpert ExtExpert;
int totalTrades = 0;
int winningTrades = 0;
double totalProfit = 0.0;
datetime lastTradeTime = 0;
//+------------------------------------------------------------------+
//| Function to generate trade comment                               |
//+------------------------------------------------------------------+
string GetTradeComment() {
   string comment = "";
   comment = "ZEUS SCALPER Ai";
   return comment;
}
//+------------------------------------------------------------------+
//| Function to update trading statistics                            |
//+------------------------------------------------------------------+
void UpdateTradingStats() {
   totalTrades = 0;
   winningTrades = 0;
   totalProfit = 0.0;
   
   // Count positions and trades from history
   int deals = HistoryDealsTotal();
   
   for(int i = 0; i < deals; i++) {
      ulong ticket = HistoryDealGetTicket(i);
      
      if(ticket > 0) {
         // Check if deal belongs to this EA
         ulong magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
         
         if(magic == Expert_MagicNumber) {
            ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
            
            // Count completed deals
            if(dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL) {
               totalTrades++;
               double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
               totalProfit += profit;
               
               if(profit > 0) {
                  winningTrades++;
               }
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
//| Function to draw text dashboard                                  |
//+------------------------------------------------------------------+
void DrawDashboard() {
   if(!ShowDashboard) return;
   
   UpdateTradingStats();
   
   string dashboardText = "";
   dashboardText += "╔════════════════════════════════════╗\n";
   dashboardText += "║    ZEUS SCALPER Ai - DASHBOARD    ║\n";
   dashboardText += "╠════════════════════════════════════╣\n";
   dashboardText += "║ Symbol: " + Symbol() + "\n";
   dashboardText += "║ Timeframe: " + IntegerToString(Period()) + " min\n";
   dashboardText += "║ Price: " + DoubleToString(SymbolInfoDouble(Symbol(), SYMBOL_ASK), 5) + "\n";
   dashboardText += "╠════════════════════════════════════╣\n";
   dashboardText += "║ SIGNAL SETTINGS\n";
   dashboardText += "║ Open Threshold: " + IntegerToString(Signal_ThresholdOpen) + "%\n";
   dashboardText += "║ Close Threshold: " + IntegerToString(Signal_ThresholdClose) + "%\n";
   dashboardText += "║ Stop Loss: " + DoubleToString(Signal_StopLevel, 0) + " pts\n";
   dashboardText += "║ Take Profit: " + DoubleToString(Signal_TakeLevel, 0) + " pts\n";
   dashboardText += "╠════════════════════════════════════╣\n";
   dashboardText += "║ INDICATOR WEIGHTS\n";
   dashboardText += "║ MA(200): " + DoubleToString(Signal_0_MA_Weight, 2) + " | ";
   dashboardText += "MA(50): " + DoubleToString(Signal_1_MA_Weight, 2) + "\n";
   dashboardText += "║ Bulls: " + DoubleToString(Signal_BullsPower_Weight, 2) + " | ";
   dashboardText += "Bears: " + DoubleToString(Signal_BearsPower_Weight, 2) + "\n";
   dashboardText += "║ Stoch: " + DoubleToString(Signal_Stoch_Weight, 2) + "\n";
   dashboardText += "╠════════════════════════════════════╣\n";
   dashboardText += "║ TRADING STATISTICS\n";
   dashboardText += "║ Total Trades: " + IntegerToString(totalTrades) + "\n";
   dashboardText += "║ Winning: " + IntegerToString(winningTrades) + " | ";
   dashboardText += "Losing: " + IntegerToString(totalTrades - winningTrades) + "\n";
   
   double winRate = (totalTrades > 0) ? (double)winningTrades / totalTrades * 100 : 0;
   dashboardText += "║ Win Rate: " + DoubleToString(winRate, 1) + "%\n";
   dashboardText += "║ Total P&L: " + DoubleToString(totalProfit, 2) + " $\n";
   dashboardText += "╠════════════════════════════════════╣\n";
   dashboardText += "║ STATUS: " + (PositionsTotal() > 0 ? "IN TRADE" : "WAITING") + "\n";
   dashboardText += "╚════════════════════════════════════╝\n";
   
   // Draw the dashboard using Comment function
   Comment(dashboardText);
}
//+------------------------------------------------------------------+
//| Initialization function of the expert                            |
//+------------------------------------------------------------------+
int OnInit() {
//--- Initializing expert
   if(!ExtExpert.Init(Symbol(),Period(),Expert_EveryTick,Expert_MagicNumber)) {
      //--- failed
      printf(__FUNCTION__+": error initializing expert");
      ExtExpert.Deinit();
      return(INIT_FAILED);
   }
//--- Creating signal
   CExpertSignal *signal=new CExpertSignal;
   if(signal==NULL) {
      //--- failed
      printf(__FUNCTION__+": error creating signal");
      ExtExpert.Deinit();
      return(INIT_FAILED);
   }
//---
   ExtExpert.InitSignal(signal);
   signal.ThresholdOpen(Signal_ThresholdOpen);
   signal.ThresholdClose(Signal_ThresholdClose);
   signal.PriceLevel(Signal_PriceLevel);
   signal.StopLevel(Signal_StopLevel);
   signal.TakeLevel(Signal_TakeLevel);
   signal.Expiration(Signal_Expiration);
//--- Creating filter CSignalMA (Trend Filter - 200 EMA)
   CSignalMA *filter0=new CSignalMA;
   if(filter0==NULL) {
      //--- failed
      printf(__FUNCTION__+": error creating filter0");
      ExtExpert.Deinit();
      return(INIT_FAILED);
   }
   signal.AddFilter(filter0);
//--- Set filter parameters
   filter0.PeriodMA(Signal_0_MA_PeriodMA);
   filter0.Shift(Signal_0_MA_Shift);
   filter0.Method(Signal_0_MA_Method);
   filter0.Applied(Signal_0_MA_Applied);
   filter0.Weight(Signal_0_MA_Weight);
//--- Creating filter CSignalMA (Entry Confirmation - 50 EMA)
   CSignalMA *filter1=new CSignalMA;
   if(filter1==NULL) {
      //--- failed
      printf(__FUNCTION__+": error creating filter1");
      ExtExpert.Deinit();
      return(INIT_FAILED);
   }
   signal.AddFilter(filter1);
//--- Set filter parameters
   filter1.PeriodMA(Signal_1_MA_PeriodMA);
   filter1.Shift(Signal_1_MA_Shift);
   filter1.Method(Signal_1_MA_Method);
   filter1.Applied(Signal_1_MA_Applied);
   filter1.Weight(Signal_1_MA_Weight);
//--- Creating filter CSignalBullsPower
   CSignalBullsPower *filter2=new CSignalBullsPower;
   if(filter2==NULL) {
      //--- failed
      printf(__FUNCTION__+": error creating filter2");
      ExtExpert.Deinit();
      return(INIT_FAILED);
   }
   signal.AddFilter(filter2);
//--- Set filter parameters
   filter2.PeriodBulls(Signal_BullsPower_PeriodBulls);
   filter2.Weight(Signal_BullsPower_Weight);
//--- Creating filter CSignalBearsPower
   CSignalBearsPower *filter3=new CSignalBearsPower;
   if(filter3==NULL) {
      //--- failed
      printf(__FUNCTION__+": error creating filter3");
      ExtExpert.Deinit();
      return(INIT_FAILED);
   }
   signal.AddFilter(filter3);
//--- Set filter parameters
   filter3.PeriodBears(Signal_BearsPower_PeriodBears);
   filter3.Weight(Signal_BearsPower_Weight);
//--- Creating filter CSignalStoch
   CSignalStoch *filter4=new CSignalStoch;
   if(filter4==NULL) {
      //--- failed
      printf(__FUNCTION__+": error creating filter4");
      ExtExpert.Deinit();
      return(INIT_FAILED);
   }
   signal.AddFilter(filter4);
//--- Set filter parameters
   filter4.PeriodK(Signal_Stoch_PeriodK);
   filter4.PeriodD(Signal_Stoch_PeriodD);
   filter4.PeriodSlow(Signal_Stoch_PeriodSlow);
   filter4.Applied(Signal_Stoch_Applied);
   filter4.Weight(Signal_Stoch_Weight);
//--- Creation of trailing object
   CTrailingNone *trailing=new CTrailingNone;
   if(trailing==NULL) {
      //--- failed
      printf(__FUNCTION__+": error creating trailing");
      ExtExpert.Deinit();
      return(INIT_FAILED);
   }
//--- Add trailing to expert (will be deleted automatically))
   if(!ExtExpert.InitTrailing(trailing)) {
      //--- failed
      printf(__FUNCTION__+": error initializing trailing");
      ExtExpert.Deinit();
      return(INIT_FAILED);
   }
//--- Set trailing parameters
//--- Creation of money object
   CMoneyFixedLot *money=new CMoneyFixedLot;
   if(money==NULL) {
      //--- failed
      printf(__FUNCTION__+": error creating money");
      ExtExpert.Deinit();
      return(INIT_FAILED);
   }
//--- Add money to expert (will be deleted automatically))
   if(!ExtExpert.InitMoney(money)) {
      //--- failed
      printf(__FUNCTION__+": error initializing money");
      ExtExpert.Deinit();
      return(INIT_FAILED);
   }
//--- Set money parameters
   money.Percent(Money_FixLot_Percent);
   money.Lots(Money_FixLot_Lots);
//--- Check all trading objects parameters
   if(!ExtExpert.ValidationSettings()) {
      //--- failed
      ExtExpert.Deinit();
      return(INIT_FAILED);
   }
//--- Tuning of all necessary indicators
   if(!ExtExpert.InitIndicators()) {
      //--- failed
      printf(__FUNCTION__+": error initializing indicators");
      ExtExpert.Deinit();
      return(INIT_FAILED);
   }
//--- ok
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Deinitialization function of the expert                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   ExtExpert.Deinit();
   Comment("");
}
//+------------------------------------------------------------------+
//| "Tick" event handler function                                    |
//+------------------------------------------------------------------+
void OnTick() {
   ExtExpert.OnTick();
   DrawDashboard();
}
//+------------------------------------------------------------------+
//| "Trade" event handler function                                    |
//+------------------------------------------------------------------+
void OnTrade() {
   ExtExpert.OnTrade();
   UpdateTradingStats();
}
//+------------------------------------------------------------------+
//| "Timer" event handler function                                    |
//+------------------------------------------------------------------+
void OnTimer() {
   ExtExpert.OnTimer();
}
//+------------------------------------------------------------------+
