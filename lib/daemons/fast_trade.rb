#!/usr/bin/env ruby

# You might want to change this
ENV["RAILS_ENV"] ||= "production"

root = File.expand_path(File.dirname(__FILE__))
root = File.dirname(root) until File.exists?(File.join(root, 'config'))
Dir.chdir(root)

require File.join(root, "config", "environment")

$running = true
Signal.trap("TERM") do
  $running = false
end

def start_hunter(coin)
  _profit = coin.regulate.resistance
  _cost   = coin.regulate.cost
  _latest = coin.recent_price

  if _latest > _profit
    coin.sync_fund
    coin.sync_fund
    balance = coin.fund.balance
    amount = coin.regulate.fast_cash
    if balance > 0.01
      if balance > amount
        coin.step_price_ask(amount)
      else
        coin.market_price_ask(balance * 0.998)
      end
      coin.regulate.update(resistance: _latest * 1.001)
      coin.regulate.update(support: _latest * 0.9975)
      if _latest * 0.9975 > coin.avg_cost
        switch_guarant
      end
    end
  end

  if _latest < _cost
    amount = coin.regulate.fast_cash
    quota = coin.regulate.retain
    coin.step_price_bid(amount)
    coin.regulate.update(cost: _latest)
  end
end

def switch_guarant
  status = Daemons::Rails::Monitoring.statuses
  unless status['guarant.rb'] == :running
    Daemons::Rails::Monitoring.start('guarant.rb')
    Notice.dingding("开启止损操作")
  end
end

while($running) do
  begin
    Market.all.each do |coin|
      if coin&.regulate&.fast_trade
        start_hunter(coin)
      end
    end
  rescue => detail
    Notice.dingding("FastTrade：\n #{detail.message} \n #{detail.backtrace[0..5].join("\n")}")
  end
  sleep 30
end
