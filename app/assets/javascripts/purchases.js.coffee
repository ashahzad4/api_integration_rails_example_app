# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/

$ ->
  ############ END JS for purchases#new ############
  
  # On orders#new, when #order_language or #order_country has been changed, an ajax-call will be made to orders_controller#new
  # It responds with new.js.erb, which in turn updates the order_payment_method select_tag with the correct language and tariff
  if($('select#language').length > 0)
    $('select#language').change ->
      $.ajax
        url: window.location
        dataType: 'script'
        data: { language: $("select#language option:selected").val(), country: $("select#country option:selected").val() }

    $('select#country').change ->
      $.ajax
        url: this.action
        dataType: 'script'
        data: { language: $("select#language option:selected").val(), country: $("select#country option:selected").val() }

  $('.alert-error').effect('pulsate', { times: 3}, 1500)
  ############ END JS for purchases#new ############

  ############ JS for purchases#show ###############
  # make a periodic ajax request
  setInterval ->
    if($('#long_instructions').length > 0)
      $.ajax 
        url: window.location
  ,3000

  # waiting for user to enter paycode
  if($('h5#waiting_for_response').length > 0 )
    $('h5#waiting_for_response').ajaxStart ->
      $(this).fadeTo(2000, 1.0)
    $('h5#waiting_for_response').ajaxStop ->
      $(this).fadeTo(2000, 0.0)
      
  # for certain countries (eg USA, Turkey), the end-user has to enter a verification code after sending a sms
  # the submission of verification code triggers an ajax-request, which in turn shows and hides certain dom-elements
  $('body').ajaxStart ->
    $('span#loading').show()

  $('body').ajaxStop ->
    $('span#loading').hide()

  $('body').ajaxStart ->
    $('#incorrect_verification_code').hide()
  ############ END JS for purchases#new ############