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

# tradingview 通知格式 #BTC_USDT|RSI1 <=> 70|market|ask
# subject= "#BTC_USDT|RSI1 <=> 70|step|bid"
def start_trade(subject)
  puts "[#{Time.now.to_s(:short)}] #{subject}"
  trading = subject.split('|')
  quote = trading[0].split('_')
  market = Market.find_by_quote_unit_and_base_unit(quote[0],quote[1])
  if market&.regulate&.fast_trade
    amount = market.regulate.fast_cash
    profit = market.regulate.fast_profit || 0.002
    side = trading[-1]
    if side == 'bid'
      puts "[#{Time.now.to_s(:short)}] staring new bid order"
      bid_order(market, amount, profit, subject)
    elsif side == 'ask'
      puts "[#{Time.now.to_s(:short)}] staring ask bid order"
      ask_order(market, amount, profit, subject)
    end
  end
end

def bid_order(market, amount, profit, subject)
  _latest = market.recent_price
  price = _latest * (1 - profit)
  market.regulate.update(cost: _latest * 0.9985)
  if subject =~ /(step)|(market)/
    puts "[#{Time.now.to_s(:short)}] #{market.full_name} bid #{$1} amount: #{amount}"
    market.send("#{$1}_price_bid".to_sym, amount)
  else
    puts "[#{Time.now.to_s(:short)}] #{market.full_name} bid limit amount: #{amount}"
    market.new_bid(price, amount)
  end
end

def ask_order(market,amount, profit, subject)
  price = market.recent_price * (1 + profit)
  if subject =~ /(step)|(market)/
    puts "[#{Time.now.to_s(:short)}] #{market.full_name} ask #{$1} amount: #{amount}"
    market.send("#{$1}_price_ask".to_sym, amount)
  else
    puts "[#{Time.now.to_s(:short)}] #{market.full_name} ask limit amount: #{amount}"
    aks_order = market.new_ask(price, amount)
  end
end

def stop_loss
  Daemon.start('stoploss')
end

def build(subject)
  trading = subject.split('|')
  quote = trading[0].split('_')
  market = Market.find_by_quote_unit_and_base_unit(quote[0],quote[1])
  unless market&.regulate&.fast_trade
    market.regulate.update(fast_trade: true, support: market.recent_price * 0.9975, resistance: market.recent_price * 1.0075)
    amount = market.regulate.retain
    market.step_price_bid(amount)
  end
end

def all_in(subject)
  trading = subject.split('|')
  quote = trading[0].split('_')
  market = Market.find_by_quote_unit_and_base_unit(quote[0],quote[1])
  if market&.regulate&.fast_trade
    amount = market.regulate.retain
    market.step_price_bid(amount)
    market.regulate.update(support: market.recent_price * 0.9975, resistance: market.recent_price * 1.0075)
  end
end

while($running) do
  begin
    mails = Mail.all.select { |x| x.from[0] =~ /tradingview/ }
    mails.each do |email|
      if email.subject.include? '|'
        subject = email.subject
        topic = subject.delete(' ').split('#')[-1]
        Notice.dingding("[#{Time.now.to_s(:short)}] \n #{topic}")
        start_trade(topic) if topic =~ /(bid)|(ask)/
        build(topic) if topic =~ /build/
        all_in(topic) if topic =~ /all_in/
        stop_loss if topic =~ /stop_loss/
      end
    end
  rescue => detail
    Notice.dingding("TradingView：\n #{detail.message} \n #{detail.backtrace[0..5].join("\n")}")
  end
  sleep 10
end
