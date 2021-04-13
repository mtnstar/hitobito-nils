# frozen_string_literal: true


class TotpController < ApplicationController
  # before_action :redirect_to_root, unless: :two_factor_authentication_pending?
  skip_authorization_check
  before_action :redirect_on_locked, if: :access_locked?

  def new
    session[:pending_totp_secret] ||= generate_secret unless person.totp_registered?

  end

  def create
    if otp.verify(params[:totp_code]).present?
      sign_in(person) unless person_signed_in?

      unless person.totp_registered?
        person.totp_secret = session.delete(:pending_totp_secret)
        person.second_factor_auth = :totp
      end

      session.delete(:pending_two_factor_person_id)

      person.save!

      redirect_to root_path, notice: t('totp.flash.success')
    else

      person.increment_failed_attempts
      if person.failed_attempts > Person.maximum_attempts
        person.lock_access!
      end

      redirect_to new_users_totp_path, alert: t('totp.flash.failure')
    end
  end

  private

  def person
    @person ||= current_person || pending_two_factor_person
  end

  def authenticate?
    false
  end

  def generate_secret
    People::OneTimePassword.generate_secret
  end

  def otp
    People::OneTimePassword.new(secret)
  end

  def secret
    person.totp_registered? ? person.totp_secret : session[:pending_totp_secret] 
  end

  def access_locked?
    person.access_locked?
  end

  def redirect_on_locked
    redirect_to root_path, alert: t('devise.failure.locked')
  end
end
