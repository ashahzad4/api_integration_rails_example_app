class Purchase < ActiveRecord::Base
  belongs_to :product

  def update_status_by_valid_request(params)
    return if !payment_id_equals?(params[:payment_id]) || !price_setting_equals?(params[:price_setting_id]) || !status_equals?(params[:status])
    update_attributes(:status => params[:status])
  end

  def is_prepared?
    status == 'prepared'
  end
  
  def is_in_progress?
    status == 'in_progress'
  end
  
  def is_paused?
    status == 'paused'
  end
  
  def is_paid?
    status == 'paid'
  end
  
  def has_error?
    status == 'error'
  end

  def set_needs_polling(zaypay_payment)
    if (zaypay_payment[:payment][:platform] != 'sms' && (is_in_progress? || is_paused?) && zaypay_payment[:payment][:sub_platform] != 'pay per call') || sms_in_progress_needs_verification?(zaypay_payment)
      update_attributes(:needs_polling => true)
    else
      update_attributes(:needs_polling => false)
    end
  end

  private ######################################################################
  
  def payment_id_equals?(params_payment_id)
    zaypay_payment_id == params_payment_id.to_i
  end

  def price_setting_equals?(params_price_setting_id)
    product.price_setting_id == params_price_setting_id.to_i
  end

  # compare the status on the zaypay platform with the status sent in the params
  def status_equals?(params_status)
    @ps = Zaypay::PriceSetting.new(product.price_setting_id)
    @zaypay_payment = @ps.show_payment(zaypay_payment_id)
    @zaypay_payment[:payment][:status] == params_status
  end
  
  def sms_in_progress_needs_verification?(zaypay_payment)
    is_in_progress? && zaypay_payment[:payment][:platform] == 'sms' && zaypay_payment[:payment][:verification_needed]
  end
end