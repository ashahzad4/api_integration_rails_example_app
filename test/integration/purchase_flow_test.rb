require 'test_helper'

class PurchaseFlowTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:one)
    @price_setting = dutch_price_setting_mock
    Zaypay::PriceSetting.stubs(:new).returns @price_setting
  end
  context "customer goes to main page" do
    should "be successful and has the welcome message" do
      get "/"
      assert_response :success
      assert_template 'home/index'
      assert_select "a#products_index_button"
    end
  end

  context "customer on products page" do
    should "see name, description for products" do
      get products_path
      assert_response :success
      assert_template "index"
      assert_select "tr#product_1 td.product_name", @product.name
      assert_select "tr#product_1 td a[href=?]", new_product_purchase_path(@product)
      assert_select "tr#product_1 td.product_description", @product.description
    end
  end

  context "customer clicks on a product" do
    context "ip_country of customer is configured" do
      should "be presented with a form with languages, countries and payment_methods" do
        get new_product_purchase_path(@product)
        assert_response :success
        assert_template "new"
        assert_select "div#language_selection"
        assert_select "div#country_selection"
        assert_select "div#payment_method_selection"
        assert_select "div#submit_wrapper"
      end
    end
    context "ip_country of customer is NOT configured" do
      setup do
        # do some customization to our standard dutch_price_setting_mock
        @price_setting.stubs(:locale).returns nil
        @price_setting.stubs(:ip_country_is_configured?).returns nil
      end
      should "hide select_tag for payment_methods and submit button" do
        get new_product_purchase_path(@product)
        assert_select "div#payment_method_selection", false
        assert_select "div#submit_wrapper", false
      end
    end
  end
  
  context "customer does not submit language OR country OR payment_method" do
    should "NOT create a purchase object and redirect back to products page" do
      assert_no_difference "Purchase.count" do
        post product_purchases_path(@product), {:language => "nl", :country => '', :payment_method => ""}
      end
      assert_response :redirect
      assert_redirected_to new_product_purchase_path(@product)
      assert_equal "You did not select a country.<br/>You did not select a payment method.", flash[:error]
    end
  end
  
  context "customer submits language, country and payment_method correctly" do
    setup do
      @payment = {:payment => {:status => 'prepared', :id => '1' }, 
                  :instructions => {:long_instructions => "Please text the message PAY 3955 to phone number 7711" }}
      @price_setting.expects(:create_payment).returns @payment
    end
    should "create a purchase, redirect to purchases#show and display instructions" do
      assert_difference "Purchase.count" do
        post product_purchases_path(@product), {:language => "nl", :country => 'NL', :payment_method => "2"}
        assert_redirected_to product_purchase_path(@product, Purchase.last)
        assert_equal @product.id, Purchase.last.product_id
        assert_equal 'prepared',  Purchase.last.status
      end
    end
  end

  context "For countries where verification_code is needed" do
    setup do
      @prepared_payment = {:payment => {:id => '1', 
                                        :locale=>"en-TR", 
                                        :status => 'prepared', 
                                        :verification_needed => false, 
                                        :your_variables=>"product_id=1",
                                        :payment_method_id=>2 }, 
                           :instructions => {:long_instructions => "Please text the message PAY 3955 to phone number 7711" }}
      @in_progress_payment = {:payment => {:id => '1', 
                                           :locale=>"en-TR", 
                                           :status => 'in_progress', 
                                           :verification_needed => true,
                                           :verification_tries_left=>3, 
                                           :your_variables=>"product_id=1",
                                           :payment_method_id=>2 },
                              :instructions => {:long_instructions => "Please text the message PAY 3955 to phone number 7711" }}
      @paid_payment = {:payment => {:id => '1', 
                                    :locale=>"en-TR", 
                                    :status => 'paid', 
                                    :verification_needed => false,
                                    :your_variables=>"product_id=1",
                                    :payment_method_id=>2 },
                       :instructions => {}}
    end
    context "a correct code is submitted" do

      should "render thank_you partial at the end" do
        # create a payment in Turkey, then get redirected to purchases#show
        @price_setting.expects(:create_payment).returns @prepared_payment
        post product_purchases_path(@product), {:language => "en", :country => 'TR', :payment_method => "2"}
        assert_redirected_to product_purchase_path(@product, Purchase.last)

        # Stubs PriceSetting to return a payment that is progress and needs verification code
        # Simulate an incoming URL with status in_progress
        @price_setting.stubs(:show_payment).returns @in_progress_payment
        get report_path, {:price_setting_id => @product.price_setting_id, :status => 'in_progress', :purchase_id => Purchase.last.id, :message => "This+payment+changed+state", :payment_id => Purchase.last.zaypay_payment_id}

        # simulate a periodic ajax call to purchases#show, and it should render verification_form
        xml_http_request :get, product_purchase_path(@product, Purchase.last)
        assert_response :success
        assert_template :_verification_code_form
        
        # just to make sure that it renders verification_form as wwell for html request
        get product_purchase_path(@product, Purchase.last)
        assert_template :_verification_code_form

        # post the verification code
        @price_setting.expects(:verification_code).with(Purchase.last.zaypay_payment_id, '123456').returns @paid_payment
        xml_http_request :post, submit_verification_code_product_purchase_path(@product, Purchase.last), 
                          { :product_id => @product.id, :id => Purchase.last.zaypay_payment_id, :verification_code => '123456' }, {:session_id => '1234abcd'}
        assert_response :success
        assert_template :submit_verification_code
        assert_template :thank_you
        assert_select_jquery :html, '#instructions_body' do
          assert_select 'div#thank_you'
          assert_select '#long_instructions', false
        end
      end
    end

    context "submitted code is incorrect" do
      setup do
        @two_tries_left_payment = {:payment => {:id => '1', 
                                                :locale=>"en-TR", 
                                                :status => 'in_progress', 
                                                :verification_needed => true,
                                                :verification_tries_left=>2, 
                                                :your_variables=>"product_id=1",
                                                :payment_method_id=>2 },
                                   :instructions => {:long_instructions => "Please text the message PAY 3955 to phone number 7711" }}
        @one_try_left_payment = {:payment => {:id => '1', 
                                              :locale=>"en-TR", 
                                              :status => 'in_progress', 
                                              :verification_needed => true,
                                              :verification_tries_left=>1, 
                                              :your_variables=>"product_id=1",
                                              :payment_method_id=>2 },
                                 :instructions => {:long_instructions => "Please text the message PAY 3955 to phone number 7711" }}
        @no_tries_left_payment = {:payment => {:id => '1', 
                                               :locale=>"en-TR", 
                                               :status => 'in_progress', 
                                               :verification_needed => true,
                                               :verification_tries_left=>0, 
                                               :your_variables=>"product_id=1",
                                               :payment_method_id=>2 },
                                  :instructions => {:long_instructions => "Please text the message PAY 3955 to phone number 7711" }}
      end

      should "display appropriate messages and redirect after 3rd failed attempt" do
        # create a payment in Turkey
        @price_setting.expects(:create_payment).returns @prepared_payment
        post product_purchases_path(@product), {:language => "en", :country => 'TR', :payment_method => "2"}
        assert_redirected_to product_purchase_path(@product, Purchase.last)

        # simulate an incoming report
        @price_setting.stubs(:show_payment).returns @in_progress_payment
        get report_path, {:price_setting_id => @product.price_setting_id, :status => 'in_progress', :purchase_id => Purchase.last.id, :message => "This+payment+changed+state", :payment_id => Purchase.last.zaypay_payment_id}
        # Stubs PriceSetting to return a payment that is progress and needs verification code
        xml_http_request :get, product_purchase_path(@product, Purchase.last)
        assert_response :success
        
        # First Try
        @price_setting.expects(:verification_code).with(Purchase.last.zaypay_payment_id, '123456').returns @two_tries_left_payment
        xml_http_request :post, submit_verification_code_product_purchase_path(@product, Purchase.last), 
                         { :product_id => @product.id, :id => Purchase.last.zaypay_payment_id, :verification_code => '123456' }, {:session_id => '1234abcd'}
        assert_response :success
        assert_template :submit_verification_code
        assert_select ".alert.alert-error", "You provided an incorrect verification code."

        # Second Try
        @price_setting.expects(:verification_code).with(Purchase.last.zaypay_payment_id, '123456').returns @one_try_left_payment
        xml_http_request :post, submit_verification_code_product_purchase_path(@product, Purchase.last), 
                         { :product_id => @product.id, :id => Purchase.last.zaypay_payment_id, :verification_code => '123456' }, {:session_id => '1234abcd'}
        assert_response :success
        assert_template :submit_verification_code
        assert_select ".alert.alert-error", "You provided an incorrect verification code."

        # Thrid Try
        @price_setting.expects(:verification_code).with(Purchase.last.zaypay_payment_id, '123456').returns @no_tries_left_payment
        xml_http_request :post, submit_verification_code_product_purchase_path(@product, Purchase.last), 
                         { :product_id => @product.id, :id => Purchase.last.zaypay_payment_id, :verification_code => '123456' }, {:session_id => '1234abcd'}
        assert_response :success
        assert_template :submit_verification_code
        assert_select ".alert.alert-error", "You have failed too many times. You will be redirected."
      end
    end
  end
end