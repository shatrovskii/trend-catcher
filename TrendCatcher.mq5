/*
 *                                                 TrendCatcher.mq5 |
 *                        Copyright 2017, MetaQuotes Software Corp. |
 *                                             https://www.mql5.com |
 */
#property copyright "Copyright 2017, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#define EXPERT_MAGIC 614029
//--- input parameters
int      positionsDiff = 100;
double   openPosition = 0.5;
double   takeProfit = 0.5;
double   stopLoss = 1.25;
double   tradeVolume = 0.1;
int      requestDeviation = 2;

double point;
int digits;
double lastBuyStopLoss;
double lastSellStopLoss;
ulong   lastBuyOrder;
ulong   lastSellOrder;
int openedBuyOrders = 0;
int openedSellOrders = 0;

double getOpenPosition() {
   return positionsDiff * openPosition;
}
double getTakeProfit() {
   return positionsDiff * takeProfit;
}
double getStopLoss() {
   return positionsDiff * stopLoss;
}

/*
 * Expert initialization function
 */
int OnInit() {
   Print("=====================================================================");
   Print("--------------------------------------------------ЗАПУСТИЛСЯ TREND CATCHER");
   Print("=====================================================================");
   Print("--------------------ТЕКУЩИЙ СИМВОЛ: " + _Symbol);
   
   point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   Print("--------------------ВЕЛИЧИНА ПУНКТА: " +  point);
   
   digits = SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   Print("--------------------ТОЧНОСТЬ СМИМВОЛА: " + digits);
   
   double positionsDiffPrice = NormalizeDouble(positionsDiff * point, digits);
   Print("--------------------РАЗНИЦА М/У ПОЗИЦИЯМИ В ПУНКТАХ: " + positionsDiff);
   Print("--------------------РАЗНИЦА М/У ПОЗИЦИЯМИ В ЦЕНЕ: " + positionsDiffPrice);
   
   int takeProfitPoints = getTakeProfit();
   double takeProfitPrice = NormalizeDouble(takeProfitPoints * point, digits);
   Print("--------------------TAKE PROFIT В ПУНКТАХ: " + takeProfitPoints);
   Print("--------------------TAKE PROFIT В ЦЕНЕ: " + takeProfitPrice);
   
   int stopLossPoints = getStopLoss();
   double stopLossPrice = NormalizeDouble(stopLossPoints * point, digits);
   Print("--------------------STOP LOSS В ПУНКТАХ: " + stopLossPoints);
   Print("--------------------STOP LOSS В ЦЕНЕ: " + stopLossPrice);
   
   openPendingOrder(ORDER_TYPE_BUY_STOP, getOpenPosition());
   openPendingOrder(ORDER_TYPE_SELL_STOP, -1 * getOpenPosition());
   return(INIT_SUCCEEDED);
}
/*
 * Expert deinitialization function
 */
void OnDeinit(const int reason) {
}
/*
 * Expert tick function
 */
void OnTick() {
   //Print("Open Position: ", openPosition);
}
/*
 * Trade function
 */
void OnTrade() {
}
/*
 * TradeTransaction function
 */
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result) {
   //Print("--------------------------------------------------ON TRADE TRANSACTION");
   //--- получим тип транзакции в виде значения перечисления  
   ENUM_TRADE_TRANSACTION_TYPE type = trans.type; 
   //Print(EnumToString(type));

   if (type == TRADE_TRANSACTION_ORDER_DELETE) { 
      //Print(EnumToString(trans.order_state));
      if (trans.order_state == ORDER_STATE_FILLED) {
         //Print("--------------------ТИП ОРДЕРА ТРАНЗАКЦИИ: " + EnumToString(trans.order_type));
         //Print("------------TransactionDescription\r\n",TransactionDescription(trans));
         if (trans.order_type == ORDER_TYPE_BUY_STOP) {
            Print("--------------------ОТКРЫЛСЯ ОРДЕР НА ПОКУПКУ N: " + trans.order + " ПО ЦЕНЕ: " + trans.price);
            openedBuyOrders++;
            /*
             * Если открылась позиция на покупку
             * 1. создаём отложенный ордер в ту же сторону
             */
            openPendingOrder(ORDER_TYPE_BUY_STOP, getTakeProfit());
            /*
             * 2. подтягиваем противоположный, если нужно.
             */
            if (openedSellOrders == 0) {
               openPendingOrder(ORDER_TYPE_SELL_STOP, -2 * getOpenPosition());
            }
         } else if (trans.order_type == ORDER_TYPE_SELL) {
            if (trans.price < lastBuyStopLoss) {
               Print("--------------------СРАБОТАЛ СТОП ЛОСС ОРДЕРА НА ПОКУПКУ N: " + trans.order + " ПО ЦЕНЕ: " + trans.price);
               /*
                * Позиция на покупку закрылась по STOP LOSS
                * создаём отложенный ордер в ту же сторону
                */
               openPendingOrder(ORDER_TYPE_BUY_STOP, lastSellStopLoss - getStopLoss() + 2 * getOpenPosition());
            }
            openedBuyOrders--;
         } else if (trans.order_type == ORDER_TYPE_SELL_STOP) {
            Print("--------------------ОТКРЫЛСЯ ОРДЕР НА ПРОДАЖУ N " + trans.order + " ПО ЦЕНЕ: " + trans.price);
            openedSellOrders++;
            /*
             * Если открылась позиция на продажу
             * 1. создаём отложенный ордер в ту же сторону
             */
            openPendingOrder(ORDER_TYPE_SELL_STOP, -1 * getTakeProfit());
            /*
             * 2. подтягиваем противоположный, если нужно.
             */
            if (openedBuyOrders == 0) {
               openPendingOrder(ORDER_TYPE_BUY_STOP, 2 * getOpenPosition());
            }
         } else if (trans.order_type == ORDER_TYPE_BUY) {
            if (trans.price > lastSellStopLoss) {
               Print("--------------------СРАБОТАЛ СТОП ЛОСС ОРДЕРА НА ПРОДАЖУ N " + trans.order + " ПО ЦЕНЕ: " + trans.price);
               /*
                * Позиция на продажу закрылась по STOP LOSS
                * создаём отложенный ордер в ту же сторону
                */
               openPendingOrder(ORDER_TYPE_SELL_STOP, lastBuyStopLoss + getStopLoss() - 2 * getOpenPosition());
            }
            openedSellOrders--;
         }
         
         if (openedBuyOrders > 1) {
            Print("--------------------КОЛИЧЕСТВО ОТКРЫТЫХ ОРДЕРОВ НА ПОКУПКУ: " + openedBuyOrders);
         }
         if (openedSellOrders > 1) {
            Print("--------------------КОЛИЧЕСТВО ОТКРЫТЫХ ОРДЕРОВ НА ПРОДАЖУ: " + openedSellOrders);
         }
      }
      //--- выведем строковое описание обработанного запроса 
      //Print("------------RequestDescription\r\n",RequestDescription(request)); 
      //--- выведем описание результата запроса 
      //Print("------------ResultDescription\r\n",TradeResultDescription(result)); 
      //--- запомним тикет ордера для его удаления на следующей обработке в OnTick() 
   } else if (type == TRADE_TRANSACTION_ORDER_ADD) {
      //Print(EnumToString(trans.order_type));
      if (trans.order_type == ORDER_TYPE_BUY_STOP) {
         lastBuyOrder = trans.order;
      } else if (trans.order_type == ORDER_TYPE_SELL_STOP) {
         lastSellOrder = trans.order;
      }
   } 
}
/*
 * Get Spread
 */
double getSpread() {
   return SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
}
/*
 * Open Order
 */
void openPendingOrder(const ENUM_ORDER_TYPE orderType, const double offset) {
   MqlTradeRequest request = {0};
   
   request.symbol = _Symbol; 
   request.magic = EXPERT_MAGIC; 
   request.volume = tradeVolume; 
   request.type = orderType;
   
   double price;
   double tp;
   double sl;
   string comment;
   string direction;
   ulong lastOpenOrder;
   double spread = getSpread();
   Print("ВЕЛИЧИНА СПРЕДА: " + NormalizeDouble(spread, digits));
   if (orderType == ORDER_TYPE_BUY_STOP) {
      lastOpenOrder = lastBuyOrder;
      price = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK) + offset * point, digits);
      tp = NormalizeDouble(price + getTakeProfit() * point - spread, digits);
      sl = NormalizeDouble(price - getStopLoss() * point - spread, digits);
      lastBuyStopLoss = sl;
      direction = "ПОКУПКУ";
      comment = "BUY STOP";
   } else {
      lastOpenOrder = lastSellOrder;
      price = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID) + offset * point, digits);
      tp = NormalizeDouble(price - getTakeProfit() * point + spread, digits);
      sl = NormalizeDouble(price + getStopLoss() * point + spread, digits);
      lastSellStopLoss = sl;
      direction = "ПРОДАЖУ";
      comment = "SELL STOP";
   }
   request.price = price;
   request.tp = tp;
   request.sl = sl;
   
   if (OrderSelect(lastOpenOrder)) {
      request.action = TRADE_ACTION_MODIFY;
      request.order = lastOpenOrder;
      Print("--------------------ИЗМЕНЁН ОРДЕР НА "+direction+" N " + request.order + " ПО ЦЕНЕ: " + price);
   } else {
      request.action = TRADE_ACTION_PENDING; 
      Print("--------------------СОЗДАН ОРДЕР НА "+direction+ " ПО ЦЕНЕ: " + price);
   }

   request.type_filling = ORDER_FILLING_FOK;
   request.deviation = requestDeviation; 
   request.comment = comment; 

   MqlTradeResult result = {0}; 
   if(!OrderSendAsync(request, result)) { 
      Print(__FUNCTION__, ": error ", GetLastError(), ", retcode = ", result.retcode); 
   }
}
//+------------------------------------------------------------------+ 
//| Возвращает текстовое описание транзакции                         | 
//+------------------------------------------------------------------+ 
string TransactionDescription(const MqlTradeTransaction &trans) 
  { 
//---  
   string desc=EnumToString(trans.type)+"\r\n"; 
   desc+="Symbol: "+trans.symbol+"\r\n"; 
   desc+="Deal ticket: "+(string)trans.deal+"\r\n"; 
   desc+="Deal type: "+EnumToString(trans.deal_type)+"\r\n"; 
   desc+="Order ticket: "+(string)trans.order+"\r\n"; 
   desc+="Order type: "+EnumToString(trans.order_type)+"\r\n"; 
   desc+="Order state: "+EnumToString(trans.order_state)+"\r\n"; 
   desc+="Order time type: "+EnumToString(trans.time_type)+"\r\n"; 
   desc+="Order expiration: "+TimeToString(trans.time_expiration)+"\r\n"; 
   desc+="Price: "+StringFormat("%G",trans.price)+"\r\n"; 
   desc+="Price trigger: "+StringFormat("%G",trans.price_trigger)+"\r\n"; 
   desc+="Stop Loss: "+StringFormat("%G",trans.price_sl)+"\r\n"; 
   desc+="Take Profit: "+StringFormat("%G",trans.price_tp)+"\r\n"; 
   desc+="Volume: "+StringFormat("%G",trans.volume)+"\r\n"; 
   desc+="Position: "+(string)trans.position+"\r\n"; 
   desc+="Position by: "+(string)trans.position_by+"\r\n"; 
//--- вернем полученную строку 
   return desc; 
  } 
//+------------------------------------------------------------------+ 
//| Возвращает текстовое описание торгового запроса                  | 
//+------------------------------------------------------------------+ 
string RequestDescription(const MqlTradeRequest &request) 
  { 
//--- 
   string desc=EnumToString(request.action)+"\r\n"; 
   desc+="Symbol: "+request.symbol+"\r\n"; 
   desc+="Magic Number: "+StringFormat("%d",request.magic)+"\r\n"; 
   desc+="Order ticket: "+(string)request.order+"\r\n"; 
   desc+="Order type: "+EnumToString(request.type)+"\r\n"; 
   desc+="Order filling: "+EnumToString(request.type_filling)+"\r\n"; 
   desc+="Order time type: "+EnumToString(request.type_time)+"\r\n"; 
   desc+="Order expiration: "+TimeToString(request.expiration)+"\r\n"; 
   desc+="Price: "+StringFormat("%G",request.price)+"\r\n"; 
   desc+="Deviation points: "+StringFormat("%G",request.deviation)+"\r\n"; 
   desc+="Stop Loss: "+StringFormat("%G",request.sl)+"\r\n"; 
   desc+="Take Profit: "+StringFormat("%G",request.tp)+"\r\n"; 
   desc+="Stop Limit: "+StringFormat("%G",request.stoplimit)+"\r\n"; 
   desc+="Volume: "+StringFormat("%G",request.volume)+"\r\n"; 
   desc+="Comment: "+request.comment+"\r\n"; 
//--- вернем полученную строку 
   return desc; 
  } 
//+------------------------------------------------------------------+ 
//| Возвращает текстовое описание результата обработки запроса       | 
//+------------------------------------------------------------------+ 
string TradeResultDescription(const MqlTradeResult &result) 
  { 
//--- 
   string desc="Retcode "+(string)result.retcode+"\r\n"; 
   desc+="Request ID: "+StringFormat("%d",result.request_id)+"\r\n"; 
   desc+="Order ticket: "+(string)result.order+"\r\n"; 
   desc+="Deal ticket: "+(string)result.deal+"\r\n"; 
   desc+="Volume: "+StringFormat("%G",result.volume)+"\r\n"; 
   desc+="Price: "+StringFormat("%G",result.price)+"\r\n"; 
   desc+="Ask: "+StringFormat("%G",result.ask)+"\r\n"; 
   desc+="Bid: "+StringFormat("%G",result.bid)+"\r\n"; 
   desc+="Comment: "+result.comment+"\r\n"; 
//--- вернем полученную строку 
   return desc; 
  }
