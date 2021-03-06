# frozen_string_literal: true

require 'support/with_env'
require 'spec_helper'
require 'payment'
require 'thank_you_mailer'

RSpec.describe Payment do
  include Support::WithEnv

  Request = Struct.new(
    :amount, :currency, :card_number, :cvc, :exp_year, :exp_month, :email, :name
  )

  let(:request) { Request.new(nil) }
  let(:payment) { Payment.new(request) }

  it 'stores the request object passed in the initializer' do
    expect(payment.request).to eq request
  end

  describe '#attempt', vcr: { record: :once } do
    it 'fails without an api key' do
      with_env('STRIPE_API_KEY' => '') do
        expect(payment.attempt).to eq([:invalid_request])
      end
    end

    it 'fails with an invalid api key' do
      with_env('STRIPE_API_KEY' => 'aaaaa') do
        expect(payment.attempt).to eq([:invalid_request])
      end
    end

    it 'fails with a valid api key but no other parameters' do
      expect(payment.attempt).to eq([:invalid_request])
    end

    it 'fails with a valid api key and invalid card number' do
      request = Request.new(
        '1000', 'usd', '1235424242424242', '123', '2020', '01',
        'irrelevant', 'irrelevant'
      )
      payment = Payment.new(request)
      expect(payment.attempt).to eq([:card_error])
    end

    context 'success' do
      it 'succeeds with a valid api key and valid parameters' do
        request = Request.new(
          '1000', 'usd', '4242424242424242', '123', '2020', '01',
          'irrelevant', 'irrelevant'
        )
        payment = Payment.new(request)
        expect(payment.attempt).to eq([])
      end

      it 'should send a thank you email' do
        allow(ThankYouMailer).to receive(:send_email)
          .with('user@example.com', 'Name')

        request = Request.new(
          '1000', 'usd', '4242424242424242', '123', '2020', '01',
          'user@example.com', 'Name'
        )
        Payment.new(request).attempt

        expect(ThankYouMailer).to have_received(:send_email)
          .with('user@example.com', 'Name')
      end
    end
  end
end
