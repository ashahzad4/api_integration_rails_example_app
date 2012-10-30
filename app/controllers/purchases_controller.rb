class PurchasesController < ApplicationController
  before_filter :verify_session_id, :only => :show
  before_filter :assign_parent_product_and_price_setting, :except => :report
  before_filter :bust_response_headers, :only => :new

  def new
    respond_to do |format|
      format.html{
        if country = @ps.ip_country_is_configured?(request.remote_ip)
          @ps.locale = Zaypay::Util.stringify_locale_hash(country[:locale])
        end
      }
      format.js{
        if params[:country].present? && params[:language].present?
          @ps.locale = params[:language] + "-" + params[:country]
        end
      }
    end
  end

  def create
    # set locale first before calling #list_payment_methods
    # locale and payment_method_id must be set before calling create_payment
    
    if params[:language].blank? || params[:country].blank? || params[:payment_method].blank?
      flash[:error] = ''
      flash[:error] << "You did not select a language.<br/>" if params[:language].blank?
      flash[:error] << "You did not select a country.<br/>"   if params[:country].blank?
      flash[:error] << "You did not select a payment method." if params[:payment_method].blank?
      redirect_to new_product_purchase_path(@product) and return
    end
    
    @ps.locale = params[:language] + "-" + params[:country]
    @ps.payment_method_id = params[:payment_method]
    @purchase = @product.purchases.create!(:session_id => session[:session_id])
    begin
      @zaypay_payment = @ps.create_payment(:purchase_id => @purchase.id)
    rescue => e
      if e.type == :locale_not_set
        flash[:error] = "There was an error with the country or language you provided"
      elsif e.type == :payment_method_id_not_set
        flash[:error] = "There was an error with the payment method you provided"
      else
        flash[:error] = "Oops... Something went wrong, please try again"
      end
      @purchase.destroy
      redirect_to new_product_purchase_path(@product)
    else
      @purchase.set_needs_polling(@zaypay_payment)
      @purchase.update_attributes(:zaypay_payment_id => @zaypay_payment[:payment][:id])
      redirect_to product_purchase_path(@product, @purchase)
    end
  end

  def show
    @purchase = Purchase.find(params[:id])

    respond_to do |format|
      format.js {
        @zaypay_payment = @ps.show_payment(@purchase.zaypay_payment_id) if @purchase.needs_polling?
      }

      format.html {
        if !@purchase.is_paid? && !@purchase.has_error?
          @zaypay_payment = @ps.show_payment(@purchase.zaypay_payment_id)
        end
      }
    end
  end

  def report
    if params[:payment_id].present? && params[:price_setting_id].present? && params[:purchase_id].present? && params[:status].present?
      @purchase = Purchase.find(params[:purchase_id])
      if @purchase
        @purchase.update_status_by_valid_request(params)
        unless @purchase.is_prepared?
          @ps = Zaypay::PriceSetting.new(@purchase.product.price_setting_id)
          @zaypay_payment = @ps.show_payment(@purchase.zaypay_payment_id) if @purchase.zaypay_payment_id
          @purchase.set_needs_polling(@zaypay_payment)
        end
      end
    end
    render :layout => false, :text => "*ok*"
  end

  def submit_verification_code
    @purchase = Purchase.find(params[:id])

    if session[:session_id] != @purchase.session_id
      redirect_to products_path and return
    end

    respond_to do |format|
      format.js {
        if params[:verification_code].present? && @purchase.is_in_progress?
          @zaypay_payment = @ps.verification_code(@purchase.zaypay_payment_id, params[:verification_code])
        end
      }
    end
  end

  private ################################################################
  def assign_parent_product_and_price_setting
    @product = Product.find(params[:product_id])
    @ps = Zaypay::PriceSetting.new(@product.price_setting_id)
  end

  def verify_session_id
    if session[:session_id] != Purchase.find(params[:id]).session_id
      flash[:error] = "You tried to access a page that does not exist"
      redirect_to products_path
    end
  end
  
  def bust_response_headers
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
  end
end