require 'simplecov'
SimpleCov.start 'rails'

ENV["RAILS_ENV"] = "test"
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  # Add more helper methods to be used by all tests here...
  def dutch_price_setting_mock
    price_setting = mock
    price_setting.stubs(:ip_country_is_configured?).returns({:country=>{:code=>"NL", :name=>"Netherlands"}, :locale=>{:country=>"NL", :language=>"nl"}})
    price_setting.stubs(:list_languages).returns([{:code=>"nl", :english_name=>"Dutch", :native_name=>"Nederlands"}])
    price_setting.stubs(:list_countries).returns([{:code=>"NL", :name=>"Netherlands"}])
    price_setting.stubs(:locale_for_ip).returns({:country=>"NL", :language=>"en"})
    price_setting.stubs(:locale).returns 'nl-NL'
    price_setting.stubs(:list_payment_methods).returns []
    price_setting.stub_everything
    price_setting
  end
end
