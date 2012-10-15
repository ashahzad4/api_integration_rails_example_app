require 'test_helper'

class PurchasesControllerTest < ActionController::TestCase
  setup do
    @product = products(:one)
    @price_setting = dutch_price_setting_mock
    Zaypay::PriceSetting.stubs(:new).returns @price_setting
  end

  context "#new" do
    should "be successful and render new" do
      get :new, :product_id => @product
      assert_response :success
      assert_template :new
    end

    should "assign a price_setting" do
      get :new, :product_id => @product
      assert_not_nil assigns(:ps)
    end

    context ".html" do
      context "ip_country is configured the in price setting" do
        should "set locale to the ip-country" do
          @price_setting.expects(:ip_country_is_configured?).
                         returns({:country => {:name => 'Netherlands', :code => 'NL'}, :locale => {:country => 'NL', :language => 'nl'}})
          @price_setting.expects(:locale=)
          get :new, :product_id => @product
        end
      end
      context "ip_country is not configured in price setting" do
        should "not assign locale" do
          @price_setting.expects(:ip_country_is_configured?).returns nil
          @price_setting.expects(:locale=).never
          get :new, :product_id => @product
        end
      end
    end

    context ".js" do
      should "set locale if params for country and language are present" do
        @price_setting.expects(:locale=)
        xhr :get, :new, :product_id => @product, :country => "NL", :language => 'nl'
      end
      should "not set locale when language or country are not present" do
        @price_setting.expects(:locale=).never
        xhr :get, :new, :product_id => @product, :country => "", :language => 'nl'
      end
    end
  end ##### END #new #####

  context "#create" do
    def post_create_pay_by_phone
      post :create, {:product_id => @product, :language => "nl", :country => 'NL', :payment_method => "1"},
                    {:session_id => '4444DDDD'}
    end
    
    def post_create_pay_by_sms
      post :create, {:product_id => @product, :language => "nl", :country => 'NL', :payment_method => "2"},
                    {:session_id => '4444DDDD'}
    end

    should "assign a product and price_setting" do
      @price_setting.expects(:create_payment).returns({:payment => {:id => 1}})
      post_create_pay_by_sms
      assert_not_nil assigns(:product)
      assert_not_nil assigns(:ps)
    end

    context "create_payment succeeds" do
      should "create a purchase and call create_payment with purchase_id" do
        assert_difference "Purchase.count" do
          @price_setting.expects(:create_payment).with(:purchase_id => (Purchase.last.id + 1)).returns({:payment => {:id => 1}})
          post_create_pay_by_phone
        end
      end

      should "call set_needs_polling, set a zaypay_payment_id and redirect" do
        @price_setting.expects(:create_payment).with(:purchase_id => (Purchase.last.id + 1)).returns({:payment => {:id => 1, :platform => "phone", :sub_platform => "pay per call"}})
        Purchase.any_instance.expects(:set_needs_polling).with({:payment => {:id => 1, :platform => "phone", :sub_platform => "pay per call"}})
        post_create_pay_by_phone
        assert_redirected_to product_purchase_path(@product, Purchase.last )
        assert_not_nil Purchase.last.zaypay_payment_id
      end
    end
    
    context "create_payment fails" do
      context "locale was not set" do
        should "redirect back to products#new and display flash msg" do
          @price_setting.expects(:create_payment).raises Zaypay::Error.new(:locale_not_set)
          post_create_pay_by_sms
          assert_response :redirect
          assert_redirected_to new_product_purchase_path(@product)
          assert_equal "There was an error with the country or language you provided", flash[:error]
        end
      end
      
      context "payment_method_id was not set" do
        should "redirect back to products#new and display flash msg" do
          @price_setting.expects(:create_payment).raises Zaypay::Error.new(:payment_method_id_not_set)
          post_create_pay_by_sms
          assert_response :redirect
          assert_redirected_to new_product_purchase_path(@product)
          assert_equal "There was an error with the payment method you provided", flash[:error]
        end
      end
      
      context "any other reason" do
        should "redirect back to products#new and display flash msg" do
          @price_setting.expects(:create_payment).raises Zaypay::Error.new(:http_error)
          post_create_pay_by_sms
          assert_response :redirect
          assert_redirected_to new_product_purchase_path(@product)
          assert_equal "Oops... Something went wrong, please try again", flash[:error]
        end
      end
    end
  end ##### END #create #####

  context "#show" do
    setup do
      @prepared_purchase = purchases(:one)
      @in_prog_purchase = purchases(:two)
      @paused_purchase = purchases(:three)
      @paid_purchase = purchases(:four)
      @error_purchase = purchases(:five)
      @needs_polling_purchase = purchases(:six)

      @sms_payment = {:payment => {:id => '1', :status => 'prepared', :payment_method_id => '2'}, 
                             :instructions => {:long_instructions => "Please text the message PAY 3955 to phone number 7711." }}
    end
    
    context "format-JS" do
      context "with a purchase that needs polling" do
        should "call show_payment" do
          @price_setting.expects(:show_payment)
          xhr :get, :show, {:id => @needs_polling_purchase, :product_id => @needs_polling_purchase.product, :payment_method_id => '1', :sub_platform => 'pay_per_call'}, {:session_id => '1234abcd'}
        end
      end
      
      context "with a purchase that does not need polling" do
        should "NOT call show_payment" do
          @price_setting.expects(:show_payment).never
          xhr :get, :show, {:id => @prepared_purchase, :product_id => @prepared_purchase.product, :payment_method_id => '1', :sub_platform => 'pay_per_call'}, {:session_id => '1234abcd'}
        end
      end
    end
    
    context "format HTML" do
      setup do
        @prepared_payment = {:payment => {:id => '1', :status => 'prepared', :payment_method_id => '1', :sub_platform => 'pay per minute'}, 
                                        :instructions => {:long_instructions => "prepared instructions" }}
        @in_prog_payment = {:payment => {:id => '1', :status => 'in_progress', :payment_method_id => '1', :sub_platform => 'pay per minute'}, 
                                       :instructions => {:long_instructions => "in progress instructions" }}
        @paused_payment = {:payment => {:id => '1', :status => 'paused', :payment_method_id => '1', :sub_platform => 'pay per minute'}, 
                                      :instructions => {:long_instructions => "paused instructions" }}
        @paid_payment = {:payment => {:id => '1', :status => 'paid', :payment_method_id => '1', :sub_platform => 'pay per minute'}}
        @error_payment = {:payment => {:id => '1', :status => 'error', :payment_method_id => '1', :sub_platform => 'pay per minute'}}
      end
      context "AND purchase is prepared" do
        should "call show_payment" do
          @price_setting.expects(:show_payment).returns @prepared_payment 
          get :show, {:id => @prepared_purchase, :product_id => @prepared_purchase.product, :payment_method_id => '1', :sub_platform => 'pay_per_minute'}, {:session_id => '1234abcd'}
        end
      end
      context "AND purchase is in_progress" do
        should "call show_payment" do
          @price_setting.expects(:show_payment).returns @in_prog_payment
          get :show, {:id => @prepared_purchase, :product_id => @in_prog_purchase.product, :payment_method_id => '1', :sub_platform => 'pay_per_minute'}, {:session_id => '1234abcd'}
        end
      end
      context "AND purchase is paused" do
        should "call show_payment" do
          @price_setting.expects(:show_payment).returns @paused_payment
          get :show, {:id => @paused_purchase, :product_id => @in_prog_purchase.product, :payment_method_id => '1', :sub_platform => 'pay_per_minute'}, {:session_id => '1234abcd'}
        end
      end
      context "AND purchase is paid" do
        should "NOT call show_payment" do
          @price_setting.expects(:show_payment).never
          get :show, {:id => @paid_purchase, :product_id => @paid_purchase.product, :payment_method_id => '1', :sub_platform => 'pay_per_minute'}, {:session_id => '1234abcd'}
        end
      end
      context "AND purchase is error" do
        should "NOT call show_payment" do
          @price_setting.expects(:show_payment).never
          get :show, {:id => @error_purchase, :product_id => @error_purchase.product, :payment_method_id => '1', :sub_platform => 'pay_per_minute'}, {:session_id => '1234abcd'}
        end
      end
    end
    
    context "accessing with session_id of purchase" do
      def call_get_with_correct_session_id
        get :show, {:id => @prepared_purchase, :product_id => @prepared_purchase.product}, {:session_id => '1234abcd'}
      end
      should "be successfull and render show" do
        @price_setting.expects(:show_payment).returns({:payment => {:id => '1', :status => 'prepared', :payment_method_id => '1', :sub_platform => 'pay per minute'}, :instructions => {:long_instructions => "prepared instructions" }})
        call_get_with_correct_session_id
        assert_response :success
        assert_template :show
        assert_not_nil assigns(:purchase)
        assert_not_nil assigns(:zaypay_payment)
      end
    end

    context "accessing with session_id that differs from purchase.session_id" do
      def call_get_with_incorrect_session_id
        get :show, {:id => @prepared_purchase, :product_id => @prepared_purchase.product}, {:session_id => '9876zyxw'}
      end
      should "be redirected to products#index and display flash msg" do
        call_get_with_incorrect_session_id
        assert_response :redirect
        assert_redirected_to products_path
        assert_equal "You tried to access a page that does not exist", flash[:error]
      end
      should "NOT assign @purchase and @zaypay_payment" do
        call_get_with_incorrect_session_id
        assert_nil assigns(:purchase)
        assert_nil assigns(:zaypay_payment)
      end
    end

  end ##### END #show #####

  context "report" do
    context "payment_id or price_setting_id or purchase_id or status is NOT present in params" do
      should "NOT find a purchase record" do
        params_hash = {:price_setting_id => '111111', :status => 'prepared', :purchase_id => '1', :message => "This+payment+changed+state", :payment_id => "12345"}
        required_keys = [:price_setting_id, :status, :purchase_id, :payment_id]
        required_keys.each do |k|
          minus_one_hash = params_hash.reject{ |hk, hv| hk == k }
          Purchase.expects(:find_by_zaypay_payment_id).never
          get :report,  minus_one_hash
        end
      end
    end

    context "payment_id, price_setting_id, purchase_id all present" do
      should "NOT call #update_status_by_valid_request when no Purchase can be found" do
        params = {:price_setting_id => '111111', :status => 'prepared', :purchase_id => '1', :message => "This+payment+changed+state", :payment_id => "12345"}
        Purchase.expects(:find).returns nil
        Purchase.any_instance.expects(:update_status_by_valid_request).never
        get :report, params
      end
      
      should "call #update_status_by_valid_request when a Purchase can be found" do
        purchase = purchases(:one)
        params = {:price_setting_id => '111111', :status => 'prepared', :purchase_id => '1', :message => "This+payment+changed+state", :payment_id => "12345"}
        Purchase.expects(:find).with("1").returns purchase
        purchase.expects(:update_status_by_valid_request)
        get :report, params
      end
      
      context "purchase's status is not prepared" do
        should "call set_need_polling" do
          purchase = purchases(:two)
          params = {:price_setting_id => '111111', :status => 'in_progress', :purchase_id => '2', :message => "This+payment+changed+state", :payment_id => "23456"}
          
          Purchase.expects(:find).with("2").returns purchase
          @price_setting.stubs(:show_payment).returns({:payment => {:id => '2', :status => 'in_progress', :payment_method_id => '1', :platform => 'phone'}, :instructions => {:long_instructions => "prepared instructions" }})
          purchase.expects(:set_needs_polling)
          get :report, params
        end
      end
      
      context "purchase's status is prepared" do
        should "NOT call set_need_polling" do
          purchase = purchases(:one)
          params = {:price_setting_id => '111111', :status => 'prepared', :purchase_id => '1', :message => "This+payment+changed+state", :payment_id => "12345"}
          
          Purchase.expects(:find).with("1").returns purchase
          @price_setting.stubs(:show_payment).returns({:payment => {:id => '1', :status => 'prepared', :payment_method_id => '1', :platform => 'phone'}, :instructions => {:long_instructions => "prepared instructions" }})
          purchase.expects(:set_needs_polling).never
          get :report, params
        end
      end
    end

    should "never render layout and return *ok*" do
      get :report
      assert_response :success
      assert_template false
      assert_equal "*ok*", @response.body
    end

  end ##### END #report #####

  context "#submit_verification_code" do
    setup do
      @payment_in_progress = {:payment => {:id => '1', :status => 'in_progress', :verification_tries_left => '2'}, 
                              :instructions => {:long_instructions => "Please text the message PAY 3955 to phone number 7711." }}
                              
      @in_prog_purchase = purchases(:two)
      # Purchase.expects(:find).returns @in_prog_purchase
      
      @product = products(:one)
      Product.expects(:find).returns @product
    end

    should "not be successful with incorrect session id" do
      Purchase.expects(:find).returns @in_prog_purchase
      @price_setting.expects(:verification_code).never
      xhr :post, :submit_verification_code, { :product_id => @product, 
                                              :id => Purchase.first.zaypay_payment_id, 
                                              :verification_code => '123456' }, {:session_id => 'blablabla'}
      assert_response :redirect
      assert_redirected_to products_path
    end

    context "with correct session_id" do
      should "be successful when purchase.in_progress? and verification code is present" do
        Purchase.expects(:find).returns @in_prog_purchase
        @price_setting.expects(:verification_code).with(@in_prog_purchase.zaypay_payment_id, '123456').returns @payment_in_progress
        xhr :post, :submit_verification_code, { :product_id => @product, 
                                                :id => @in_prog_purchase.zaypay_payment_id, 
                                                :verification_code => '123456' }, {:session_id => '1234abcd'}
        assert_response :success
        assert_template :submit_verification_code
      end
      
      should "NOT call verification_code when no verification_code is submitted" do
        Purchase.expects(:find).returns @in_prog_purchase
        @price_setting.expects(:verification_code).never
        xhr :post, :submit_verification_code, { :product_id => @product, 
                                                :id => @in_prog_purchase.zaypay_payment_id, 
                                                :verification_code => ' ' }, {:session_id => '1234abcd'}
        assert_response :success
        assert_template :submit_verification_code
      end
      
      should "NOT call verification_code when purchase is NOT in_progress" do
        @prepared_purchase = purchases(:one)
        Purchase.expects(:find).returns @prepared_purchase
        @price_setting.expects(:verification_code).never

        xhr :post, :submit_verification_code, { :product_id => @product, 
                                                :id => @prepared_purchase.zaypay_payment_id, 
                                                :verification_code => '123456' }, {:session_id => '1234abcd'}

        assert_response :success
        assert_template :submit_verification_code
      end
    end
  end ##### END #submit_verification_code #####

end