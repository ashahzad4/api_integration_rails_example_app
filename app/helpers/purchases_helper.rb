module PurchasesHelper
  def generate_instructions_body
    return unless @zaypay_payment
    
    if @purchase.is_in_progress? && @zaypay_payment[:payment][:verification_needed] == true
      render 'verification_code_form'
    elsif @purchase.is_prepared? || @purchase.is_in_progress? || @purchase.is_paused?
      content_tag :div, :id => 'instructions_body' do
        (content_tag(:div, :id => 'long_instructions') do
          raw @zaypay_payment[:instructions][:long_instructions]
        end) +
        (content_tag :h5, :id => 'waiting_for_response' do
          'Waiting for response.....'
        end)
      end
    end

  end
end
