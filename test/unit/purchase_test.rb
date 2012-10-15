require 'test_helper'

class PurchaseTest < ActiveSupport::TestCase
  context "update_status_by_valid_request" do
    setup do
      @purchase = Purchase.first
      # the purchase above has status "prepared"
    end

    context "payment_ids doesn't match" do
      should "NOT even call show_payment" do
        @price_setting_mock.expects(:show_payment).never
        @purchase.update_status_by_valid_request({:purchase_id => '1', :price_setting_id => '111111', :payment_id => '54321', :status => "paid" })
        assert_equal "prepared", @purchase.status
      end
    end
    context "payment_ids match" do
      setup do
        @price_setting_mock = dutch_price_setting_mock
        Zaypay::PriceSetting.stubs(:new).returns @price_setting_mock
      end
      context "BUT price_setting_ids dont match" do
        should "not even call show_payment" do
          @price_setting_mock.expects(:show_payment).never
          @purchase.update_status_by_valid_request({:purchase_id => '1', :price_setting_id => '987654', :payment_id => '12345', :status => "in_progress" })
        end
      end
      context "AND price_setting_ids match" do
        context "AND params[:status] matches with the status on Zaypay platform as well" do
          should "update the status" do
            @price_setting_mock.expects(:show_payment).with(12345).returns({:payment => {:id => '12345', :status => "in_progress"}})
            @purchase.expects(:update_attributes).with(:status => "in_progress")
            @purchase.update_status_by_valid_request({:purchase_id => '1', :price_setting_id => '111111', :payment_id => '12345', :status => "in_progress" })
          end
        end
        context "BUT params[:status] does not match with the status on Zaypay platform" do
          should "NOT update the status" do
            @price_setting_mock.expects(:show_payment).with(12345).returns ({:payment => {:id => '12345', :status => "prepared"}})
            @purchase.expects(:update_attributes).never
            @purchase.update_status_by_valid_request({:purchase_id => '1', :price_setting_id => '111111', :payment_id => '12345', :status => "paid" })
          end
        end
      end
    end
  end # END update_status_by_valid_request
  
  context "is_prepared?" do
    should "return true for prepared payments" do
      purchase = purchases(:one)
      assert purchase.is_prepared?
    end
    should "return false for non-prepared payments" do
      purchase = purchases(:two)
      assert_equal false, purchase.is_prepared?
    end
  end
  
  context "is_in_progress?" do
    should "return true for in_progress payments" do
      purchase = purchases(:two)
      assert purchase.is_in_progress?
    end
    should "return false for non-in_progress payments" do
      purchase = purchases(:three)
      assert_equal false, purchase.is_in_progress?
    end
  end

  context "is_paused?" do
    should "return true for paused payments" do
      purchase = purchases(:three)
      assert purchase.is_paused?
    end
    should "return false for non-paused payments" do
      purchase = purchases(:four)
      assert_equal false, purchase.is_paused?
    end
  end

  context "is_paid?" do
    should "return true for paid payments" do
      purchase = purchases(:four)
      assert purchase.is_paid?
    end
    should "return false for non-paid payments" do
      purchase = purchases(:three)
      assert_equal false, purchase.is_paid?
    end
  end

  context "has_error?" do
    should "return true for error payments" do
      purchase = purchases(:five)
      assert purchase.has_error?
    end
    should "return false for non-error payments" do
      purchase = purchases(:four)
      assert_equal false, purchase.has_error?
    end
  end

  context "set_needs_polling" do

    context "sms payment" do
      should "return false when status is prepared" do
        @purchase = purchases(:one)
        @sms_payment = {:payment => {:id => '12345', :status => "prepared", :platform => 'sms'} }
        @purchase.set_needs_polling(@sms_payment)
        assert_equal false, @purchase.needs_polling?
      end
      should "return true when status is in_progress with verification code needed" do
        @purchase = purchases(:two)
        @sms_payment = {:payment => {:id => '12345', :status => "in_progress", :platform => 'sms', :verification_needed => true} }
        @purchase.set_needs_polling(@sms_payment)
        assert_equal true, @purchase.needs_polling?
      end
      should "return false when status is in_progress with verification code NOT needed" do
        @purchase = purchases(:two)
        @sms_payment = {:payment => {:id => '12345', :status => "in_progress", :platform => 'sms', :verification_needed => false} }
        @purchase.set_needs_polling(@sms_payment)
        assert_equal false, @purchase.needs_polling?
      end      
      should "return false when status is paid" do
        @purchase = purchases(:four)
        @sms_payment = {:payment => {:id => '12345', :status => "paid", :platform => 'sms'}}
        @purchase.set_needs_polling(@sms_payment)
        assert_equal false, @purchase.needs_polling?
      end      
      should "return false when status is error" do
        @purchase = purchases(:five)
        @sms_payment = {:payment => {:id => '12345', :status => "error", :platform => 'sms'}}
        @purchase.set_needs_polling(@sms_payment)
        assert_equal false, @purchase.needs_polling?
      end
    end
    
    context "per call payment" do
      should "return false when status is prepared" do
        @purchase = purchases(:one)
        @per_call_payment = {:payment => {:id => '12345', :status => "prepared", :platform => 'phone', :sub_platform => 'pay per call'}}
        @purchase.set_needs_polling(@per_call_payment)
        assert_equal false, @purchase.needs_polling?
      end
      should "return false when status is in_progress" do
        @purchase = purchases(:two)
        @per_call_payment = {:payment => {:id => '12345', :status => "in_progress", :platform => 'phone', :sub_platform => 'pay per call'}}
        @purchase.set_needs_polling(@per_call_payment)
        assert_equal false, @purchase.needs_polling?
      end
      should "return false when status is paid" do
        @purchase = purchases(:four)
        @per_call_payment = {:payment => {:id => '12345', :status => "paid", :platform => 'phone', :sub_platform => 'pay per call'}}
        @purchase.set_needs_polling(@per_call_payment)
        assert_equal false, @purchase.needs_polling?
      end      
      should "return false when status is error" do
        @purchase = purchases(:six)
        @per_call_payment = {:payment => {:id => '12345', :status => "error", :platform => 'phone', :sub_platform => 'pay per call'}}
        @purchase.set_needs_polling(@per_call_payment)
        assert_equal false, @purchase.needs_polling?
      end
    end
    
    context "per minute payment" do
      should "return false when status is prepared" do
        @purchase = purchases(:one)
        @per_minute_payment = {:payment => {:id => '12345', :status => "prepared", :platform => 'phone', :sub_platform => 'pay per minute'} }
        @purchase.set_needs_polling(@per_minute_payment)
        assert_equal false, @purchase.needs_polling?
      end
      should "return false when status is in_progress" do
        @purchase = purchases(:two)
        @per_minute_payment = {:payment => {:id => '12345', :status => "in_progress", :platform => 'phone', :sub_platform => 'pay per minute'} }
        @purchase.set_needs_polling(@per_minute_payment)
        assert_equal true, @purchase.needs_polling?
      end
      should "return false when status is paused" do
        @purchase = purchases(:three)
        @per_minute_payment = {:payment => {:id => '12345', :status => "paused", :platform => 'phone', :sub_platform => 'pay per minute'} }
        @purchase.set_needs_polling(@per_minute_payment)
        assert_equal true, @purchase.needs_polling?
      end
      should "return false when status is paid" do
        @purchase = purchases(:four)
        @per_minute_payment = {:payment => {:id => '12345', :status => "paid", :platform => 'phone', :sub_platform => 'pay per minute'} }
        @purchase.set_needs_polling(@per_minute_payment)
        assert_equal false, @purchase.needs_polling?
      end      
      should "return false when status is error" do
        @purchase = purchases(:five)
        @per_minute_payment = {:payment => {:id => '12345', :status => "error", :platform => 'phone', :sub_platform => 'pay per minute'} }
        @purchase.set_needs_polling(@per_minute_payment)
        assert_equal false, @purchase.needs_polling?
      end
    end
    
    context "future platform" do
      should "return false when status is prepared" do
        @purchase = purchases(:one)
        @future_platform_payment = {:payment => {:id => '12345', :status => "prepared", :platform => 'future_platform'} }
        @purchase.set_needs_polling(@future_platform_payment)
        assert_equal false, @purchase.needs_polling?
      end
      should "return false when status is in_progress" do
        @purchase = purchases(:two)
        @future_platform_payment = {:payment => {:id => '12345', :status => "in_progress", :platform => 'future_platform'} }
        @purchase.set_needs_polling(@future_platform_payment)
        assert_equal true, @purchase.needs_polling?
      end
      should "return false when status is paused" do
        @purchase = purchases(:three)
        @future_platform_payment = {:payment => {:id => '12345', :status => "paused", :platform => 'future_platform'} }
        @purchase.set_needs_polling(@future_platform_payment)
        assert_equal true, @purchase.needs_polling?
      end
      should "return false when status is paid" do
        @purchase = purchases(:four)
        @future_platform_payment = {:payment => {:id => '12345', :status => "paid", :platform => 'future_platform'} }
        @purchase.set_needs_polling(@future_platform_payment)
        assert_equal false, @purchase.needs_polling?
      end      
      should "return false when status is error" do
        @purchase = purchases(:five)
        @future_platform_payment = {:payment => {:id => '12345', :status => "error", :platform => 'future_platform'} }
        @purchase.set_needs_polling(@future_platform_payment)
        assert_equal false, @purchase.needs_polling?
      end
    end
    
  end # context needs polling
end