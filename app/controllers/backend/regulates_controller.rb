class Backend::RegulatesController < Backend::BaseController

  def index
    @regulates = Regulate.order('market_id').paginate(page:params[:page])
  end

  def new
  end

  def create
    @regulate = Regulate.new(regulate_params)
    if @regulate.save
      redirect_to backend_regulates_path, notice: '添加行情监管'
    else
      flash[:warn] = "请完善表单信息"
      render :new
    end
  end

  def edit
  end

  def update
    if @regulate.update(regulate_params)
      redirect_to backend_regulates_path, notice: '更新行情监管'
    else
      flash[:warn] = "请完善表单信息"
      render :edit
    end
  end

  def destroy
    @regulate.destroy
    flash[:notice] = "删除行情监管"
    redirect_to :back
  end

  def change_state
    if params[:kind] == 'sms'
      @regulate.update(notify_sms: !@regulate.notify_sms)
    elsif params[:kind] == 'wx'
      @regulate.update(notify_wx: !@regulate.notify_wx)
    elsif params[:kind] == 'dd'
      @regulate.update(notify_dd: !@regulate.notify_dd)
    elsif params[:kind] == 'fast'
      @regulate.update(fast_trade: !@regulate.fast_trade)
    elsif params[:kind] == 'range'
      @regulate.update(range_trade: !@regulate.range_trade)
    end
    render json: { message: 'Success'}
  end

private

  def regulate_params
    params.require(:regulate).permit(:market_id, :precision, :amplitude, :retain, :cost,
      :fast_profit, :fast_cash, :range_profit, :range_cash)
  end

end
